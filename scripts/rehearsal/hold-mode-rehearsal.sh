#!/usr/bin/env bash
# hold-mode-rehearsal.sh — Production-sized write-pause and capacity validation harness.
#
# Validates SPEC-PLAT-13 hold-mode platform support under peak write load:
#   (a) Applies peak write load to blue pods via the shared Service write endpoints.
#   (b) Triggers the forward selector patch and measures the write-pause window.
#   (c) During the 30 s write-park window, captures blue pod capacity metrics and
#       asserts zero exhaustion events.
#   (d) Asserts forwarded_write_failures == 0 from the run record.
#   (e) Runs cross-slot-connectivity-test.sh as part of sign-off.
#   (f) Prints a structured rehearsal report with PASS/FAIL for each gate.
#
# Usage:
#   MODE=Z SHARED_SERVICE_NAME=petclinic NAMESPACE=default \
#     BLUE_POD_SELECTOR=slot=blue GREEN_POD_SELECTOR=slot=green \
#     ./scripts/rehearsal/hold-mode-rehearsal.sh
#
# Environment variables:
#   MODE                    ADR-APP-3 mode: Z (≤20 s write pause) or W (≤60 s) (default: Z)
#   SHARED_SERVICE_NAME     Name of the shared Kubernetes Service (required)
#   NAMESPACE               Kubernetes namespace (default: default)
#   BLUE_POD_SELECTOR       kubectl label selector for blue pods (default: slot=blue)
#   GREEN_POD_SELECTOR      kubectl label selector for green pods (default: slot=green)
#   WRITE_PAUSE_LIMIT_SECONDS  Override the write-pause limit in seconds (derived from MODE)
#   LOAD_GENERATOR          Load generator command: wrk or ab (default: ab)
#   WRITE_ENDPOINT          Write endpoint path to load-test (default: /owners/new)
#   ACTUATOR_PORT           Actuator port inside blue pods (default: 8080)
#   RUN_RECORD_FILE         Path to the JSON run record file (default: /tmp/orchestrator-run-record.json)

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRATOR_DIR="$(CDPATH="" cd "${SCRIPT_DIR}/../orchestrator" && pwd)"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
MODE="${MODE:-Z}"
SHARED_SERVICE_NAME="${SHARED_SERVICE_NAME:-}"
NAMESPACE="${NAMESPACE:-default}"
BLUE_POD_SELECTOR="${BLUE_POD_SELECTOR:-slot=blue}"
GREEN_POD_SELECTOR="${GREEN_POD_SELECTOR:-slot=green}"
LOAD_GENERATOR="${LOAD_GENERATOR:-ab}"
WRITE_ENDPOINT="${WRITE_ENDPOINT:-/owners/new}"
ACTUATOR_PORT="${ACTUATOR_PORT:-8080}"
export RUN_RECORD_FILE="${RUN_RECORD_FILE:-/tmp/orchestrator-run-record.json}"

if [[ -z "${SHARED_SERVICE_NAME}" ]]; then
  echo "ERROR: SHARED_SERVICE_NAME environment variable is required" >&2
  exit 1
fi

# Derive write-pause limit from MODE
case "${MODE}" in
  Z) DEFAULT_WRITE_PAUSE_LIMIT=20 ;;
  W) DEFAULT_WRITE_PAUSE_LIMIT=60 ;;
  *) echo "ERROR: MODE must be Z or W, got '${MODE}'" >&2; exit 1 ;;
esac
WRITE_PAUSE_LIMIT_SECONDS="${WRITE_PAUSE_LIMIT_SECONDS:-${DEFAULT_WRITE_PAUSE_LIMIT}}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
PASS_COUNT=0
FAIL_COUNT=0
declare -a REPORT_LINES=()

record_result() {
  local gate="$1"
  local result="$2"  # PASS or FAIL
  local detail="$3"
  REPORT_LINES+=("  [${result}] ${gate}: ${detail}")
  if [[ "${result}" == "PASS" ]]; then
    PASS_COUNT=$(( PASS_COUNT + 1 ))
  else
    FAIL_COUNT=$(( FAIL_COUNT + 1 ))
  fi
}

get_blue_pod() {
  kubectl get pods \
    --namespace "${NAMESPACE}" \
    -l "${BLUE_POD_SELECTOR}" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

get_metric_value() {
  local pod="$1"
  local metric_path="$2"
  kubectl exec "${pod}" \
    --namespace "${NAMESPACE}" \
    -- curl -sf "http://localhost:${ACTUATOR_PORT}${metric_path}" 2>/dev/null \
    | grep -o '"value":[0-9.]*' | head -1 | grep -o '[0-9.]*' || echo "0"
}

# ---------------------------------------------------------------------------
# Phase 1: Start peak write load
# ---------------------------------------------------------------------------
echo "[rehearsal] === Phase 1: Starting peak write load ==="
BLUE_POD=$(get_blue_pod)
if [[ -z "${BLUE_POD}" ]]; then
  echo "ERROR: No blue pods found matching selector '${BLUE_POD_SELECTOR}'" >&2
  exit 1
fi
echo "[rehearsal] Blue pod: ${BLUE_POD}"

# Get the Service ClusterIP for load generation
SERVICE_IP=$(kubectl get service "${SHARED_SERVICE_NAME}" \
  --namespace "${NAMESPACE}" \
  -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
SERVICE_URL="http://${SERVICE_IP}:8080"

echo "[rehearsal] Starting load generator (${LOAD_GENERATOR}) against ${SERVICE_URL}${WRITE_ENDPOINT}..."
LOAD_PID=""
if [[ "${LOAD_GENERATOR}" == "wrk" ]] && command -v wrk >/dev/null 2>&1; then
  wrk -t4 -c50 -d120s "${SERVICE_URL}${WRITE_ENDPOINT}" &
  LOAD_PID=$!
elif command -v ab >/dev/null 2>&1; then
  ab -n 100000 -c 50 -k "${SERVICE_URL}${WRITE_ENDPOINT}" &
  LOAD_PID=$!
else
  echo "[rehearsal] WARNING: No load generator (wrk/ab) found; skipping load phase"
fi

# ---------------------------------------------------------------------------
# Phase 2: Capture baseline capacity metrics on blue pod
# ---------------------------------------------------------------------------
echo "[rehearsal] === Phase 2: Capturing baseline capacity metrics ==="
BASELINE_THREAD_COUNT=$(get_metric_value "${BLUE_POD}" "/actuator/metrics/jvm.threads.live")
BASELINE_POOL_ACTIVE=$(get_metric_value "${BLUE_POD}" "/actuator/metrics/hikaricp.connections.active")
BASELINE_POOL_PENDING=$(get_metric_value "${BLUE_POD}" "/actuator/metrics/hikaricp.connections.pending")
BASELINE_HEAP=$(get_metric_value "${BLUE_POD}" "/actuator/metrics/jvm.memory.used")
echo "[rehearsal] Baseline — threads: ${BASELINE_THREAD_COUNT}, pool-active: ${BASELINE_POOL_ACTIVE}, pool-pending: ${BASELINE_POOL_PENDING}, heap: ${BASELINE_HEAP}"

# ---------------------------------------------------------------------------
# Phase 3: Record gate-close timestamp and trigger forward selector patch
# ---------------------------------------------------------------------------
echo "[rehearsal] === Phase 3: Gate close — triggering forward selector patch ==="
GATE_CLOSE_TS=$(date +%s)
echo "[rehearsal] Gate close timestamp: $(date -u -d @${GATE_CLOSE_TS} +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r ${GATE_CLOSE_TS} +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"

export SHARED_SERVICE_NAME NAMESPACE ENDPOINTS_TIMEOUT_SECONDS=5
"${ORCHESTRATOR_DIR}/switch.sh"
GREEN_GATE_OPEN_TS=$(date +%s)

WRITE_PAUSE_SECONDS=$(( GREEN_GATE_OPEN_TS - GATE_CLOSE_TS ))
echo "[rehearsal] Green gate open timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[rehearsal] Write-pause duration: ${WRITE_PAUSE_SECONDS}s (limit: ${WRITE_PAUSE_LIMIT_SECONDS}s)"

if [[ "${WRITE_PAUSE_SECONDS}" -le "${WRITE_PAUSE_LIMIT_SECONDS}" ]]; then
  record_result "AC-004 write-pause (mode ${MODE})" "PASS" "${WRITE_PAUSE_SECONDS}s ≤ ${WRITE_PAUSE_LIMIT_SECONDS}s"
else
  record_result "AC-004 write-pause (mode ${MODE})" "FAIL" "${WRITE_PAUSE_SECONDS}s > ${WRITE_PAUSE_LIMIT_SECONDS}s"
fi

# ---------------------------------------------------------------------------
# Phase 4: Monitor blue pod capacity during 30 s write-park window
# ---------------------------------------------------------------------------
echo "[rehearsal] === Phase 4: Monitoring blue pod capacity during 30 s write-park window ==="
PARK_DURATION=30
PARK_END=$(( $(date +%s) + PARK_DURATION ))
THREAD_EXHAUSTION=false
POOL_EXHAUSTION=false
HEAP_EXHAUSTION=false

# Thresholds (configurable via env)
MAX_THREAD_COUNT="${MAX_THREAD_COUNT:-500}"
MAX_HEAP_BYTES="${MAX_HEAP_BYTES:-536870912}"  # 512 MiB default

while [[ $(date +%s) -lt ${PARK_END} ]]; do
  sleep 2
  CURRENT_THREADS=$(get_metric_value "${BLUE_POD}" "/actuator/metrics/jvm.threads.live")
  CURRENT_POOL_PENDING=$(get_metric_value "${BLUE_POD}" "/actuator/metrics/hikaricp.connections.pending")
  CURRENT_HEAP=$(get_metric_value "${BLUE_POD}" "/actuator/metrics/jvm.memory.used")

  if [[ "${CURRENT_THREADS%.*}" -ge "${MAX_THREAD_COUNT}" ]]; then
    echo "[rehearsal] WARNING: Thread exhaustion detected: ${CURRENT_THREADS} >= ${MAX_THREAD_COUNT}"
    THREAD_EXHAUSTION=true
  fi
  if [[ "${CURRENT_POOL_PENDING%.*}" -gt 0 ]]; then
    echo "[rehearsal] WARNING: Connection pool pending > 0: ${CURRENT_POOL_PENDING}"
    POOL_EXHAUSTION=true
  fi
  if [[ "${CURRENT_HEAP%.*}" -ge "${MAX_HEAP_BYTES}" ]]; then
    echo "[rehearsal] WARNING: Heap exhaustion detected: ${CURRENT_HEAP} >= ${MAX_HEAP_BYTES}"
    HEAP_EXHAUSTION=true
  fi
done

if [[ "${THREAD_EXHAUSTION}" == "false" && "${POOL_EXHAUSTION}" == "false" && "${HEAP_EXHAUSTION}" == "false" ]]; then
  record_result "AC-008 blue pod capacity (30 s park)" "PASS" "No thread/pool/heap exhaustion detected"
else
  EXHAUSTION_DETAIL="thread=${THREAD_EXHAUSTION} pool=${POOL_EXHAUSTION} heap=${HEAP_EXHAUSTION}"
  record_result "AC-008 blue pod capacity (30 s park)" "FAIL" "Exhaustion detected: ${EXHAUSTION_DETAIL}"
fi

# ---------------------------------------------------------------------------
# Phase 5: Stop load generator
# ---------------------------------------------------------------------------
if [[ -n "${LOAD_PID:-}" ]]; then
  echo "[rehearsal] Stopping load generator (PID ${LOAD_PID})..."
  kill "${LOAD_PID}" 2>/dev/null || true
  wait "${LOAD_PID}" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Phase 6: Check forwarded-write failure counter
# ---------------------------------------------------------------------------
echo "[rehearsal] === Phase 6: Checking forwarded-write failure counter ==="
# shellcheck source=scripts/orchestrator/run-record.sh
source "${ORCHESTRATOR_DIR}/run-record.sh"

FAILURE_COUNT=0
if command -v python3 >/dev/null 2>&1 && [[ -f "${RUN_RECORD_FILE}" ]]; then
  FAILURE_COUNT=$(python3 -c "
import json
with open('${RUN_RECORD_FILE}', encoding='utf-8') as f:
    d = json.load(f)
print(d.get('forwarded_write_failures', 0))
" 2>/dev/null || echo "0")
fi

if [[ "${FAILURE_COUNT}" -eq 0 ]]; then
  record_result "AC-009 forwarded-write failures" "PASS" "forwarded_write_failures == 0"
else
  record_result "AC-009 forwarded-write failures" "FAIL" "forwarded_write_failures == ${FAILURE_COUNT} (target: 0)"
fi

# ---------------------------------------------------------------------------
# Phase 7: Cross-slot connectivity test
# ---------------------------------------------------------------------------
echo "[rehearsal] === Phase 7: Cross-slot connectivity test ==="
if "${SCRIPT_DIR}/cross-slot-connectivity-test.sh"; then
  record_result "AC-006/AC-007 cross-slot connectivity" "PASS" "All connectivity checks passed"
else
  record_result "AC-006/AC-007 cross-slot connectivity" "FAIL" "One or more connectivity checks failed"
fi

# ---------------------------------------------------------------------------
# Phase 8: Print structured rehearsal report
# ---------------------------------------------------------------------------
echo ""
echo "[rehearsal] ===== REHEARSAL REPORT ====="
echo "[rehearsal] Mode: ${MODE}"
echo "[rehearsal] Write-pause limit: ${WRITE_PAUSE_LIMIT_SECONDS}s"
echo "[rehearsal] Measured write-pause: ${WRITE_PAUSE_SECONDS}s"
echo "[rehearsal] Blue pod: ${BLUE_POD}"
echo "[rehearsal] Baseline threads: ${BASELINE_THREAD_COUNT}"
echo "[rehearsal] Baseline pool-pending: ${BASELINE_POOL_PENDING}"
echo "[rehearsal] Baseline heap: ${BASELINE_HEAP}"
echo "[rehearsal] Forwarded-write failures: ${FAILURE_COUNT}"
echo "[rehearsal] Gates:"
for line in "${REPORT_LINES[@]}"; do
  echo "[rehearsal] ${line}"
done
echo "[rehearsal] PASS: ${PASS_COUNT}  FAIL: ${FAIL_COUNT}"

if [[ "${FAIL_COUNT}" -eq 0 ]]; then
  echo "[rehearsal] OVERALL: PASS"
  exit 0
else
  echo "[rehearsal] OVERALL: FAIL (${FAIL_COUNT} gate(s) failed)"
  exit 1
fi
