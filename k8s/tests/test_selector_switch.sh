#!/usr/bin/env bash
# test_selector_switch.sh — Integration tests for selector_switch.sh
#
# Covers TC1, TC2, TC3 per GH-48 (E4-S5).
#
# TC1: Green-only success path — selector patch to green, Endpoints verified
#      within 5 s, orchestrator exits 0.
# TC2: Timeout/halt path — green pods scaled to 0, orchestrator halts after
#      5 s with non-zero exit, selector restored to blue.
# TC3: Fault-injection abort — INJECT_PATCH_FAILURE=1, orchestrator exits
#      non-zero, selector remains at pre-patch value.
#
# Usage:
#   test_selector_switch.sh [--namespace <ns>] [--service <svc>]
#                           [--run-tc <TC1|TC2|TC3|all>]
#
# Exit codes:
#   0  All executed test cases passed.
#   1  One or more test cases failed.

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
SERVICE_NAME="${SERVICE_NAME:-petclinic}"
RUN_TC="${RUN_TC:-all}"
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELECTOR_SWITCH="${SCRIPT_DIR}/../orchestrator/selector_switch.sh"
ENDPOINTS_DEADLINE_S=5

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2";    shift 2 ;;
    --service)   SERVICE_NAME="$2"; shift 2 ;;
    --run-tc)    RUN_TC="$2";       shift 2 ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Prerequisite check
# ---------------------------------------------------------------------------
if [[ ! -x "$SELECTOR_SWITCH" ]]; then
  log_error "selector_switch.sh not found or not executable at: $SELECTOR_SWITCH"
  exit 1
fi

# ---------------------------------------------------------------------------
# Helper: get current selector slot for the shared Service
# ---------------------------------------------------------------------------
get_current_slot() {
  kubectl get service "$SERVICE_NAME" \
    --namespace "$NAMESPACE" \
    -o jsonpath='{.spec.selector.slot}' 2>/dev/null
}

# ---------------------------------------------------------------------------
# Helper: restore selector to a given slot (cleanup)
# ---------------------------------------------------------------------------
restore_selector() {
  local target_slot="$1"
  kubectl patch service "$SERVICE_NAME" \
    --namespace "$NAMESPACE" \
    --type=merge \
    --patch "{\"spec\":{\"selector\":{\"slot\":\"${target_slot}\"}}}" \
    >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Helper: verify Endpoints contain only pods of a given slot within deadline
# ---------------------------------------------------------------------------
wait_for_exclusive_endpoints() {
  local target_slot="$1"
  local deadline="$2"
  local start_ts
  start_ts=$(date +%s)

  while true; do
    local ready_pods
    ready_pods=$(kubectl get endpoints "$SERVICE_NAME" \
      --namespace "$NAMESPACE" \
      -o jsonpath='{range .subsets[*].addresses[*]}{.targetRef.name}{"\n"}{end}' \
      2>/dev/null) || true

    if [[ -n "$ready_pods" ]]; then
      local all_match=true
      local pod_name
      while IFS= read -r pod_name; do
        [[ -z "$pod_name" ]] && continue
        local pod_slot
        pod_slot=$(kubectl get pod "$pod_name" \
          --namespace "$NAMESPACE" \
          -o jsonpath='{.metadata.labels.slot}' 2>/dev/null) || pod_slot=""
        if [[ "$pod_slot" != "$target_slot" ]]; then
          all_match=false
          break
        fi
      done <<< "$ready_pods"
      if [[ "$all_match" == "true" ]]; then
        return 0
      fi
    fi

    local now_ts
    now_ts=$(date +%s)
    local elapsed=$(( now_ts - start_ts ))
    if [[ $elapsed -ge $deadline ]]; then
      return 1
    fi
    sleep 0.5
  done
}

# ---------------------------------------------------------------------------
# TC1: Green-only success path
# ---------------------------------------------------------------------------
run_tc1() {
  local tc_id="TC1"
  log_info "${tc_id}: Starting — green-only success path"

  # Ensure we start with blue
  restore_selector "blue"
  sleep 1

  local pre_slot
  pre_slot=$(get_current_slot)
  log_info "${tc_id}: Pre-patch slot: '$pre_slot'"

  # Run selector switch to green
  local exit_code=0
  NAMESPACE="$NAMESPACE" SERVICE_NAME="$SERVICE_NAME" \
    "$SELECTOR_SWITCH" \
    --namespace "$NAMESPACE" \
    --service "$SERVICE_NAME" \
    --target-slot green || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    log_fail "${tc_id}: selector_switch.sh exited with code ${exit_code} (expected 0)"
    restore_selector "blue"
    return 1
  fi

  # Verify Endpoints contain only green pods within deadline
  if wait_for_exclusive_endpoints "green" "$ENDPOINTS_DEADLINE_S"; then
    log_pass "${tc_id}: Endpoints contain only green pod addresses within ${ENDPOINTS_DEADLINE_S}s — PASS"
    restore_selector "blue"
    return 0
  else
    log_fail "${tc_id}: Endpoints did not contain exclusively green pod addresses within ${ENDPOINTS_DEADLINE_S}s — FAIL"
    restore_selector "blue"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# TC2: Timeout/halt path (green pods scaled to 0)
# ---------------------------------------------------------------------------
run_tc2() {
  local tc_id="TC2"
  log_info "${tc_id}: Starting — timeout/halt path (green pods scaled to 0)"

  # Ensure we start with blue
  restore_selector "blue"
  sleep 1

  # Scale green deployment to 0 replicas
  local green_deployment="${GREEN_DEPLOYMENT:-petclinic-green}"
  local original_replicas=1
  original_replicas=$(kubectl get deployment "$green_deployment" \
    --namespace "$NAMESPACE" \
    -o jsonpath='{.spec.replicas}' 2>/dev/null) || original_replicas=1

  log_info "${tc_id}: Scaling green deployment '$green_deployment' to 0 replicas..."
  kubectl scale deployment "$green_deployment" \
    --namespace "$NAMESPACE" \
    --replicas=0 >/dev/null 2>&1 || {
    log_error "${tc_id}: Could not scale green deployment to 0. Skipping TC2."
    log_fail "${tc_id}: SKIP (could not scale green deployment)"
    return 1
  }

  # Wait for green pods to terminate
  sleep 3

  # Run selector switch — should fail because Endpoints won't go green-only
  local exit_code=0
  NAMESPACE="$NAMESPACE" SERVICE_NAME="$SERVICE_NAME" \
    "$SELECTOR_SWITCH" \
    --namespace "$NAMESPACE" \
    --service "$SERVICE_NAME" \
    --target-slot green || exit_code=$?

  # Restore green deployment replicas
  kubectl scale deployment "$green_deployment" \
    --namespace "$NAMESPACE" \
    --replicas="$original_replicas" >/dev/null 2>&1 || true

  if [[ $exit_code -eq 0 ]]; then
    log_fail "${tc_id}: selector_switch.sh exited 0 but should have halted with non-zero exit — FAIL"
    restore_selector "blue"
    return 1
  fi

  # Verify selector was restored to blue
  local current_slot
  current_slot=$(get_current_slot)
  if [[ "$current_slot" == "blue" ]]; then
    log_pass "${tc_id}: Orchestrator halted (exit ${exit_code}) and selector restored to 'blue' — PASS"
    return 0
  else
    log_fail "${tc_id}: Orchestrator halted but selector is '$current_slot' (expected 'blue') — FAIL"
    restore_selector "blue"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# TC3: Fault-injection abort (INJECT_PATCH_FAILURE=1)
# ---------------------------------------------------------------------------
run_tc3() {
  local tc_id="TC3"
  log_info "${tc_id}: Starting — fault-injection abort (INJECT_PATCH_FAILURE=1)"

  # Ensure we start with blue
  restore_selector "blue"
  sleep 1

  local pre_slot
  pre_slot=$(get_current_slot)
  log_info "${tc_id}: Pre-patch slot: '$pre_slot'"

  # Run selector switch with fault injection enabled
  local exit_code=0
  INJECT_PATCH_FAILURE=1 NAMESPACE="$NAMESPACE" SERVICE_NAME="$SERVICE_NAME" \
    "$SELECTOR_SWITCH" \
    --namespace "$NAMESPACE" \
    --service "$SERVICE_NAME" \
    --target-slot green || exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    log_fail "${tc_id}: selector_switch.sh exited 0 with INJECT_PATCH_FAILURE=1 (expected non-zero) — FAIL"
    restore_selector "blue"
    return 1
  fi

  # Verify selector remains at pre-patch value (no intermediate state)
  local current_slot
  current_slot=$(get_current_slot)
  if [[ "$current_slot" == "$pre_slot" ]]; then
    log_pass "${tc_id}: Orchestrator aborted (exit ${exit_code}), selector remains at pre-patch value '$pre_slot' — PASS"
    return 0
  else
    log_fail "${tc_id}: Selector is '$current_slot' after fault injection (expected '$pre_slot') — FAIL"
    restore_selector "blue"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------
OVERALL_FAILURES=0

run_test() {
  local tc_func="$1"
  local tc_name="$2"
  if $tc_func; then
    log_info "${tc_name}: PASSED"
  else
    log_error "${tc_name}: FAILED"
    OVERALL_FAILURES=$(( OVERALL_FAILURES + 1 ))
  fi
}

case "$RUN_TC" in
  TC1)  run_test run_tc1 "TC1" ;;
  TC2)  run_test run_tc2 "TC2" ;;
  TC3)  run_test run_tc3 "TC3" ;;
  all)
    run_test run_tc1 "TC1"
    run_test run_tc2 "TC2"
    run_test run_tc3 "TC3"
    ;;
  *) log_error "Unknown --run-tc value: $RUN_TC (expected TC1, TC2, TC3, or all)"; exit 1 ;;
esac

if [[ $OVERALL_FAILURES -gt 0 ]]; then
  log_error "${OVERALL_FAILURES} test case(s) FAILED."
  exit 1
fi

log_info "All executed test cases PASSED."
exit 0
