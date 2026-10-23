#!/usr/bin/env bash
# switch.sh — Atomic forward selector patch (blue → green) with Endpoints verification.
#
# Usage:
#   SHARED_SERVICE_NAME=petclinic NAMESPACE=default ./scripts/orchestrator/switch.sh
#
# Environment variables:
#   SHARED_SERVICE_NAME        Name of the shared Kubernetes Service (required)
#   NAMESPACE                  Kubernetes namespace (default: default)
#   ENDPOINTS_TIMEOUT_SECONDS  Seconds to wait for green-only Endpoints (default: 5)
#
# Exit codes:
#   0  Selector patched and Endpoints verified green-only within timeout
#   1  Endpoints not green-only within timeout, or patch failed

set -euo pipefail

# ---------------------------------------------------------------------------
# Source the run-record helper so the forwarded-write failure counter is
# available throughout the orchestration sequence.
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
# Step 1: Record pre-patch selector for rollback reference
# ---------------------------------------------------------------------------
echo "[switch] Recording pre-patch selector for rollback reference..."
PRE_PATCH_SELECTOR=$(kubectl get service "${SHARED_SERVICE_NAME}" \
  --namespace "${NAMESPACE}" \
  -o jsonpath='{.spec.selector}' 2>/dev/null || echo "unknown")
echo "[switch] Pre-patch selector: ${PRE_PATCH_SELECTOR}"

# ---------------------------------------------------------------------------
# Step 2: Issue exactly one atomic merge PATCH to switch selector to green
# ---------------------------------------------------------------------------
echo "[switch] Patching service '${SHARED_SERVICE_NAME}' selector to slot=green..."
kubectl patch service "${SHARED_SERVICE_NAME}" \
  --namespace "${NAMESPACE}" \
  --type=merge \
  -p '{"spec":{"selector":{"slot":"green"}}}'
echo "[switch] Selector patch applied."

# ---------------------------------------------------------------------------
# Step 3: Poll Endpoints and verify all addresses belong to green pods
# ---------------------------------------------------------------------------
echo "[switch] Verifying Endpoints are green-only (timeout: ${ENDPOINTS_TIMEOUT_SECONDS}s)..."

DEADLINE=$(( $(date +%s) + ENDPOINTS_TIMEOUT_SECONDS ))
VERIFIED=false

while [[ $(date +%s) -lt ${DEADLINE} ]]; do
  # Collect all Endpoint addresses for the shared Service
  ENDPOINT_IPS=$(kubectl get endpoints "${SHARED_SERVICE_NAME}" \
    --namespace "${NAMESPACE}" \
    -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}' 2>/dev/null | sort -u)

  if [[ -z "${ENDPOINT_IPS}" ]]; then
    echo "[switch] Endpoints not yet populated, retrying..."
    sleep 0.5
    continue
  fi

  # Collect IPs of all green pods
  GREEN_POD_IPS=$(kubectl get pods \
    --namespace "${NAMESPACE}" \
    -l slot=green \
    -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' 2>/dev/null | sort -u)

  if [[ -z "${GREEN_POD_IPS}" ]]; then
    echo "[switch] No green pods found yet, retrying..."
    sleep 0.5
    continue
  fi

  # Check every Endpoint address is a green pod IP
  NON_GREEN_IP=""
  while IFS= read -r ep_ip; do
    [[ -z "${ep_ip}" ]] && continue
    if ! echo "${GREEN_POD_IPS}" | grep -qx "${ep_ip}"; then
      NON_GREEN_IP="${ep_ip}"
      break
    fi
  done <<< "${ENDPOINT_IPS}"

  if [[ -z "${NON_GREEN_IP}" ]]; then
    VERIFIED=true
    break
  fi

  echo "[switch] Non-green address still present: ${NON_GREEN_IP}, retrying..."
  sleep 0.5
done

if [[ "${VERIFIED}" == "true" ]]; then
  echo "[switch] Endpoints verified: green-only"
  exit 0
else
  echo "ERROR: [switch] Endpoints not green-only within ${ENDPOINTS_TIMEOUT_SECONDS}s. Non-green address: ${NON_GREEN_IP:-unknown}" >&2
  increment_forwarded_write_failure "Endpoints not green-only after forward patch: non-green IP ${NON_GREEN_IP:-unknown}"
  exit 1
fi
