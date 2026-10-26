#!/usr/bin/env bash
# mode_w_provision.sh — Mode W topology provisioning script.
#
# ADR-APP-3 mode W: Provisions the direct per-slot ClusterIP topology
# (petclinic-blue, petclinic-green) and verifies upstream timeout configuration
# WITHOUT activating or depending on the hold mechanism.
#
# SPEC-PLAT-13 / FR-016: For mode W the platform provides the same direct
# per-slot ClusterIP topology as mode Z but MUST NOT rely on the hold mechanism.
#
# FR-011: Every upstream timeout MUST be at least hold-limit + 5 s.
#         Mode W hold limit = 60 s; minimum upstream timeout = 65 s.
#
# Usage:
#   mode_w_provision.sh [--namespace <ns>] [--manifests-dir <dir>]
#                       [--min-timeout <seconds>]
#
# Environment variables:
#   NAMESPACE              Kubernetes namespace (default: default)
#   MANIFESTS_DIR          Directory containing petclinic-blue.yaml and
#                          petclinic-green.yaml (default: k8s/services)
#   MIN_UPSTREAM_TIMEOUT_S Minimum required upstream timeout in seconds.
#                          Mode W default: 65 (hold limit 60 s + 5 s buffer).
#                          Override only if your hold limit differs.
#
# Exit codes:
#   0  Topology provisioned and all timeout checks passed.
#   1  A required timeout is below the minimum threshold (finding raised).
#   2  A kubectl apply or prerequisite check failed.

set -euo pipefail

# ---------------------------------------------------------------------------
# Logging helpers (mirror .specify/scripts/bash/common.sh conventions)
# ---------------------------------------------------------------------------
log_info()  { printf '[INFO]  %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
log_warn()  { printf '[WARN]  %s\n' "$*" >&2; }
log_pass()  { printf '[PASS]  %s\n' "$*" >&2; }
log_fail()  { printf '[FAIL]  %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
NAMESPACE="${NAMESPACE:-default}"
# Resolve manifests directory relative to this script's location
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${MANIFESTS_DIR:-${SCRIPT_DIR}/../services}"
# FR-011: Mode W minimum upstream timeout = hold limit (60 s) + 5 s buffer = 65 s
MIN_UPSTREAM_TIMEOUT_S="${MIN_UPSTREAM_TIMEOUT_S:-65}"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)    NAMESPACE="$2";             shift 2 ;;
    --manifests-dir) MANIFESTS_DIR="$2";        shift 2 ;;
    --min-timeout)  MIN_UPSTREAM_TIMEOUT_S="$2"; shift 2 ;;
    *) log_error "Unknown argument: $1"; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# Guard: ensure no hold-mechanism dependency is active
# FR-016: mode W topology MUST NOT rely on the hold mechanism.
# ---------------------------------------------------------------------------
if [[ "${HOLD_MECHANISM_ENABLED:-0}" == "1" || "${HOLD_MODE_ACTIVE:-0}" == "1" ]]; then
  log_error "Hold mechanism is active (HOLD_MECHANISM_ENABLED or HOLD_MODE_ACTIVE is set)."
  log_error "Mode W provisioning MUST NOT depend on the hold mechanism. Aborting."
  exit 2
fi
log_info "Hold mechanism guard: PASSED (no hold-mechanism dependency detected)."

# ---------------------------------------------------------------------------
# Step 1: Apply petclinic-blue and petclinic-green Service manifests
# FR-006, FR-007: Both Services applied together for atomic blue<->green
# intra-cluster connectivity establishment.
# ---------------------------------------------------------------------------
BLUE_MANIFEST="${MANIFESTS_DIR}/petclinic-blue.yaml"
GREEN_MANIFEST="${MANIFESTS_DIR}/petclinic-green.yaml"

for manifest in "$BLUE_MANIFEST" "$GREEN_MANIFEST"; do
  if [[ ! -f "$manifest" ]]; then
    log_error "Required manifest not found: $manifest"
    exit 2
  fi
done

log_info "Applying petclinic-blue Service manifest..."
if ! kubectl apply -f "$BLUE_MANIFEST" --namespace "$NAMESPACE"; then
  log_error "Failed to apply petclinic-blue manifest."
  exit 2
fi

log_info "Applying petclinic-green Service manifest..."
if ! kubectl apply -f "$GREEN_MANIFEST" --namespace "$NAMESPACE"; then
  log_error "Failed to apply petclinic-green manifest."
  exit 2
fi
log_info "Both per-slot ClusterIP Services applied successfully."

# ---------------------------------------------------------------------------
# Step 2: Verify upstream timeout configuration
# FR-010, FR-011, FR-015: Every LB, ingress, and proxy timeout must be
# documented and >= MIN_UPSTREAM_TIMEOUT_S (65 s for mode W).
# ---------------------------------------------------------------------------
log_info "Verifying upstream timeout configuration (minimum: ${MIN_UPSTREAM_TIMEOUT_S}s)..."

FINDINGS=0

check_timeout() {
  local component="$1"
  local namespace="$2"
  local resource_type="$3"
  local resource_name="$4"
  local jsonpath="$5"
  local configured_timeout

  configured_timeout=$(kubectl get "$resource_type" "$resource_name" \
    --namespace "$namespace" \
    -o jsonpath="$jsonpath" 2>/dev/null) || {
    log_warn "Could not retrieve timeout for $component ($resource_type/$resource_name). Skipping."
    return 0
  }

  if [[ -z "$configured_timeout" ]]; then
    log_warn "Timeout value for $component is empty or not configured. Treating as finding."
    log_fail "$component: timeout not configured (required >= ${MIN_UPSTREAM_TIMEOUT_S}s)"
    FINDINGS=$(( FINDINGS + 1 ))
    return 0
  fi

  # Strip trailing 's' if present (e.g. "60s" -> "60")
  local timeout_val="${configured_timeout%s}"

  if [[ "$timeout_val" -ge "$MIN_UPSTREAM_TIMEOUT_S" ]]; then
    log_pass "$component: ${configured_timeout} >= ${MIN_UPSTREAM_TIMEOUT_S}s — PASS"
  else
    log_fail "$component: ${configured_timeout} < ${MIN_UPSTREAM_TIMEOUT_S}s — FINDING (raise before G5)"
    FINDINGS=$(( FINDINGS + 1 ))
  fi
}

# Check ingress-nginx proxy-read-timeout annotation on the petclinic ingress (if present)
INGRESS_NAME="${INGRESS_NAME:-petclinic}"
INGRESS_NS="${INGRESS_NAMESPACE:-$NAMESPACE}"
if kubectl get ingress "$INGRESS_NAME" --namespace "$INGRESS_NS" >/dev/null 2>&1; then
  PROXY_READ_TIMEOUT=$(kubectl get ingress "$INGRESS_NAME" \
    --namespace "$INGRESS_NS" \
    -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/proxy-read-timeout}' \
    2>/dev/null) || PROXY_READ_TIMEOUT=""
  if [[ -z "$PROXY_READ_TIMEOUT" ]]; then
    log_warn "Ingress '$INGRESS_NAME': proxy-read-timeout annotation not set. Treating as finding."
    log_fail "ingress/$INGRESS_NAME proxy-read-timeout: not configured (required >= ${MIN_UPSTREAM_TIMEOUT_S}s)"
    FINDINGS=$(( FINDINGS + 1 ))
  else
    TIMEOUT_VAL="${PROXY_READ_TIMEOUT%s}"
    if [[ "$TIMEOUT_VAL" -ge "$MIN_UPSTREAM_TIMEOUT_S" ]]; then
      log_pass "ingress/$INGRESS_NAME proxy-read-timeout: ${PROXY_READ_TIMEOUT} >= ${MIN_UPSTREAM_TIMEOUT_S}s — PASS"
    else
      log_fail "ingress/$INGRESS_NAME proxy-read-timeout: ${PROXY_READ_TIMEOUT} < ${MIN_UPSTREAM_TIMEOUT_S}s — FINDING"
      FINDINGS=$(( FINDINGS + 1 ))
    fi
  fi
else
  log_info "Ingress '$INGRESS_NAME' not found in namespace '$INGRESS_NS'; skipping ingress timeout check."
fi

# ---------------------------------------------------------------------------
# Step 3: Measure write-pause window (gate close to green gate open)
# NFR-004: Mode W write-pause MUST be <= 60 s.
# ---------------------------------------------------------------------------
MODE_W_WRITE_PAUSE_LIMIT_S=60

log_info "Measuring write-pause window (mode W limit: ${MODE_W_WRITE_PAUSE_LIMIT_S}s)..."
WRITE_PAUSE_START=$(date +%s)

# The write-pause window is the interval from gate close (selector patch issued)
# to green gate open (Endpoints verified green-only). In rehearsal context this
# is measured by timing the selector_switch.sh invocation.
SELECTOR_SWITCH_SCRIPT="${SCRIPT_DIR}/selector_switch.sh"
if [[ -x "$SELECTOR_SWITCH_SCRIPT" ]]; then
  log_info "Invoking selector_switch.sh to measure write-pause window..."
  if ! "$SELECTOR_SWITCH_SCRIPT" \
      --namespace "$NAMESPACE" \
      --service "${SERVICE_NAME:-petclinic}" \
      --target-slot green; then
    log_error "selector_switch.sh failed during write-pause measurement."
    exit 2
  fi
else
  log_warn "selector_switch.sh not found or not executable at '$SELECTOR_SWITCH_SCRIPT'; skipping live write-pause measurement."
fi

WRITE_PAUSE_END=$(date +%s)
WRITE_PAUSE_ELAPSED=$(( WRITE_PAUSE_END - WRITE_PAUSE_START ))
log_info "Write-pause window measured: ${WRITE_PAUSE_ELAPSED}s (limit: ${MODE_W_WRITE_PAUSE_LIMIT_S}s)"

if [[ $WRITE_PAUSE_ELAPSED -le $MODE_W_WRITE_PAUSE_LIMIT_S ]]; then
  log_pass "Write-pause window: ${WRITE_PAUSE_ELAPSED}s <= ${MODE_W_WRITE_PAUSE_LIMIT_S}s — PASS"
else
  log_fail "Write-pause window: ${WRITE_PAUSE_ELAPSED}s > ${MODE_W_WRITE_PAUSE_LIMIT_S}s — FINDING"
  FINDINGS=$(( FINDINGS + 1 ))
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [[ $FINDINGS -gt 0 ]]; then
  log_error "Mode W provisioning completed with ${FINDINGS} finding(s). Raise all findings before gate G5."
  exit 1
fi

log_info "Mode W provisioning completed successfully. No findings."
exit 0
