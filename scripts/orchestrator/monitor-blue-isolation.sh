#!/usr/bin/env bash
# monitor-blue-isolation.sh — Monitor blue pods for direct client requests after the
# forward selector patch.  Runs for MONITOR_DURATION_SECONDS (default 30) and alerts
# if any blue pod's request counter increments, indicating a direct client request
# bypassed the selector switch.
#
# Usage:
#   BLUE_POD_SELECTOR=slot=blue NAMESPACE=default ./scripts/orchestrator/monitor-blue-isolation.sh
#
# Environment variables:
#   BLUE_POD_SELECTOR        kubectl label selector for blue pods (default: slot=blue)
#   NAMESPACE                Kubernetes namespace (default: default)
#   MONITOR_DURATION_SECONDS Duration of the monitoring window in seconds (default: 30)
#   METRICS_PATH             Actuator metrics path inside the pod (default: /actuator/metrics/http.server.requests)
#   METRICS_PORT             Port for the actuator endpoint inside the pod (default: 8080)
#
# Exit codes:
#   0  No direct client requests detected on blue pods during the monitoring window
#   1  One or more direct client requests detected on blue pods

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
BLUE_POD_SELECTOR="${BLUE_POD_SELECTOR:-slot=blue}"
NAMESPACE="${NAMESPACE:-default}"
MONITOR_DURATION_SECONDS="${MONITOR_DURATION_SECONDS:-30}"
METRICS_PATH="${METRICS_PATH:-/actuator/metrics/http.server.requests}"
METRICS_PORT="${METRICS_PORT:-8080}"
PROBE_INTERVAL=2

# ---------------------------------------------------------------------------
# Collect baseline request counts for all blue pods
# ---------------------------------------------------------------------------
echo "[monitor-blue-isolation] Collecting baseline request counts for blue pods (selector: ${BLUE_POD_SELECTOR})..."

declare -A BASELINE_COUNTS

BLUE_PODS=$(kubectl get pods \
  --namespace "${NAMESPACE}" \
  -l "${BLUE_POD_SELECTOR}" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)

if [[ -z "${BLUE_PODS}" ]]; then
  echo "[monitor-blue-isolation] WARNING: No blue pods found matching selector '${BLUE_POD_SELECTOR}'" >&2
  echo "[monitor-blue-isolation] blue-isolation-clean: 0 violations in ${MONITOR_DURATION_SECONDS}s (no pods to monitor)"
  exit 0
fi

while IFS= read -r pod_name; do
  [[ -z "${pod_name}" ]] && continue
  count=$(kubectl exec "${pod_name}" \
    --namespace "${NAMESPACE}" \
    -- curl -sf "http://localhost:${METRICS_PORT}${METRICS_PATH}" 2>/dev/null \
    | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*' || echo "0")
  BASELINE_COUNTS["${pod_name}"]="${count}"
  echo "[monitor-blue-isolation] Baseline for pod ${pod_name}: ${count} requests"
done <<< "${BLUE_PODS}"

# ---------------------------------------------------------------------------
# Monitor loop
# ---------------------------------------------------------------------------
echo "[monitor-blue-isolation] Starting ${MONITOR_DURATION_SECONDS}s isolation monitor..."

START_TIME=$(date +%s)
DEADLINE=$(( START_TIME + MONITOR_DURATION_SECONDS ))
VIOLATION_COUNT=0

while [[ $(date +%s) -lt ${DEADLINE} ]]; do
  sleep "${PROBE_INTERVAL}"
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  while IFS= read -r pod_name; do
    [[ -z "${pod_name}" ]] && continue
    current_count=$(kubectl exec "${pod_name}" \
      --namespace "${NAMESPACE}" \
      -- curl -sf "http://localhost:${METRICS_PORT}${METRICS_PATH}" 2>/dev/null \
      | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*' || echo "0")

    baseline="${BASELINE_COUNTS[${pod_name}]:-0}"
    if [[ "${current_count}" -gt "${baseline}" ]]; then
      echo "ALERT: direct client request detected on blue pod ${pod_name} at ${TIMESTAMP}"
      VIOLATION_COUNT=$(( VIOLATION_COUNT + 1 ))
      # Update baseline so we count each new increment, not cumulative
      BASELINE_COUNTS["${pod_name}"]="${current_count}"
    fi
  done <<< "${BLUE_PODS}"
done

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
if [[ "${VIOLATION_COUNT}" -eq 0 ]]; then
  echo "[monitor-blue-isolation] blue-isolation-clean: 0 violations in ${MONITOR_DURATION_SECONDS}s"
  exit 0
else
  echo "ERROR: [monitor-blue-isolation] ${VIOLATION_COUNT} direct client request violation(s) detected on blue pods in ${MONITOR_DURATION_SECONDS}s" >&2
  exit 1
fi
