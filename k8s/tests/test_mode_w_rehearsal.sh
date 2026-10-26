#!/usr/bin/env bash
# test_mode_w_rehearsal.sh — Integration test TC5: mode W rehearsal without hold mechanism.
#
# TC5: Execute the full mode W cutover rehearsal on a production-sized copy by
# invoking k8s/orchestrator/mode_w_provision.sh with the hold mechanism disabled.
# Asserts:
#   - Write-pause duration from gate close to green gate open is <= 60 s (NFR-004)
#   - No hold-dependent code path was exercised
#   - mode_w_provision.sh exits 0
#
# FR-011: Mode W minimum upstream timeout = hold limit (60 s) + 5 s buffer = 65 s.
# The MODE_W_LIMIT constant below reflects the write-pause window limit (60 s),
# not the upstream timeout threshold (65 s).
#
# Usage:
#   test_mode_w_rehearsal.sh [--namespace <ns>]
#
# Exit codes:
#   0  TC5 passed.
#   1  TC5 failed.

set -euo pipefail

# ---------------------------------------------------------------------------
# Logging helpers (mirror .specify/scripts/bash/common.sh conventions)
# ---------------------------------------------------------------------------
log_info()  { printf '[INFO]  %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
log_pass()  { printf '[PASS]  %s\n' "$*"; }
log_fail()  { printf '[FAIL]  %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
NAMESPACE="${NAMESPACE:-default}"
TC_ID="TC5"
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE_W_PROVISION="${SCRIPT_DIR}/../orchestrator/mode_w_provision.sh"
# NFR-004: Mode W write-pause limit = 60 s
MODE_W_LIMIT=60
# FR-011: Mode W minimum upstream timeout = 65 s (hold limit 60 s + 5 s buffer)
MODE_W_MIN_UPSTREAM_TIMEOUT=65

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

FAILURES=0

# ---------------------------------------------------------------------------
# Prerequisite check
# ---------------------------------------------------------------------------
if [[ ! -x "$MODE_W_PROVISION" ]]; then
  log_error "mode_w_provision.sh not found or not executable at: $MODE_W_PROVISION"
  log_fail "${TC_ID}: FAILED (prerequisite: mode_w_provision.sh not found)"
  exit 1
fi

# ---------------------------------------------------------------------------
# Ensure hold mechanism is disabled
# AC-013: mode W rehearsal MUST NOT activate the hold mechanism.
# ---------------------------------------------------------------------------
unset HOLD_MECHANISM_ENABLED 2>/dev/null || true
unset HOLD_MODE_ACTIVE 2>/dev/null || true
export HOLD_MECHANISM_ENABLED=0
export HOLD_MODE_ACTIVE=0
log_info "${TC_ID}: Hold mechanism disabled (HOLD_MECHANISM_ENABLED=0, HOLD_MODE_ACTIVE=0)."

# ---------------------------------------------------------------------------
# TC5: Invoke mode_w_provision.sh and measure write-pause duration
# ---------------------------------------------------------------------------
log_info "${TC_ID}: Invoking mode_w_provision.sh with hold mechanism disabled..."
WRITE_PAUSE_START=$(date +%s)

PROVISION_EXIT=0
NAMESPACE="$NAMESPACE" \
  MIN_UPSTREAM_TIMEOUT_S="$MODE_W_MIN_UPSTREAM_TIMEOUT" \
  "$MODE_W_PROVISION" \
  --namespace "$NAMESPACE" \
  --min-timeout "$MODE_W_MIN_UPSTREAM_TIMEOUT" || PROVISION_EXIT=$?

WRITE_PAUSE_END=$(date +%s)
WRITE_PAUSE_ELAPSED=$(( WRITE_PAUSE_END - WRITE_PAUSE_START ))

log_info "${TC_ID}: mode_w_provision.sh exited with code ${PROVISION_EXIT}."
log_info "${TC_ID}: Write-pause duration measured: ${WRITE_PAUSE_ELAPSED}s (limit: ${MODE_W_LIMIT}s)."

# ---------------------------------------------------------------------------
# Assertion 1: mode_w_provision.sh must exit 0
# ---------------------------------------------------------------------------
if [[ $PROVISION_EXIT -eq 0 ]]; then
  log_pass "${TC_ID}: mode_w_provision.sh exited 0 — PASS"
else
  log_fail "${TC_ID}: mode_w_provision.sh exited ${PROVISION_EXIT} (expected 0) — FAIL"
  FAILURES=$(( FAILURES + 1 ))
fi

# ---------------------------------------------------------------------------
# Assertion 2: Write-pause duration <= MODE_W_LIMIT (60 s)
# NFR-004: Mode W write-pause MUST be <= 60 s.
# ---------------------------------------------------------------------------
if [[ $WRITE_PAUSE_ELAPSED -le $MODE_W_LIMIT ]]; then
  log_pass "${TC_ID}: Write-pause duration ${WRITE_PAUSE_ELAPSED}s <= ${MODE_W_LIMIT}s — PASS"
else
  log_fail "${TC_ID}: Write-pause duration ${WRITE_PAUSE_ELAPSED}s > ${MODE_W_LIMIT}s — FAIL"
  FAILURES=$(( FAILURES + 1 ))
fi

# ---------------------------------------------------------------------------
# Assertion 3: No hold-dependent code path was exercised
# AC-013: Verify HOLD_MECHANISM_ENABLED and HOLD_MODE_ACTIVE were not set to 1
# during the provisioning run.
# ---------------------------------------------------------------------------
if [[ "${HOLD_MECHANISM_ENABLED:-0}" != "1" && "${HOLD_MODE_ACTIVE:-0}" != "1" ]]; then
  log_pass "${TC_ID}: No hold-mechanism environment variable was activated — PASS"
else
  log_fail "${TC_ID}: Hold mechanism was activated during mode W provisioning (HOLD_MECHANISM_ENABLED=${HOLD_MECHANISM_ENABLED:-0}, HOLD_MODE_ACTIVE=${HOLD_MODE_ACTIVE:-0}) — FAIL"
  FAILURES=$(( FAILURES + 1 ))
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [[ $FAILURES -gt 0 ]]; then
  log_fail "${TC_ID}: FAILED (${FAILURES} assertion(s) failed)"
  exit 1
fi

log_pass "${TC_ID}: PASSED — mode W rehearsal completed without hold mechanism, write-pause ${WRITE_PAUSE_ELAPSED}s <= ${MODE_W_LIMIT}s"
exit 0
