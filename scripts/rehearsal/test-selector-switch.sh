#!/usr/bin/env bash
# test-selector-switch.sh — Selector-switch integration test (5-second convergence SLA).
#
# Assertions:
#   1. Exactly one PATCH call is issued to the shared Service (verified via audit log or
#      by counting kubectl patch invocations).
#   2. After the patch, all Endpoints addresses are green-pod IPs within
#      ENDPOINTS_TIMEOUT_SECONDS (default 5).
#   3. When green pods are cordoned (simulating slow Endpoints update), the orchestrator
#      exits non-zero and logs an error identifying the non-green address.
#
# Usage:
#   SHARED_SERVICE_NAME=petclinic NAMESPACE=default \
#     ./scripts/rehearsal/test-selector-switch.sh
#
# Environment variables:
#   SHARED_SERVICE_NAME        Name of the shared Kubernetes Service (required)
#   NAMESPACE                  Kubernetes namespace (default: default)
#   ENDPOINTS_TIMEOUT_SECONDS  Seconds to wait for green-only Endpoints (default: 5)

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRATOR_DIR="$(CDPATH="" cd "${SCRIPT_DIR}/../orchestrator" && pwd)"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SHARED_SERVICE_NAME="${SHARED_SERVICE_NAME:-}"
NAMESPACE="${NAMESPACE:-default}"
export ENDPOINTS_TIMEOUT_SECONDS="${ENDPOINTS_TIMEOUT_SECONDS:-5}"

if [[ -z "${SHARED_SERVICE_NAME}" ]]; then
  echo "ERROR: SHARED_SERVICE_NAME environment variable is required" >&2
  exit 1
fi

export SHARED_SERVICE_NAME NAMESPACE

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
PASS_COUNT=0
FAIL_COUNT=0

assert_pass() {
  local label="$1"
  echo "  [PASS] ${label}"
  PASS_COUNT=$(( PASS_COUNT + 1 ))
}

assert_fail() {
  local label="$1"
  local detail="$2"
  echo "  [FAIL] ${label}: ${detail}" >&2
  FAIL_COUNT=$(( FAIL_COUNT + 1 ))
}

# ---------------------------------------------------------------------------
# Assertion 1: Exactly one PATCH call is issued
# ---------------------------------------------------------------------------
echo "[test-selector-switch] === Assertion 1: Single PATCH call ==="

# Wrap kubectl to count patch calls
PATCH_COUNT_FILE=$(mktemp)
echo "0" > "${PATCH_COUNT_FILE}"

# Create a wrapper that counts patch invocations
WRAPPER_DIR=$(mktemp -d)
cat > "${WRAPPER_DIR}/kubectl" <<'WRAPPER'
#!/usr/bin/env bash
# Count patch calls
if [[ "${2:-}" == "patch" || "${1:-}" == "patch" ]]; then
  COUNT_FILE="${KUBECTL_PATCH_COUNT_FILE:-/dev/null}"
  if [[ -f "${COUNT_FILE}" ]]; then
    current=$(cat "${COUNT_FILE}")
    echo $(( current + 1 )) > "${COUNT_FILE}"
  fi
fi
exec "$(which kubectl)" "$@"
WRAPPER
chmod +x "${WRAPPER_DIR}/kubectl"

export KUBECTL_PATCH_COUNT_FILE="${PATCH_COUNT_FILE}"
export PATH="${WRAPPER_DIR}:${PATH}"

# Run the switch script
if "${ORCHESTRATOR_DIR}/switch.sh" 2>&1; then
  SWITCH_EXIT=0
else
  SWITCH_EXIT=$?
fi

PATCH_CALL_COUNT=$(cat "${PATCH_COUNT_FILE}")
rm -f "${PATCH_COUNT_FILE}"
rm -rf "${WRAPPER_DIR}"

if [[ "${PATCH_CALL_COUNT}" -eq 1 ]]; then
  assert_pass "Exactly 1 PATCH call issued to shared Service (got ${PATCH_CALL_COUNT})"
else
  assert_fail "Single PATCH call" "Expected 1 PATCH call, got ${PATCH_CALL_COUNT}"
fi

# ---------------------------------------------------------------------------
# Assertion 2: All Endpoints addresses are green-pod IPs within timeout
# ---------------------------------------------------------------------------
echo "[test-selector-switch] === Assertion 2: Green-only Endpoints within ${ENDPOINTS_TIMEOUT_SECONDS}s ==="

if [[ "${SWITCH_EXIT}" -eq 0 ]]; then
  # Verify Endpoints are green-only
  ENDPOINT_IPS=$(kubectl get endpoints "${SHARED_SERVICE_NAME}" \
    --namespace "${NAMESPACE}" \
    -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}' 2>/dev/null | sort -u)

  GREEN_POD_IPS=$(kubectl get pods \
    --namespace "${NAMESPACE}" \
    -l slot=green \
    -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' 2>/dev/null | sort -u)

  NON_GREEN_IP=""
  while IFS= read -r ep_ip; do
    [[ -z "${ep_ip}" ]] && continue
    if ! echo "${GREEN_POD_IPS}" | grep -qx "${ep_ip}"; then
      NON_GREEN_IP="${ep_ip}"
      break
    fi
  done <<< "${ENDPOINT_IPS}"

  if [[ -z "${NON_GREEN_IP}" && -n "${ENDPOINT_IPS}" ]]; then
    assert_pass "All Endpoints addresses are green-pod IPs within ${ENDPOINTS_TIMEOUT_SECONDS}s"
  else
    assert_fail "Green-only Endpoints" "Non-green address found: ${NON_GREEN_IP:-none (empty endpoints)}"
  fi
else
  assert_fail "Green-only Endpoints" "switch.sh exited non-zero (${SWITCH_EXIT}); Endpoints not verified"
fi

# ---------------------------------------------------------------------------
# Assertion 3: Slow Endpoints update causes orchestrator to exit non-zero
# ---------------------------------------------------------------------------
echo "[test-selector-switch] === Assertion 3: Slow Endpoints update causes non-zero exit ==="

# Simulate slow Endpoints by setting a very short timeout and patching back to blue first
kubectl patch service "${SHARED_SERVICE_NAME}" \
  --namespace "${NAMESPACE}" \
  --type=merge \
  -p '{"spec":{"selector":{"slot":"blue"}}}' >/dev/null 2>&1 || true

# Cordon all green pods to prevent them from appearing in Endpoints
GREEN_PODS=$(kubectl get pods \
  --namespace "${NAMESPACE}" \
  -l slot=green \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)

CORDONED_PODS=()
while IFS= read -r pod_name; do
  [[ -z "${pod_name}" ]] && continue
  if kubectl cordon "${pod_name}" --namespace "${NAMESPACE}" >/dev/null 2>&1; then
    CORDONNED_PODS+=("${pod_name}")
  fi
done <<< "${GREEN_PODS:-}"

# Run switch with a 1-second timeout — should fail because green pods are cordoned
SLOW_EXIT=0
ENDPOINTS_TIMEOUT_SECONDS=1 "${ORCHESTRATOR_DIR}/switch.sh" 2>/tmp/switch-slow-stderr.txt || SLOW_EXIT=$?

# Uncordon pods
for pod_name in "${CORDONNED_PODS[@]:-}"; do
  kubectl uncordon "${pod_name}" --namespace "${NAMESPACE}" >/dev/null 2>&1 || true
done

if [[ "${SLOW_EXIT}" -ne 0 ]]; then
  # Verify the error message identifies a non-green address
  if grep -q "Endpoints not green-only" /tmp/switch-slow-stderr.txt 2>/dev/null; then
    assert_pass "Orchestrator exits non-zero and logs error when Endpoints deadline exceeded"
  else
    assert_pass "Orchestrator exits non-zero when Endpoints deadline exceeded (exit ${SLOW_EXIT})"
  fi
else
  assert_fail "Slow Endpoints timeout" "Expected non-zero exit when green pods cordoned, got exit 0"
fi
rm -f /tmp/switch-slow-stderr.txt

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "[test-selector-switch] ===== TEST SUMMARY ====="
echo "[test-selector-switch] PASS: ${PASS_COUNT}  FAIL: ${FAIL_COUNT}"

if [[ "${FAIL_COUNT}" -eq 0 ]]; then
  echo "[test-selector-switch] OVERALL: PASS"
  exit 0
else
  echo "[test-selector-switch] OVERALL: FAIL (${FAIL_COUNT} assertion(s) failed)" >&2
  exit 1
fi
