#!/usr/bin/env bash
# test_clusterip_topology.sh — Integration test TC4: ClusterIP Service topology validation.
#
# TC4: Verify that petclinic-blue and petclinic-green Services:
#   - Exist as ClusterIP type
#   - Expose only port 8080
#   - Are unreachable from outside the cluster
#   - Intra-cluster connectivity from blue pod to petclinic-green:8080 succeeds
#   - Intra-cluster connectivity from green pod to petclinic-blue:8080 succeeds
#
# Usage:
#   test_clusterip_topology.sh [--namespace <ns>]
#
# Exit codes:
#   0  TC4 passed.
#   1  TC4 failed.

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
TC_ID="TC4"

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
# Helper: assert a condition, emit PASS/FAIL
# ---------------------------------------------------------------------------
assert_pass() {
  local description="$1"
  local result="$2"  # "0" = pass, non-zero = fail
  if [[ "$result" == "0" ]]; then
    log_pass "${TC_ID}: ${description}"
  else
    log_fail "${TC_ID}: ${description}"
    FAILURES=$(( FAILURES + 1 ))
  fi
}

# ---------------------------------------------------------------------------
# Check 1: petclinic-blue exists as ClusterIP
# ---------------------------------------------------------------------------
log_info "${TC_ID}: Checking petclinic-blue Service type..."
BLUE_TYPE=$(kubectl get service petclinic-blue \
  --namespace "$NAMESPACE" \
  -o jsonpath='{.spec.type}' 2>/dev/null) || BLUE_TYPE="NOT_FOUND"

if [[ "$BLUE_TYPE" == "ClusterIP" ]]; then
  assert_pass "petclinic-blue type=ClusterIP" "0"
else
  assert_pass "petclinic-blue type=ClusterIP (got: $BLUE_TYPE)" "1"
fi

# ---------------------------------------------------------------------------
# Check 2: petclinic-green exists as ClusterIP
# ---------------------------------------------------------------------------
log_info "${TC_ID}: Checking petclinic-green Service type..."
GREEN_TYPE=$(kubectl get service petclinic-green \
  --namespace "$NAMESPACE" \
  -o jsonpath='{.spec.type}' 2>/dev/null) || GREEN_TYPE="NOT_FOUND"

if [[ "$GREEN_TYPE" == "ClusterIP" ]]; then
  assert_pass "petclinic-green type=ClusterIP" "0"
else
  assert_pass "petclinic-green type=ClusterIP (got: $GREEN_TYPE)" "1"
fi

# ---------------------------------------------------------------------------
# Check 3: petclinic-blue exposes only port 8080
# ---------------------------------------------------------------------------
log_info "${TC_ID}: Checking petclinic-blue port..."
BLUE_PORT=$(kubectl get service petclinic-blue \
  --namespace "$NAMESPACE" \
  -o jsonpath='{.spec.ports[0].port}' 2>/dev/null) || BLUE_PORT=""
BLUE_PORT_COUNT=$(kubectl get service petclinic-blue \
  --namespace "$NAMESPACE" \
  -o jsonpath='{range .spec.ports[*]}{.port}{"\n"}{end}' 2>/dev/null | wc -l | tr -d ' ') || BLUE_PORT_COUNT=0

if [[ "$BLUE_PORT" == "8080" && "$BLUE_PORT_COUNT" == "1" ]]; then
  assert_pass "petclinic-blue exposes only port 8080" "0"
else
  assert_pass "petclinic-blue exposes only port 8080 (port=$BLUE_PORT count=$BLUE_PORT_COUNT)" "1"
fi

# ---------------------------------------------------------------------------
# Check 4: petclinic-green exposes only port 8080
# ---------------------------------------------------------------------------
log_info "${TC_ID}: Checking petclinic-green port..."
GREEN_PORT=$(kubectl get service petclinic-green \
  --namespace "$NAMESPACE" \
  -o jsonpath='{.spec.ports[0].port}' 2>/dev/null) || GREEN_PORT=""
GREEN_PORT_COUNT=$(kubectl get service petclinic-green \
  --namespace "$NAMESPACE" \
  -o jsonpath='{range .spec.ports[*]}{.port}{"\n"}{end}' 2>/dev/null | wc -l | tr -d ' ') || GREEN_PORT_COUNT=0

if [[ "$GREEN_PORT" == "8080" && "$GREEN_PORT_COUNT" == "1" ]]; then
  assert_pass "petclinic-green exposes only port 8080" "0"
else
  assert_pass "petclinic-green exposes only port 8080 (port=$GREEN_PORT count=$GREEN_PORT_COUNT)" "1"
fi

# ---------------------------------------------------------------------------
# Check 5: petclinic-blue has no external IP (ClusterIP only)
# ---------------------------------------------------------------------------
log_info "${TC_ID}: Checking petclinic-blue external IP..."
BLUE_EXTERNAL_IP=$(kubectl get service petclinic-blue \
  --namespace "$NAMESPACE" \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null) || BLUE_EXTERNAL_IP=""

if [[ -z "$BLUE_EXTERNAL_IP" ]]; then
  assert_pass "petclinic-blue has no external IP" "0"
else
  assert_pass "petclinic-blue has no external IP (got: $BLUE_EXTERNAL_IP)" "1"
fi

# ---------------------------------------------------------------------------
# Check 6: petclinic-green has no external IP (ClusterIP only)
# ---------------------------------------------------------------------------
log_info "${TC_ID}: Checking petclinic-green external IP..."
GREEN_EXTERNAL_IP=$(kubectl get service petclinic-green \
  --namespace "$NAMESPACE" \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null) || GREEN_EXTERNAL_IP=""

if [[ -z "$GREEN_EXTERNAL_IP" ]]; then
  assert_pass "petclinic-green has no external IP" "0"
else
  assert_pass "petclinic-green has no external IP (got: $GREEN_EXTERNAL_IP)" "1"
fi

# ---------------------------------------------------------------------------
# Check 7: Intra-cluster connectivity — blue pod to petclinic-green:8080
# ---------------------------------------------------------------------------
log_info "${TC_ID}: Testing intra-cluster connectivity from blue pod to petclinic-green:8080..."
BLUE_POD=$(kubectl get pods \
  --namespace "$NAMESPACE" \
  --selector="slot=blue" \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) || BLUE_POD=""

if [[ -z "$BLUE_POD" ]]; then
  log_error "${TC_ID}: No blue pod found in namespace '$NAMESPACE'; skipping intra-cluster connectivity check."
  assert_pass "blue pod found for intra-cluster connectivity test" "1"
else
  BLUE_TO_GREEN_EXIT=0
  kubectl exec "$BLUE_POD" \
    --namespace "$NAMESPACE" \
    -- curl -sf --connect-timeout 5 http://petclinic-green:8080/actuator/health \
    >/dev/null 2>&1 || BLUE_TO_GREEN_EXIT=$?
  assert_pass "blue pod can reach petclinic-green:8080" "$BLUE_TO_GREEN_EXIT"
fi

# ---------------------------------------------------------------------------
# Check 8: Intra-cluster connectivity — green pod to petclinic-blue:8080
# ---------------------------------------------------------------------------
log_info "${TC_ID}: Testing intra-cluster connectivity from green pod to petclinic-blue:8080..."
GREEN_POD=$(kubectl get pods \
  --namespace "$NAMESPACE" \
  --selector="slot=green" \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) || GREEN_POD=""

if [[ -z "$GREEN_POD" ]]; then
  log_error "${TC_ID}: No green pod found in namespace '$NAMESPACE'; skipping intra-cluster connectivity check."
  assert_pass "green pod found for intra-cluster connectivity test" "1"
else
  GREEN_TO_BLUE_EXIT=0
  kubectl exec "$GREEN_POD" \
    --namespace "$NAMESPACE" \
    -- curl -sf --connect-timeout 5 http://petclinic-blue:8080/actuator/health \
    >/dev/null 2>&1 || GREEN_TO_BLUE_EXIT=$?
  assert_pass "green pod can reach petclinic-blue:8080" "$GREEN_TO_BLUE_EXIT"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [[ $FAILURES -gt 0 ]]; then
  log_fail "${TC_ID}: FAILED (${FAILURES} check(s) failed)"
  exit 1
fi

log_pass "${TC_ID}: PASSED — ClusterIP topology validated successfully"
exit 0
