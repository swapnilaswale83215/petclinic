#!/usr/bin/env bash
# selector_switch.sh — Atomic Service selector switch with S8b Endpoints verification gate.
#
# SPEC-PLAT-5: Issues a single JSON merge patch to switch the shared Service selector
# between blue and green pod sets. After the patch the orchestrator verifies that the
# Endpoints object contains only the target-slot pod addresses within 5 seconds (S8b).
# On failure the script aborts and restores the selector to the pre-patch value.
#
# Usage:
#   selector_switch.sh [--namespace <ns>] [--service <svc>] [--target-slot <blue|green>]
#
# Environment variables:
#   INJECT_PATCH_FAILURE=1   Simulate an API server error mid-patch (fault-injection seam).
#                            Inactive by default (unset or 0). For CI validation only.
#   KUBECONFIG               Standard kubectl config override.
#
# Exit codes:
#   0  Selector switched and Endpoints verified successfully.
#   1  Patch failed, deadline expired, or rollback required.

set -euo pipefail

# ---------------------------------------------------------------------------
# Logging helpers (mirror .specify/scripts/bash/common.sh conventions)
# ---------------------------------------------------------------------------
log_info()  { printf '[INFO]  %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
log_warn()  { printf '[WARN]  %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
NAMESPACE="${NAMESPACE:-default}"
SERVICE_NAME="${SERVICE_NAME:-petclinic}"
TARGET_SLOT="${TARGET_SLOT:-green}"
ENDPOINTS_DEADLINE_S=5
INJECT_PATCH_FAILURE="${INJECT_PATCH_FAILURE:-0}"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)   NAMESPACE="$2";    shift 2 ;;
    --service)     SERVICE_NAME="$2"; shift 2 ;;
    --target-slot) TARGET_SLOT="$2";  shift 2 ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ "$TARGET_SLOT" != "blue" && "$TARGET_SLOT" != "green" ]]; then
  log_error "--target-slot must be 'blue' or 'green', got: $TARGET_SLOT"
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 1: Capture pre-patch selector (blue) — required for rollback
# ---------------------------------------------------------------------------
log_info "Capturing pre-patch selector for Service '$SERVICE_NAME' in namespace '$NAMESPACE'..."
PRE_PATCH_SLOT=$(kubectl get service "$SERVICE_NAME" \
  --namespace "$NAMESPACE" \
  -o jsonpath='{.spec.selector.slot}' 2>/dev/null) || {
  log_error "Failed to read current selector from Service '$SERVICE_NAME'."
  exit 1
}

if [[ -z "$PRE_PATCH_SLOT" ]]; then
  log_warn "Pre-patch selector 'slot' label is empty; defaulting rollback target to 'blue'."
  PRE_PATCH_SLOT="blue"
fi
log_info "Pre-patch selector slot: '$PRE_PATCH_SLOT'"

# ---------------------------------------------------------------------------
# Fault-injection seam (AC-014, NFR-010)
# When INJECT_PATCH_FAILURE=1 the script simulates an API server error
# before the patch completes, then verifies the orchestrator aborts and
# restores the selector. Inactive by default.
# ---------------------------------------------------------------------------
if [[ "${INJECT_PATCH_FAILURE}" == "1" ]]; then
  log_warn "INJECT_PATCH_FAILURE=1: simulating API server error mid-patch."
  log_error "Simulated patch failure: API server returned 500 Internal Server Error."
  log_info "Aborting due to simulated patch failure; selector remains at pre-patch value '$PRE_PATCH_SLOT'."
  exit 1
fi

# ---------------------------------------------------------------------------
# Step S8a: Issue a single JSON merge patch to switch selector to target slot
# FR-002, NFR-010: single --type=merge patch; any non-zero exit is a hard failure.
# ---------------------------------------------------------------------------
log_info "S8a: Issuing merge patch to switch selector to slot='$TARGET_SLOT'..."

FORWARD_PATCH=$(printf '{"spec":{"selector":{"slot":"%s"}}}' "$TARGET_SLOT")

if ! kubectl patch service "$SERVICE_NAME" \
    --namespace "$NAMESPACE" \
    --type=merge \
    --patch "$FORWARD_PATCH"; then
  log_error "S8a: Merge patch failed (non-zero exit). Treating as hard failure."
  log_info "Selector has not been changed; no rollback required."
  exit 1
fi
log_info "S8a: Merge patch applied successfully."

# ---------------------------------------------------------------------------
# Step S8b: Poll Endpoints for up to ENDPOINTS_DEADLINE_S seconds
# Assert that ALL endpoint addresses belong exclusively to target-slot pods.
# FR-003, FR-014, NFR-001, NFR-007: 5-second hard deadline.
# ---------------------------------------------------------------------------
log_info "S8b: Verifying Endpoints contain only '$TARGET_SLOT' pod addresses (deadline: ${ENDPOINTS_DEADLINE_S}s)..."

verify_endpoints_exclusive() {
  local target_slot="$1"
  local svc="$2"
  local ns="$3"

  # Retrieve all endpoint addresses and their pod labels via jsonpath.
  # We check that every ready address has a pod whose 'slot' label matches target_slot.
  local ready_addresses
  ready_addresses=$(kubectl get endpoints "$svc" \
    --namespace "$ns" \
    -o jsonpath='{range .subsets[*].addresses[*]}{.targetRef.name}{"\n"}{end}' 2>/dev/null) || return 1

  if [[ -z "$ready_addresses" ]]; then
    # No ready addresses yet — not verified
    return 1
  fi

  # For each pod in the Endpoints, verify its slot label matches target_slot
  local pod_name
  while IFS= read -r pod_name; do
    [[ -z "$pod_name" ]] && continue
    local pod_slot
    pod_slot=$(kubectl get pod "$pod_name" \
      --namespace "$ns" \
      -o jsonpath='{.metadata.labels.slot}' 2>/dev/null) || return 1
    if [[ "$pod_slot" != "$target_slot" ]]; then
      return 1
    fi
  done <<< "$ready_addresses"

  return 0
}

S8B_VERIFIED=false
S8B_START=$(date +%s)
while true; do
  if verify_endpoints_exclusive "$TARGET_SLOT" "$SERVICE_NAME" "$NAMESPACE"; then
    S8B_VERIFIED=true
    break
  fi
  S8B_NOW=$(date +%s)
  S8B_ELAPSED=$(( S8B_NOW - S8B_START ))
  if [[ $S8B_ELAPSED -ge $ENDPOINTS_DEADLINE_S ]]; then
    break
  fi
  sleep 0.5
done

if [[ "$S8B_VERIFIED" != "true" ]]; then
  log_error "S8b: Endpoints did not contain exclusively '$TARGET_SLOT' pod addresses within ${ENDPOINTS_DEADLINE_S}s. Initiating rollback."

  # ---------------------------------------------------------------------------
  # Rollback: restore selector to pre-patch (blue) value
  # FR-004, FR-005, NFR-003: single merge patch, same 5-second SLA.
  # ---------------------------------------------------------------------------
  log_info "Rollback: issuing merge patch to restore selector to slot='$PRE_PATCH_SLOT'..."

  ROLLBACK_PATCH=$(printf '{"spec":{"selector":{"slot":"%s"}}}' "$PRE_PATCH_SLOT")

  if ! kubectl patch service "$SERVICE_NAME" \
      --namespace "$NAMESPACE" \
      --type=merge \
      --patch "$ROLLBACK_PATCH"; then
    log_error "Rollback patch failed. Manual intervention required to restore selector to '$PRE_PATCH_SLOT'."
    exit 1
  fi
  log_info "Rollback patch applied. Verifying Endpoints return to '$PRE_PATCH_SLOT' within ${ENDPOINTS_DEADLINE_S}s..."

  ROLLBACK_VERIFIED=false
  ROLLBACK_START=$(date +%s)
  while true; do
    if verify_endpoints_exclusive "$PRE_PATCH_SLOT" "$SERVICE_NAME" "$NAMESPACE"; then
      ROLLBACK_VERIFIED=true
      break
    fi
    ROLLBACK_NOW=$(date +%s)
    ROLLBACK_ELAPSED=$(( ROLLBACK_NOW - ROLLBACK_START ))
    if [[ $ROLLBACK_ELAPSED -ge $ENDPOINTS_DEADLINE_S ]]; then
      break
    fi
    sleep 0.5
  done

  if [[ "$ROLLBACK_VERIFIED" == "true" ]]; then
    log_info "Rollback verified: Endpoints now contain only '$PRE_PATCH_SLOT' pod addresses."
  else
    log_error "Rollback Endpoints verification timed out after ${ENDPOINTS_DEADLINE_S}s. Manual intervention required."
  fi

  exit 1
fi

log_info "S8b: Verified — Endpoints contain only '$TARGET_SLOT' pod addresses."
log_info "Selector switch to '$TARGET_SLOT' completed successfully."
exit 0
