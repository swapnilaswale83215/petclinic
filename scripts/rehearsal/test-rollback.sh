#!/usr/bin/env bash
# test-rollback.sh — Abort/rollback integration test (5-second revert SLA).
#
# Assertions:
#   1. Exactly one PATCH call is issued to the shared Service reverting selector to blue.
#   2. kubectl confirms spec.selector is the blue-slot label within ENDPOINTS_TIMEOUT_SECONDS.
#   3. Endpoints contains only blue pod addresses within ENDPOINTS_TIMEOUT_SECONDS.
#
# Usage:
#   SHARED_SERVICE_NAME=petclinic NAMESPACE=default \
#     ./scripts/rehearsal/test-rollback.sh
#
# Environment variables:
#   SHARED_SERVICE_NAME        Name of the shared Kubernetes Service (required)
#   NAMESPACE                  Kubernetes namespace (default: default)
#   ENDPOINTS_TIMEOUT_SECONDS  Seconds to wait for blue-only Endpoints (default: 5)

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
# Pre-condition: ensure selector is currently green so rollback has something to revert
# ---------------------------------------------------------------------------
echo "[test-rollback] Setting selector to green as pre-condition..."
kubectl patch service "${SHARED_SERVICE_NAME}" \
  --namespace "${NAMESPACE}" \
  --type=merge \
  -p '{"spec":{"selector":{"slot":"green"}}}' >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Assertion 1: Exactly one PATCH call is issued
# ---------------------------------------------------------------------------
echo "[test-rollback] === Assertion 1: Single PATCH call ==="

PATCH_COUNT_FILE=$(mktemp)
echo "0" > "${PATCH_COUNT_FILE}"

WRAPPER_DIR=$(mktemp -d)
cat > "${WRAPPER_DIR}/kubectl" <<'WRAPPER'
#!/usr/bin/env bash
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

# Run the rollback script
if "${ORCHESTRATOR_DIR}/rollback.sh" 2>&1; then
  ROLLBACK_EXIT=0
else
  ROLLBACK_EXIT=$?
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
# Assertion 2: spec.selector is the blue-slot label within timeout
# ---------------------------------------------------------------------------
echo "[test-rollback] === Assertion 2: spec.selector reverted to blue within ${ENDPOINTS_TIMEOUT_SECONDS}s ==="

if [[ "${ROLLBACK_EXIT}" -eq 0 ]]; then
  SELECTOR_SLOT=$(kubectl get service "${SHARED_SERVICE_NAME}" \
    --namespace "${NAMESPACE}" \
    -o jsonpath='{.spec.selector.slot}' 2>/dev/null || echo "")

  if [[ "${SELECTOR_SLOT}" == "blue" ]]; then
    assert_pass "spec.selector.slot == blue within ${ENDPOINTS_TIMEOUT_SECONDS}s"
  else
    assert_fail "spec.selector reverted to blue" "Expected slot=blue, got slot=${SELECTOR_SLOT:-<empty>}"
  fi
else
  assert_fail "spec.selector reverted to blue" "rollback.sh exited non-zero (${ROLLBACK_EXIT})"
fi

# ---------------------------------------------------------------------------
# Assertion 3: Endpoints contains only blue pod addresses within timeout
# ---------------------------------------------------------------------------
echo "[test-rollback] === Assertion 3: Endpoints contains only blue pod addresses ==="

if [[ "${ROLLBACK_EXIT}" -eq 0 ]]; then
  ENDPOINT_IPS=$(kubectl get endpoints "${SHARED_SERVICE_NAME}" \
    --namespace "${NAMESPACE}" \
    -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}' 2>/dev/null | sort -u)

  BLUE_POD_IPS=$(kubectl get pods \
    --namespace "${NAMESPACE}" \
    -l slot=blue \
    -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' 2>/dev/null | sort -u)

  NON_BLUE_IP=""
  while IFS= read -r ep_ip; do
    [[ -z "${ep_ip}" ]] && continue
    if ! echo "${BLUE_POD_IPS}" | grep -qx "${ep_ip}"; then
      NON_BLUE_IP="${ep_ip}"
      break
    fi
  done <<< "${ENDPOINT_IPS}"

  if [[ -z "${NON_BLUE_IP}" && -n "${ENDPOINT_IPS}" ]]; then
    assert_pass "Endpoints contains only blue pod addresses within ${ENDPOINTS_TIMEOUT_SECONDS}s"
  else
    assert_fail "Blue-only Endpoints" "Non-blue address found: ${NON_BLUE_IP:-none (empty endpoints)}"
  fi
else
  assert_fail "Blue-only Endpoints" "rollback.sh exited non-zero (${ROLLBACK_EXIT}); Endpoints not verified"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "[test-rollback] ===== TEST SUMMARY ====="
echo "[test-rollback] PASS: ${PASS_COUNT}  FAIL: ${FAIL_COUNT}"

if [[ "${FAIL_COUNT}" -eq 0 ]]; then
  echo "[test-rollback] OVERALL: PASS"
  exit 0
else
  echo "[test-rollback] OVERALL: FAIL (${FAIL_COUNT} assertion(s) failed)" >&2
  exit 1
fi
