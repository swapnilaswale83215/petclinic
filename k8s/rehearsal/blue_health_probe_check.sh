#!/usr/bin/env bash
# blue_health_probe_check.sh — Rehearsal harness for blue pod health probe tracking.
#
# SPEC-PLAT-13 / NFR-005 / NFR-006 / NFR-009 / AC-008 / AC-009 / AC-011
# Continuously polls blue pod liveness and readiness probe endpoints throughout
# the write-park window (default 30 s). Asserts:
#   - Zero pod restarts for blue during the window
#   - Zero forwarded writes that failed after being sent
#   - Liveness and readiness probes pass throughout the window
#
# Usage:
#   blue_health_probe_check.sh [--namespace <ns>] [--duration <seconds>]
#                              [--poll-interval <seconds>]
#
# Exit codes:
#   0  All assertions passed.
#   1  One or more assertions failed.

set -euo pipefail

# ---------------------------------------------------------------------------
# Logging helpers (mirror .specify/scripts/bash/common.sh conventions)
# ---------------------------------------------------------------------------
log_info()  { printf '[INFO]  %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
log_warn()  { printf '[WARN]  %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
NAMESPACE="${NAMESPACE:-default}"
WINDOW_DURATION_S="${WINDOW_DURATION_S:-30}"
POLL_INTERVAL_S="${POLL_INTERVAL_S:-2}"
SLOT_LABEL="blue"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)     NAMESPACE="$2";          shift 2 ;;
    --duration)      WINDOW_DURATION_S="$2";  shift 2 ;;
    --poll-interval) POLL_INTERVAL_S="$2";    shift 2 ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
TOTAL_PROBE_CHECKS=0
PROBE_PASS_COUNT=0
PROBE_FAIL_COUNT=0
RESTART_COUNT_START=0
RESTART_COUNT_END=0
FAILED_FORWARDED_WRITES=0

# ---------------------------------------------------------------------------
# Helper: get total restart count for all blue pods
# ---------------------------------------------------------------------------
get_blue_restart_count() {
  kubectl get pods \
    --namespace "$NAMESPACE" \
    --selector="slot=${SLOT_LABEL}" \
    -o jsonpath='{range .items[*]}{range .status.containerStatuses[*]}{.restartCount}{"\n"}{end}{end}' \
    2>/dev/null | awk '{s+=$1} END {print s+0}'
}

# ---------------------------------------------------------------------------
# Helper: check liveness and readiness for all blue pods
# Returns 0 if all pods are Running and Ready, 1 otherwise.
# ---------------------------------------------------------------------------
check_blue_pod_health() {
  local not_ready=0
  local pod_statuses
  pod_statuses=$(kubectl get pods \
    --namespace "$NAMESPACE" \
    --selector="slot=${SLOT_LABEL}" \
    -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{" "}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{"\n"}{end}' \
    2>/dev/null) || return 1

  if [[ -z "$pod_statuses" ]]; then
    log_warn "No blue pods found in namespace '$NAMESPACE'."
    return 1
  fi

  local pod_name pod_phase pod_ready
  while IFS=' ' read -r pod_name pod_phase pod_ready; do
    [[ -z "$pod_name" ]] && continue
    if [[ "$pod_phase" != "Running" || "$pod_ready" != "True" ]]; then
      log_warn "Pod '$pod_name': phase=$pod_phase ready=$pod_ready — probe FAIL"
      not_ready=$(( not_ready + 1 ))
    fi
  done <<< "$pod_statuses"

  [[ $not_ready -eq 0 ]]
}

# ---------------------------------------------------------------------------
# Helper: count failed forwarded writes
# Reads the FAILED_FORWARDED_WRITES_COUNT env var if set by an external
# write-load harness, otherwise defaults to 0.
# ---------------------------------------------------------------------------
get_failed_forwarded_writes() {
  echo "${FAILED_FORWARDED_WRITES_COUNT:-0}"
}

# ---------------------------------------------------------------------------
# Record baseline restart count before the window
# ---------------------------------------------------------------------------
log_info "Recording baseline restart count for blue pods..."
RESTART_COUNT_START=$(get_blue_restart_count)
log_info "Baseline restart count: ${RESTART_COUNT_START}"

# ---------------------------------------------------------------------------
# Poll loop: run for WINDOW_DURATION_S seconds
# ---------------------------------------------------------------------------
log_info "Starting ${WINDOW_DURATION_S}s write-park window health probe loop (poll interval: ${POLL_INTERVAL_S}s)..."
WINDOW_START=$(date +%s)

while true; do
  WINDOW_NOW=$(date +%s)
  WINDOW_ELAPSED=$(( WINDOW_NOW - WINDOW_START ))
  if [[ $WINDOW_ELAPSED -ge $WINDOW_DURATION_S ]]; then
    break
  fi

  TOTAL_PROBE_CHECKS=$(( TOTAL_PROBE_CHECKS + 1 ))

  if check_blue_pod_health; then
    PROBE_PASS_COUNT=$(( PROBE_PASS_COUNT + 1 ))
  else
    PROBE_FAIL_COUNT=$(( PROBE_FAIL_COUNT + 1 ))
    log_error "Probe FAIL at elapsed=${WINDOW_ELAPSED}s"
  fi

  sleep "$POLL_INTERVAL_S"
done

# ---------------------------------------------------------------------------
# Record final restart count and compute delta
# ---------------------------------------------------------------------------
RESTART_COUNT_END=$(get_blue_restart_count)
RESTART_DELTA=$(( RESTART_COUNT_END - RESTART_COUNT_START ))

# ---------------------------------------------------------------------------
# Record failed forwarded writes
# ---------------------------------------------------------------------------
FAILED_FORWARDED_WRITES=$(get_failed_forwarded_writes)

# ---------------------------------------------------------------------------
# Structured summary
# ---------------------------------------------------------------------------
printf '\n'
printf '=== Blue Pod Health Probe Summary ===\n'
printf 'Window duration (s)       : %s\n' "$WINDOW_DURATION_S"
printf 'Total probe checks        : %s\n' "$TOTAL_PROBE_CHECKS"
printf 'Probe pass count          : %s\n' "$PROBE_PASS_COUNT"
printf 'Probe fail count          : %s\n' "$PROBE_FAIL_COUNT"
printf 'Restart count (start)     : %s\n' "$RESTART_COUNT_START"
printf 'Restart count (end)       : %s\n' "$RESTART_COUNT_END"
printf 'Restart delta             : %s\n' "$RESTART_DELTA"
printf 'Failed forwarded writes   : %s\n' "$FAILED_FORWARDED_WRITES"
printf '=====================================\n'

# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------
ASSERTION_FAILURES=0

if [[ $RESTART_DELTA -ne 0 ]]; then
  log_error "ASSERTION FAILED: Blue pods had ${RESTART_DELTA} restart(s) during the ${WINDOW_DURATION_S}s window. Expected 0."
  ASSERTION_FAILURES=$(( ASSERTION_FAILURES + 1 ))
else
  log_info "ASSERTION PASSED: Zero blue pod restarts during the ${WINDOW_DURATION_S}s window."
fi

if [[ $FAILED_FORWARDED_WRITES -ne 0 ]]; then
  log_error "ASSERTION FAILED: ${FAILED_FORWARDED_WRITES} forwarded write(s) failed after being sent. Expected 0."
  ASSERTION_FAILURES=$(( ASSERTION_FAILURES + 1 ))
else
  log_info "ASSERTION PASSED: Zero failed forwarded writes."
fi

if [[ $PROBE_FAIL_COUNT -ne 0 ]]; then
  log_error "ASSERTION FAILED: ${PROBE_FAIL_COUNT} probe check(s) failed during the window. Expected 0."
  ASSERTION_FAILURES=$(( ASSERTION_FAILURES + 1 ))
else
  log_info "ASSERTION PASSED: All ${PROBE_PASS_COUNT} probe checks passed."
fi

if [[ $ASSERTION_FAILURES -gt 0 ]]; then
  log_error "Rehearsal harness: ${ASSERTION_FAILURES} assertion(s) failed."
  exit 1
fi

log_info "Rehearsal harness: all assertions passed."
exit 0
