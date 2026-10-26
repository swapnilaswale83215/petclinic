# Platform Runbook — Atomic Service Switch and Hold-Mode Platform Support

**Ticket**: GH-48 (E4-S5)  
**Specs**: SPEC-PLAT-5, SPEC-PLAT-13  
**Gate**: G5 — this document must be present and complete before the G5 review.  
**Status**: Draft — update timeout values from your environment before G5.

---

## 1. Overview

This runbook documents the platform infrastructure for the petclinic-mysql atomic Service
selector switch and hold-mode support (ADR-APP-3 modes Z and W). It covers:

- Direct per-slot ClusterIP Services (`petclinic-blue`, `petclinic-green`)
- Upstream timeout inventory and pass/fail determination against the 35 s threshold
- Blue↔green intra-cluster reachability confirmation
- Write-pause window measurements

---

## 2. Direct Per-Slot ClusterIP Services

| Service Name      | Type      | Port | Target Port | Selector       | External Reachability |
|-------------------|-----------|------|-------------|----------------|-----------------------|
| `petclinic-blue`  | ClusterIP | 8080 | 8080        | `slot: blue`   | None (ClusterIP only) |
| `petclinic-green` | ClusterIP | 8080 | 8080        | `slot: green`  | None (ClusterIP only) |

**Verification commands:**

```bash
kubectl get svc petclinic-blue  -o wide
kubectl get svc petclinic-green -o wide
```

Expected output: `TYPE=ClusterIP`, `PORT(S)=8080/TCP`, `EXTERNAL-IP=<none>`.

**AC-006**: Both Services must show `ClusterIP` type, port 8080 only, and no external IP.

---

## 3. Blue↔Green Intra-Cluster Reachability

**AC-007 / FR-008**: Intra-cluster connectivity must be confirmed in both directions.

| Source Pod Slot | Target Service      | Target Port | Expected Result |
|-----------------|---------------------|-------------|-----------------|
| green           | `petclinic-blue`    | 8080        | Connection succeeds |
| blue            | `petclinic-green`   | 8080        | Connection succeeds |

**Verification commands (run from within the cluster):**

```bash
# From a green pod:
kubectl exec -n <namespace> <green-pod> -- curl -sf http://petclinic-blue:8080/actuator/health

# From a blue pod:
kubectl exec -n <namespace> <blue-pod> -- curl -sf http://petclinic-green:8080/actuator/health
```

**External reachability probe (must fail):**

```bash
# From outside the cluster — must return connection refused or timeout:
curl --connect-timeout 5 http://<cluster-external-ip>:8080/  # targeting petclinic-blue/green directly
```

---

## 4. Upstream Timeout Inventory Table

**AC-005 / AC-012 / FR-010 / FR-015**

The upstream timeout requirement is derived from the hold limit plus a 5 s buffer:

| Mode | Hold Limit | Minimum Upstream Timeout |
|------|------------|-------------------------|
| Z    | 30 s       | **35 s**                |
| W    | 60 s       | **65 s**                |

> **Note**: The threshold in the table below uses **35 s** (mode Z minimum). For mode W
> deployments, any timeout below **65 s** must also be raised as a finding.

### 4.1 Timeout Inventory

Fill in the **Configured Timeout** column from your environment before the G5 review.
Any row with `FAIL` is a **blocking finding** that must be raised before G5.

| Component | Resource Type | Resource Name | Configured Timeout (s) | Pass/Fail vs 35 s | Finding Ticket |
|-----------|---------------|---------------|------------------------|-------------------|----------------|
| Ingress Controller (nginx) | Ingress | `petclinic` | _fill in_ | _fill in_ | _if FAIL_ |
| Ingress proxy-read-timeout | Ingress annotation | `nginx.ingress.kubernetes.io/proxy-read-timeout` | _fill in_ | _fill in_ | _if FAIL_ |
| Ingress proxy-send-timeout | Ingress annotation | `nginx.ingress.kubernetes.io/proxy-send-timeout` | _fill in_ | _fill in_ | _if FAIL_ |
| Load Balancer (cloud LB) | Service (LoadBalancer) | `petclinic-lb` | _fill in_ | _fill in_ | _if FAIL_ |
| Upstream proxy / API gateway | ConfigMap / CRD | _fill in_ | _fill in_ | _fill in_ | _if FAIL_ |

**Pass/Fail determination rule:**
- PASS: Configured Timeout ≥ 35 s (mode Z) or ≥ 65 s (mode W)
- FAIL: Configured Timeout < 35 s (mode Z) or < 65 s (mode W) → raise finding before G5

**How to populate this table:**

```bash
# nginx ingress proxy-read-timeout:
kubectl get ingress petclinic -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/proxy-read-timeout}'

# nginx ingress proxy-send-timeout:
kubectl get ingress petclinic -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/proxy-send-timeout}'
```

---

## 5. Selector Switch Procedure (SPEC-PLAT-5)

### 5.1 Forward Switch (blue → green)

```bash
# S8a: Single merge patch to switch selector to green
kubectl patch service petclinic \
  --namespace <namespace> \
  --type=merge \
  --patch '{"spec":{"selector":{"slot":"green"}}}'

# S8b: Verify Endpoints contain only green pod addresses (5 s deadline)
kubectl get endpoints petclinic --namespace <namespace> -w
```

Or use the orchestrator script:

```bash
bash k8s/orchestrator/selector_switch.sh \
  --namespace <namespace> \
  --service petclinic \
  --target-slot green
```

### 5.2 Abort / Rollback (green → blue)

```bash
# Single merge patch to restore selector to blue
kubectl patch service petclinic \
  --namespace <namespace> \
  --type=merge \
  --patch '{"spec":{"selector":{"slot":"blue"}}}'
```

Or invoke `selector_switch.sh` with `--target-slot blue`.

**NFR-003**: Rollback must restore traffic to blue within the same 5-second window.

---

## 6. Write-Pause Window Measurements

| Mode | Limit  | Measured (rehearsal) | Pass/Fail |
|------|--------|----------------------|-----------|
| Z    | 20 s   | _fill in_            | _fill in_ |
| W    | 60 s   | _fill in_            | _fill in_ |

Populate from rehearsal run output of `mode_w_provision.sh` and `selector_switch.sh`.

---

## 7. Capacity and Health Validation (SPEC-PLAT-13)

**NFR-005 / NFR-006 / AC-008 / AC-009 / AC-011**

Run the rehearsal harness under peak write load:

```bash
bash k8s/rehearsal/blue_health_probe_check.sh \
  --namespace <namespace> \
  --duration 30
```

Expected results:
- Zero pod restarts for blue during the 30-second window
- Zero forwarded writes that failed after being sent
- Liveness and readiness probes pass throughout the window

---

## 8. Pre-G5 Checklist

- [ ] Timeout inventory table (Section 4) is complete with actual configured values
- [ ] All timeout rows show PASS, or finding tickets exist for each FAIL row
- [ ] `petclinic-blue` and `petclinic-green` Services verified as ClusterIP, port 8080 only
- [ ] Blue↔green intra-cluster connectivity confirmed in both directions
- [ ] External reachability probe confirms Services are unreachable from outside cluster
- [ ] Write-pause window measurements recorded for both mode Z and mode W
- [ ] Peak-load rehearsal shows zero restarts and zero failed forwarded writes
- [ ] `selector_switch.sh` rehearsal exit 0 with green-only Endpoints within 5 s
- [ ] Rollback rehearsal exit 0 with blue-only Endpoints within 5 s

---

*Generated by ShiftForge Synapse Builder for GH-48 (E4-S5). Update all `_fill in_` cells from your environment before the G5 review.*
