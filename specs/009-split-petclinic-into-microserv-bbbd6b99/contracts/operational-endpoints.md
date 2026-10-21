# Contract: Operational Endpoints — Management Port

**Applies to**: Vets service, Owners service (both independently)
**Version**: 1.0.0
**Status**: New contract — introduces the management port separation required by FR-016 and FR-017; replaces the current `include=*` actuator exposure on the public host
**Feature**: 009-split-petclinic-into-microserv-bbbd6b99
**Date**: 2026-10-19
**References**: FR-016, FR-017, SPEC-APP-12, SPEC-INT-8, SPEC-PLAT-4, SPEC-PLAT-7, SPEC-PLAT-10, ADR-APP-9, User Story 5

---

## Scope

This contract defines the operational endpoints exposed by each service on its dedicated management port. It also defines what must not be reachable through the public-facing edge. This is an accepted breaking change from the current monolith configuration (which exposes `include=*` on the public host); it requires explicit sponsor agreement before S3 (E1-S3, DEF-6).

---

## Management Port

The management port number is NEEDS CLARIFICATION (research item 12a, resolved in E4-S5). The standard Spring Boot default is `8081`; the actual value must be confirmed against the existing Kubernetes manifests in `k8s/` and the Prometheus scrape configuration. This contract uses `<management-port>` as a placeholder.

Each service runs two ports:
- Application port (`8080` — NEEDS CLARIFICATION: confirm against existing manifests in E4-S5): serves all user-facing routes; reachable only through the edge
- Management port (`<management-port>`): serves operational endpoints; not routed by the edge; restricted by NetworkPolicy

---

## Exposed Endpoints (Management Port Only)

The effective `management.endpoints.web.exposure.include` must be exactly `health,info,metrics,prometheus` for both services (FR-016). No other endpoint may be exposed.

### GET /actuator/health

| Attribute | Value |
|-----------|-------|
| Port | Management port only |
| Auth | None (within monitoring network) |
| Status (service up) | `200 OK` |
| Status (service degraded) | `503 Service Unavailable` |
| Content-Type | `application/vnd.spring-boot.actuator.v3+json` or `application/json` |
| Body | `{"status": "UP"}` or `{"status": "DOWN"}` — health details must not be shown (E5-S2); no owner field values in any tag or detail |

**Liveness group**: `GET /actuator/health/liveness`
- `200 OK` with `{"status": "UP"}` when the JVM is alive
- Used by Kubernetes liveness probe

**Readiness group**: `GET /actuator/health/readiness`
- `200 OK` with `{"status": "UP"}` when the service is ready to accept traffic
- `503 Service Unavailable` with `{"status": "OUT_OF_SERVICE"}` when not ready
- Used by Kubernetes readiness probe

---

### GET /actuator/info

| Attribute | Value |
|-----------|-------|
| Port | Management port only |
| Status | `200 OK` |
| Content-Type | `application/vnd.spring-boot.actuator.v3+json` or `application/json` |
| Body | Build info, git info, or empty object; must not contain owner field values |

---

### GET /actuator/metrics

| Attribute | Value |
|-----------|-------|
| Port | Management port only |
| Status | `200 OK` |
| Content-Type | `application/vnd.spring-boot.actuator.v3+json` or `application/json` |
| Body | List of available metric names |

#### GET /actuator/metrics/{metricName}

| Attribute | Value |
|-----------|-------|
| Port | Management port only |
| Status (found) | `200 OK` |
| Status (not found) | `404 Not Found` |
| Body | Metric value with tags; must not contain owner field values in any tag (E5-S2) |

**Required metric — Vets service only**:

| Metric | Tag | Condition | Expected value |
|--------|-----|-----------|----------------|
| `cache.gets` | `cache=vets`, `result=hit` | After two calls to `VetRepository.findAll` | Greater than 0 |
| `cache.gets` | `cache=vets` | Always present after first call | Present |

(FR-006, User Story 5 scenario 3)

**Required metric — both services**:

| Metric | Condition |
|--------|-----------|
| `http.server.requests` | Present after any HTTP request to the application port |

(User Story 5 scenario 2)

---

### GET /actuator/prometheus

| Attribute | Value |
|-----------|-------|
| Port | Management port only |
| Status | `200 OK` |
| Content-Type | `text/plain;version=0.0.4;charset=utf-8` (Prometheus text format) |
| Body | Prometheus-format metrics; must include `http_server_requests_seconds` (or equivalent); must not contain owner field values in any label |

**Vets service**: The Prometheus output must include `cache_gets_total` (or equivalent) with label `cache="vets"` (User Story 5 scenario 2).

---

## Endpoints That Must NOT Be Exposed

The following endpoints must return `404 Not Found` on the management port (E5-S2):

| Endpoint | Reason |
|----------|--------|
| `/actuator/env` | Could expose configuration values including database credentials |
| `/actuator/heapdump` | Could expose owner PII from heap |
| `/actuator/beans` | Exposes internal application structure |
| `/actuator/mappings` | Exposes route structure |
| `/actuator/configprops` | Could expose configuration values |
| Any endpoint not in the `health,info,metrics,prometheus` list | Not permitted by FR-016 |

---

## Endpoints That Must Return 404 on the Public Host (Edge-Blocked)

The edge returns `404 Not Found` for all of the following paths on the public host. Neither service's upstream request counter must increment (FR-011, User Story 5 scenario 1):

| Path | Edge response |
|------|---------------|
| `/actuator` | `404 Not Found` |
| `/actuator/**` | `404 Not Found` |
| `/livez` | `404 Not Found` |
| `/readyz` | `404 Not Found` |

---

## Network Access Rules

| Source | Destination | Port | Permitted |
|--------|-------------|------|-----------|
| Edge router | Vets application port | `8080` (NEEDS CLARIFICATION) | Yes |
| Edge router | Owners application port | `8080` (NEEDS CLARIFICATION) | Yes |
| Edge router | Vets management port | `<management-port>` | **No** |
| Edge router | Owners management port | `<management-port>` | **No** |
| Monitoring namespace (Prometheus) | Vets management port | `<management-port>` | Yes |
| Monitoring namespace (Prometheus) | Owners management port | `<management-port>` | Yes |
| Orchestration namespace (Kubernetes probes) | Vets management port | `<management-port>` | Yes |
| Orchestration namespace (Kubernetes probes) | Owners management port | `<management-port>` | Yes |
| Any other source | Either management port | `<management-port>` | **No — connection refused** |
| Vets pod | Owners pod (any port) | Any | **No** |
| Owners pod | Vets pod (any port) | Any | **No** |

(FR-017, SPEC-PLAT-10, E4-S10, E5-S5)

NetworkPolicy resources in `k8s/vets/networkpolicy.yaml` and `k8s/owners/networkpolicy.yaml` enforce these rules. A connection attempt to the management port from outside the monitoring namespace must be refused (User Story 5 scenario 5).

---

## Kubernetes Probe Configuration

Both services must configure liveness and readiness probes using the health groups on the management port (FR-016):

| Probe | Path | Port | Expected status |
|-------|------|------|-----------------|
| Liveness | `/actuator/health/liveness` | `<management-port>` | `200 OK` |
| Readiness | `/actuator/health/readiness` | `<management-port>` | `200 OK` |

The application port (`8080`) must not be used for probes.

---

## Observability Acceptance Criteria

| Scenario | Verification |
|----------|--------------|
| Stopping Vets in staging raises the readiness alert within 5 minutes | E4-S7 |
| Stopping Vets in staging does not affect the Owners readiness probe | E4-S7 |
| `cache.gets` for `cache=vets` shows a hit on the second request to GET /vets | E4-S7, E1-S6 |
| A single request ID can be followed from edge log to service log | E5-S6 |
| No owner last-name value appears in edge or application logs after an owner search | E5-S6 |

---

## Configuration Properties (Both Services)

The following Spring Boot properties must be set in `application.properties` for both services:

```properties
# Management port (value NEEDS CLARIFICATION — E4-S5)
management.server.port=<management-port>

# Actuator exposure — exactly these four endpoints
management.endpoints.web.exposure.include=health,info,metrics,prometheus

# Health details hidden from unauthenticated callers
management.endpoint.health.show-details=never

# Liveness and readiness groups enabled
management.endpoint.health.probes.enabled=true

# Cache statistics enabled (Vets service only)
spring.jmx.enabled=true
management.metrics.cache.instrument-defaults=true
```

The exact property names must be confirmed against the Spring Boot version in use. The `spring.sql.init.mode=never` property is also required in `application.properties` for both services against persistent stores (FR-019); it is documented in the data model contract.
