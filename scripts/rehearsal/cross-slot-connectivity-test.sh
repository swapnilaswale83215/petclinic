#!/usr/bin/env bash
# cross-slot-connectivity-test.sh — Cross-slot and external-isolation connectivity validation.
#
# Validates:
#   (a) A green pod can reach petclinic-blue:8080 (kubectl exec curl)
#   (b) A blue pod can reach petclinic-green:8080 (kubectl exec curl)
#   (c) External curl to petclinic-blue:8080 fails (ClusterIP-only isolation)
#   (d) External curl to petclinic-green:8080 fails (ClusterIP-only isolation)
#   (e) Both Services show type=ClusterIP, port=8080, EXTERNAL-IP=<none>
#
# Usage:
#   BLUE_POD=petclinic-blue-xxx GREEN_POD=petclinic-green-xxx NAMESPACE=default \
#     ./scripts/rehearsal/cross-slot-connectivity-test.sh
#
# Environment variables:
#   BLUE_POD    Name of a blue pod (auto-detected if not set)
#   GREEN_POD   Name of a green pod (auto-detected if not set)
#   NAMESPACE   Kubernetes namespace (default: default)
#   HEALTH_PATH Actuator health path (default: /actuator/health)
#
# Exit codes:
#   0  All checks passed
#   1  One or more checks failed

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
NAMESPACE="${NAMESPACE:-default}"
HEALTH_PATH="${HEALTH_PATH:-/actuator/health}"

# Auto-detect pods if not provided
if [[ -z "${BLUE_POD:-}" ]]; then
  BLUE_POD=$(kubectl get pods \
    --namespace "${NAMESPACE}" \
    -l slot=blue \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
fi

if [[ -z "${GREEN_POD:-}" ]]; then
  GREEN_POD=$(kubectl get pods \
    --namespace "${NAMESPACE}" \
    -l slot=green \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
PASS_COUNT=0
FAIL_COUNT=0

check_pass() {
  local label="$1"
  echo "  [PASS] ${label}"
  PASS_COUNT=$(( PASS_COUNT + 1 ))
}

check_fail() {
  local label="$1"
  local detail="$2"
  echo "  [FAIL] ${label}: ${detail}" >&2
  FAIL_COUNT=$(( FAIL_COUNT + 1 ))
}

# ---------------------------------------------------------------------------
# Check (e): Service type and external IP via kubectl
# ---------------------------------------------------------------------------
echo "[cross-slot] === Check (e): Service type and external IP ==="

for svc_name in petclinic-blue petclinic-green; do
  SVC_TYPE=$(kubectl get service "${svc_name}" \
    --namespace "${NAMESPACE}" \
    -o jsonpath='{.spec.type}' 2>/dev/null || echo "NOT_FOUND")
  SVC_PORT=$(kubectl get service "${svc_name}" \
    --namespace "${NAMESPACE}" \
    -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "0")
  SVC_EXTERNAL_IP=$(kubectl get service "${svc_name}" \
    --namespace "${NAMESPACE}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

  if [[ "${SVC_TYPE}" == "ClusterIP" ]]; then
    check_pass "${svc_name} type=ClusterIP"
  else
    check_fail "${svc_name} type" "expected ClusterIP, got ${SVC_TYPE}"
  fi

  if [[ "${SVC_PORT}" == "8080" ]]; then
    check_pass "${svc_name} port=8080"
  else
    check_fail "${svc_name} port" "expected 8080, got ${SVC_PORT}"
  fi

  if [[ -z "${SVC_EXTERNAL_IP}" ]]; then
    check_pass "${svc_name} EXTERNAL-IP=<none>"
  else
    check_fail "${svc_name} EXTERNAL-IP" "expected <none>, got ${SVC_EXTERNAL_IP}"
  fi
done

# ---------------------------------------------------------------------------
# Check (a): Green pod can reach petclinic-blue:8080
# ---------------------------------------------------------------------------
echo "[cross-slot] === Check (a): Green pod → petclinic-blue:8080 ==="

if [[ -z "${GREEN_POD}" ]]; then
  check_fail "green→blue connectivity" "No green pod found (selector slot=green)"
else
  if kubectl exec "${GREEN_POD}" \
    --namespace "${NAMESPACE}" \
    -- curl -sf "http://petclinic-blue:8080${HEALTH_PATH}" >/dev/null 2>&1; then
    check_pass "green pod '${GREEN_POD}' → petclinic-blue:8080${HEALTH_PATH}"
  else
    check_fail "green pod '${GREEN_POD}' → petclinic-blue:8080" "curl failed (expected success)"
  fi
fi

# ---------------------------------------------------------------------------
# Check (b): Blue pod can reach petclinic-green:8080
# ---------------------------------------------------------------------------
echo "[cross-slot] === Check (b): Blue pod → petclinic-green:8080 ==="

if [[ -z "${BLUE_POD}" ]]; then
  check_fail "blue→green connectivity" "No blue pod found (selector slot=blue)"
else
  if kubectl exec "${BLUE_POD}" \
    --namespace "${NAMESPACE}" \
    -- curl -sf "http://petclinic-green:8080${HEALTH_PATH}" >/dev/null 2>&1; then
    check_pass "blue pod '${BLUE_POD}' → petclinic-green:8080${HEALTH_PATH}"
  else
    check_fail "blue pod '${BLUE_POD}' → petclinic-green:8080" "curl failed (expected success)"
  fi
fi

# ---------------------------------------------------------------------------
# Check (c) and (d): External access to petclinic-blue and petclinic-green must fail
# ---------------------------------------------------------------------------
echo "[cross-slot] === Checks (c)+(d): External access must fail ==="

for svc_name in petclinic-blue petclinic-green; do
  SVC_CLUSTER_IP=$(kubectl get service "${svc_name}" \
    --namespace "${NAMESPACE}" \
    -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")

  if [[ -z "${SVC_CLUSTER_IP}" || "${SVC_CLUSTER_IP}" == "None" ]]; then
    check_fail "external access to ${svc_name}" "Could not determine ClusterIP"
    continue
  fi

  # Attempt external curl with a short timeout; expect failure
  if curl -sf --connect-timeout 3 --max-time 5 \
    "http://${SVC_CLUSTER_IP}:8080${HEALTH_PATH}" >/dev/null 2>&1; then
    # If curl succeeded from outside the cluster, that is a violation
    check_fail "external access to ${svc_name} (${SVC_CLUSTER_IP}:8080)" \
      "curl succeeded from outside cluster — ClusterIP isolation violated"
  else
    check_pass "external access to ${svc_name} (${SVC_CLUSTER_IP}:8080) correctly refused"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "[cross-slot] ===== CONNECTIVITY TEST SUMMARY ====="
echo "[cross-slot] PASS: ${PASS_COUNT}  FAIL: ${FAIL_COUNT}"

if [[ "${FAIL_COUNT}" -eq 0 ]]; then
  echo "[cross-slot] OVERALL: PASS"
  exit 0
else
  echo "[cross-slot] OVERALL: FAIL (${FAIL_COUNT} check(s) failed)" >&2
  exit 1
fi
