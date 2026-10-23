#!/usr/bin/env bash
# rollback.sh — Atomic abort/rollback selector patch (green → blue) with Endpoints verification.
#
# Usage:
#   SHARED_SERVICE_NAME=petclinic NAMESPACE=default ./scripts/orchestrator/rollback.sh
#
# Environment variables:
#   SHARED_SERVICE_NAME        Name of the shared Kubernetes Service (required)
#   NAMESPACE                  Kubernetes namespace (default: default)
#   ENDPOINTS_TIMEOUT_SECONDS  Seconds to wait for blue-only Endpoints (default: 5)
#
# Exit codes:
#   0  Selector reverted to blue and Endpoints verified blue-only within timeout
#   1  Endpoints not blue-only within timeout, or patch failed

set -euo pipefail

# ---------------------------------------------------------------------------
# Source the run-record helper
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/orchestrator/run-record.sh
source "${SCRIPT_DIR}/run-record.sh"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SHARED_SERVICE_NAME="${SHARED_SERVICE_NAME:-}"
NAMESPACE="${NAMESPACE:-default}"
ENDPOINTS_TIMEOUT_SECONDS="${ENDPOINTS_TIMEOUT_SECONDS:-5}"

if [[ -z "${SHARED_SERVICE_NAME}" ]]; then
  echo "ERROR: SHARED_SERVICE_NAME environment variable is required" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 1: Issue exactly one atomic merge PATCH to revert selector to blue
# ---------------------------------------------------------------------------
echo "[rollback] Patching service '${SHARED_SERVICE_NAME}' selector back to slot=blue..."
kubectl patch service "${SHARED_SERVICE_NAME}" \
  --namespace "${NAMESPACE}" \
  --type=merge \
  -p '{"spec":{"selector":{"slot":"blue"}}}'
echo "[rollback] Selector patch applied."

# ---------------------------------------------------------------------------
# Step 2: Poll Endpoints and verify all addresses belong to blue pods
# ---------------------------------------------------------------------------
echo "[rollback] Verifying Endpoints are blue-only (timeout: ${ENDPOINTS_TIMEOUT_SECONDS}s)..."

DEADLINE=$(( $(date +%s) + ENDPOINTS_TIMEOUT_SECONDS ))
VERIFIED=false
NON_BLUE_IP=""

while [[ $(date +%s) -lt ${DEADLINE} ]]; do
  # Collect all Endpoint addresses for the shared Service
  ENDPOINT_IPS=$(kubectl get endpoints "${SHARED_SERVICE_NAME}" \
    --namespace "${NAMESPACE}" \
    -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}' 2>/dev/null | sort -u)

  if [[ -z "${ENDPOINT_IPS}" ]]; then
    echo "[rollback] Endpoints not yet populated, retrying..."
    sleep 0.5
    continue
  fi

  # Collect IPs of all blue pods
  BLUE_POD_IPS=$(kubectl get pods \
    --namespace "${NAMESPACE}" \
    -l slot=blue \
    -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' 2>/dev/null | sort -u)

  if [[ -z "${BLUE_POD_IPS}" ]]; then
    echo "[rollback] No blue pods found yet, retrying..."
    sleep 0.5
    continue
  fi

  # Check every Endpoint address is a blue pod IP
  NON_BLUE_IP=""
  while IFS= read -r ep_ip; do
    [[ -z "${ep_ip}" ]] && continue
    if ! echo "${BLUE_POD_IPS}" | grep -qx "${ep_ip}"; then
      NON_BLUE_IP="${ep_ip}"
      break
    fi
  done <<< "${ENDPOINT_IPS}"

  if [[ -z "${NON_BLUE_IP}" ]]; then
    VERIFIED=true
    break
  fi

  echo "[rollback] Non-blue address still present: ${NON_BLUE_IP}, retrying..."
  sleep 0.5
done

if [[ "${VERIFIED}" == "true" ]]; then
  echo "[rollback] Rollback complete: blue-only Endpoints verified"
  exit 0
else
  echo "ERROR: [rollback] Endpoints not blue-only within ${ENDPOINTS_TIMEOUT_SECONDS}s. Non-blue address: ${NON_BLUE_IP:-unknown}" >&2
  exit 1
fi
