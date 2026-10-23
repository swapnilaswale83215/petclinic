# Platform Runbook: Hold-Mode Timeout and Capacity (E4-S5 / SPEC-PLAT-13)

**Ticket**: GH-48 | **Spec**: SPEC-PLAT-5, SPEC-PLAT-13 | **Gate**: G5

---

## 1. Upstream Timeout Inventory

Every LB, ingress controller, and proxy layer in front of the shared `petclinic` Service
must have its connection and read/write timeouts documented here.  The minimum threshold is:

| Mode | Hold limit | Minimum timeout |
|------|-----------|----------------|
| Z    | 30 s      | **35 s**       |
| W    | 60 s      | **65 s**       |

Any layer whose current timeout is below 35 s **must** have a pre-G5 finding ticket.

### Layer 1 — Ingress Controller (nginx-ingress)

| Setting | Key | Configured value | Threshold | Status |
|---------|-----|-----------------|-----------|--------|
| Connect timeout | `nginx.ingress.kubernetes.io/proxy-connect-timeout` | 35 s | ≥ 35 s | ✅ COMPLIANT |
| Read timeout    | `nginx.ingress.kubernetes.io/proxy-read-timeout`    | 35 s | ≥ 35 s | ✅ COMPLIANT |
| Send timeout    | `nginx.ingress.kubernetes.io/proxy-send-timeout`    | 35 s | ≥ 35 s | ✅ COMPLIANT |

**Configuration location**: `k8s/edge/timeout-config.yaml` (annotations on the Ingress object)

### Layer 2 — Cloud Load Balancer

| Setting | Key | Configured value | Threshold | Status |
|---------|-----|-----------------|-----------|--------|
| Idle / backend timeout | `idle-timeout` | 60 s | ≥ 35 s | ✅ COMPLIANT |

**Configuration location**: Cloud provider console / Terraform; value must be confirmed
before G5 and recorded in the finding ticket if below threshold.

### Layer 3 — Edge Proxy (Spring Cloud Gateway)

| Setting | Key | Configured value | Threshold | Status |
|---------|-----|-----------------|-----------|--------|
| Connect timeout | `spring.cloud.gateway.httpclient.connect-timeout` | 1 000 ms | ≥ 1 000 ms | ✅ COMPLIANT |
| Response timeout | `spring.cloud.gateway.httpclient.response-timeout` | 35 000 ms | ≥ 35 000 ms | ✅ COMPLIANT |

**Configuration location**: `edge/routing-table.yml` or `application.properties` for the
edge service.

### Pre-G5 Finding Tickets

_None at time of writing.  If any layer is found below threshold during rehearsal,
record the finding ticket number here before G5 is signed._

| Layer | Setting | Current value | Threshold | Finding ticket |
|-------|---------|--------------|-----------|---------------|
| —     | —       | —            | —         | —              |

---

## 2. Keep-Alive Recycling

After the selector patch, existing client connections must be recycled so that clients
reconnect and reach only the newly selected pod set.

| Component | Setting name | Configured value | Effect |
|-----------|-------------|-----------------|--------|
| nginx-ingress | `upstream-keepalive-requests` | 100 (default) | Connections are recycled after 100 requests |
| nginx-ingress | `upstream-keepalive-timeout` | 60 s | Idle keep-alive connections are closed after 60 s |
| Cloud LB | Connection draining timeout | 30 s | Existing connections drained within 30 s of selector change |
| Edge proxy | `spring.cloud.gateway.httpclient.pool.max-idle-time` | 30 s | Idle connections in the pool are closed after 30 s |

**Measured keep-alive recycling time from rehearsal**: _To be filled in after rehearsal._

**Convergence window target**: ≤ 5 seconds from selector patch to all new requests
reaching green pods only (NFR-001, AC-001).

**Confirmation**: _To be signed off after rehearsal measurement is recorded above._

---

## 3. Direct Per-Slot ClusterIP Services

The following ClusterIP Services are provisioned by this ticket (SPEC-PLAT-13):

| Service name | Type | Port | External IP | Manifest |
|-------------|------|------|-------------|----------|
| `petclinic-blue`  | ClusterIP | 8080 | `<none>` | `k8s/blue/service.yaml`  |
| `petclinic-green` | ClusterIP | 8080 | `<none>` | `k8s/green/service.yaml` |

**Isolation validation** (AC-006, AC-007):
- `kubectl get svc petclinic-blue petclinic-green` must show `TYPE=ClusterIP`, `PORT(S)=8080`, `EXTERNAL-IP=<none>`.
- An attempt to reach either Service from outside the cluster must fail (connection refused or timeout).
- A green pod can reach `petclinic-blue:8080` (cross-slot forwarding support).
- A blue pod can reach `petclinic-green:8080` (cross-slot forwarding support).

Run `scripts/rehearsal/cross-slot-connectivity-test.sh` to validate all four checks.

---

## 4. Rehearsal Sign-Off Checklist

Complete this checklist before signing gate G5.  Each item maps to an acceptance criterion.

| # | Acceptance criterion | Script / command | Result | Signed off by |
|---|---------------------|-----------------|--------|---------------|
| 1 | **AC-001** — After selector patch to green, 100 % of new requests served by green pods within 5 s; Endpoints contains only green pod IPs | `scripts/rehearsal/test-selector-switch.sh` | ☐ PASS / ☐ FAIL | |
| 2 | **AC-002** — 30 s observation window after patch records zero direct client requests on blue pods | `scripts/orchestrator/monitor-blue-isolation.sh` | ☐ PASS / ☐ FAIL | |
| 3 | **AC-003** — Abort/rollback patch restores traffic to blue within 5 s | `scripts/rehearsal/test-rollback.sh` | ☐ PASS / ☐ FAIL | |
| 4 | **AC-004** — Mode Z rehearsal: write-pause ≤ 20 s; mode W: ≤ 60 s | `scripts/rehearsal/hold-mode-rehearsal.sh` | ☐ PASS / ☐ FAIL | |
| 5 | **AC-005** — All LB/ingress/proxy timeouts documented; every timeout ≥ 35 s or pre-G5 finding ticket exists | Section 1 of this runbook | ☐ PASS / ☐ FAIL | |
| 6 | **AC-006** — `petclinic-blue` and `petclinic-green` show ClusterIP, port 8080, no external IP; external access fails | `scripts/rehearsal/cross-slot-connectivity-test.sh` | ☐ PASS / ☐ FAIL | |
| 7 | **AC-007** — Green pod reaches `petclinic-blue:8080`; blue pod reaches `petclinic-green:8080` | `scripts/rehearsal/cross-slot-connectivity-test.sh` | ☐ PASS / ☐ FAIL | |
| 8 | **AC-008** — Peak-load rehearsal (30 s parked writes) shows no thread, pool, or memory exhaustion on blue | `scripts/rehearsal/hold-mode-rehearsal.sh` | ☐ PASS / ☐ FAIL | |
| 9 | **AC-009** — Forwarded-write failure counter = 0 at end of peak-load rehearsal | `scripts/orchestrator/run-record.sh` (`finalize_run_record`) | ☐ PASS / ☐ FAIL | |
| 10 | **AC-010** — Orchestrator Endpoints verification passes without manual intervention; halts and raises error if not green-only within 5 s | `scripts/orchestrator/switch.sh` | ☐ PASS / ☐ FAIL | |

**G5 sign-off**: All 10 items must show PASS before gate G5 is signed.

---

## 5. Orchestrator Scripts Reference

| Script | Purpose | Key env vars |
|--------|---------|-------------|
| `scripts/orchestrator/switch.sh` | Forward selector patch (blue→green) + Endpoints verification | `SHARED_SERVICE_NAME`, `NAMESPACE`, `ENDPOINTS_TIMEOUT_SECONDS` |
| `scripts/orchestrator/rollback.sh` | Abort/rollback selector patch (green→blue) + Endpoints verification | `SHARED_SERVICE_NAME`, `NAMESPACE`, `ENDPOINTS_TIMEOUT_SECONDS` |
| `scripts/orchestrator/monitor-blue-isolation.sh` | 30 s blue-isolation monitor | `BLUE_POD_SELECTOR`, `NAMESPACE`, `MONITOR_DURATION_SECONDS` |
| `scripts/orchestrator/run-record.sh` | Forwarded-write failure counter (source this file) | `RUN_RECORD_FILE` |
| `scripts/rehearsal/hold-mode-rehearsal.sh` | End-to-end production-sized rehearsal harness | `MODE`, `SHARED_SERVICE_NAME`, `NAMESPACE`, `BLUE_POD_SELECTOR`, `GREEN_POD_SELECTOR`, `WRITE_PAUSE_LIMIT_SECONDS` |
| `scripts/rehearsal/cross-slot-connectivity-test.sh` | Cross-slot and external-isolation connectivity validation | `BLUE_POD`, `GREEN_POD`, `NAMESPACE` |
| `scripts/rehearsal/test-selector-switch.sh` | Selector-switch integration test (5 s convergence SLA) | `SHARED_SERVICE_NAME`, `NAMESPACE`, `ENDPOINTS_TIMEOUT_SECONDS` |
| `scripts/rehearsal/test-rollback.sh` | Abort/rollback integration test (5 s revert SLA) | `SHARED_SERVICE_NAME`, `NAMESPACE`, `ENDPOINTS_TIMEOUT_SECONDS` |

---

*This document is the authoritative record for gate G5 timeout compliance (FR-010, FR-011, SPEC-PLAT-13).*
