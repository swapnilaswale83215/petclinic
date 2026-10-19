# Quickstart: Split PetClinic into Microservices — End-to-End Validation Guide

**Feature**: 009-split-petclinic-into-microserv-bbbd6b99
**Branch**: `009-split-petclinic-into-microserv-bbbd6b99`
**Date**: 2026-10-19
**Spec**: `/specs/009-split-petclinic-into-microserv-bbbd6b99/spec.md`
**Plan**: `/specs/009-split-petclinic-into-microserv-bbbd6b99/plan.md`

---

## Purpose

This guide describes how to verify that the split is correct at each migration stage. Every scenario is mapped to the success criterion it proves. This is a validation and run guide; implementation details, migration scripts, and full test suites belong in `tasks.md` and the implementation phase.

Do not use this guide to verify the monolith before the split begins. Run the KPI-2 baseline first (E4-S1) and record the result before executing any step below.

---

## Prerequisites

### Tools Required

- Java 17 JDK on `PATH` (no other version; see plan.md §Technical Context)
- Maven Wrapper: use `./mvnw` from the repository root; no external Maven installation
- Docker (for Testcontainers and Docker Compose runs)
- `curl` or equivalent HTTP client
- Access to the GitHub Actions UI for the repository (for KPI-1 workflow verification)
- A Kubernetes cluster or `kubectl` context pointing at the target environment (for platform-level scenarios)
- NEEDS CLARIFICATION: the edge router CLI or admin interface (depends on the technology chosen in E4-S6; see research.md §5)

### Repository State

- You are on branch `009-split-petclinic-into-microserv-bbbd6b99`
- The multi-module Maven layout (`vets/`, `owners/`, `petclinic-ui/`, `migration/`) is in place (post-W1)
- The KPI-2 baseline failing-test count has been recorded (E4-S1)
- GitHub issues #2, #3, and #5 are not touched at any point

### Environment Variables

The following must be set before running integration scenarios. Values are environment-specific.

```
VETS_APP_URL          # Public URL of the Vets service through the edge, e.g. https://petclinic.example.com
OWNERS_APP_URL        # Public URL of the Owners service through the edge (same host post-S3)
VETS_MGMT_URL         # Direct URL to the Vets management port, e.g. http://vets-pod:NEEDS_CLARIFICATION
OWNERS_MGMT_URL       # Direct URL to the Owners management port, e.g. http://owners-pod:NEEDS_CLARIFICATION
MONOLITH_URL          # URL of the running monolith (used for golden-master comparison in W2)
DB_VETS_CONN          # JDBC connection string for the Vets database principal
DB_OWNERS_CONN        # JDBC connection string for the Owners database principal
DB_MIGRATION_CONN     # JDBC connection string for the migration principal
```

NEEDS CLARIFICATION: the management port numbers for each service (research.md §12a, resolved in E4-S5). Replace `NEEDS_CLARIFICATION` in `VETS_MGMT_URL` and `OWNERS_MGMT_URL` with the confirmed port once E4-S5 is complete.

---

## Stage Map

Each section below corresponds to a migration wave or stage. Run sections in order. Do not skip a stage's verification before proceeding to the next.

| Section | Wave / Stage | Gate |
|---------|-------------|------|
| §1 | W0 — Baselines | G1 (sponsor approval) |
| §2 | W1 / S2 — Multi-module build | KPI-2 green |
| §3 | W2 / S2 — Edge in front of monolith, Vets dark | S3 approval gate (E1-S14) |
| §4 | W3 / S3 — Route flip | Post-flip verification |
| §5 | W4 / S4 — Vet code removed from Owners image | KPI-1 live |
| §6 | W5 / S5 — Optional vet schema copy | Sponsor decision (E1-S15) |
| §7 | W5 / S6 — Optional table drop | Sponsor approval (E1-S16) |
| §8 | Cross-cutting — Operational endpoints | FR-016, FR-017 |
| §9 | Cross-cutting — Locale and session | FR-014, SC-006 |
| §10 | Cross-cutting — Owner PII protection | FR-022, SC-005 |
| §11 | Cross-cutting — Edge resilience | FR-012, FR-013 |

---

## §1 — W0: Baselines

**Purpose**: Record the KPI-1 and KPI-2 baselines before any code moves. These numbers are the reference for every subsequent measurement.

**Proves**: E4-S1 accepted-when criteria; DEF-9 mitigation.

### 1.1 KPI-2 Baseline

Run the full test suite on the monolith on the H2 profile:

```
./mvnw verify -P h2
```

Expected: all tests pass. Record the count of test methods executed and the count of failures (target: 0 failures). Store this count as the KPI-2 baseline.

If any test fails before the split, stop. Do not proceed until the baseline is green. The failing-test count on main must be 0 before G1.

### 1.2 KPI-1 Baseline

Open the GitHub Actions UI. Navigate to the Deployments tab for the repository (or query the GitHub Deployments API for the production environment). Record:

- The name of the deploy-history source (GitHub Deployments API, confirmed in E4-S1)
- The current count of production deployments for each service (baseline: 0 for both, since the split has not happened yet)
- The agreed KPI-1 counting rule: which deploy types count (config-only redeploys, petclinic-ui bumps, edge redeploys)

NEEDS CLARIFICATION: the KPI-1 counting rule must be decided and recorded in E4-S1 before this step can be completed (research.md §7a).

**Success criterion**: KPI-2 baseline recorded with 0 failing tests. KPI-1 source and counting rule recorded. → Unblocks G1.

---

## §2 — W1 / S2: Multi-Module Build

**Purpose**: Verify that the repository builds two independent service artifacts and that the CI import check and KPI-2 suite are green, while production still runs the monolith.

**Proves**: FR-001 (no shared library), FR-002 (import check), SC-004 (artifact contents), KPI-2 (0 failing tests at this stage).

### 2.1 Per-Module Build Isolation

Build each module in isolation:

```
./mvnw -pl vets -am verify -P h2
./mvnw -pl owners -am verify -P h2
```

Expected: each command completes successfully without the other module's classes on the classpath. Neither command should compile or test the other service's source tree.

**Proves**: FR-001, E4-S2 accepted-when criterion.

### 2.2 Import Boundary Check

Trigger the import check by running the full build:

```
./mvnw verify -P h2
```

Then introduce a deliberate violation: add a single import of a vet class into an owner class (or vice versa) in a scratch branch. Run the build again.

Expected: the build fails with a clear violation message naming the offending import. Revert the violation.

NEEDS CLARIFICATION: the exact command to run the import check in isolation depends on whether the ArchUnit test lives in a dedicated module or per-service (research.md §2a, resolved in E1-S4). Update this step once E1-S4 is complete.

**Proves**: FR-002, SC-004.

### 2.3 Artifact Contents

After a successful build, inspect the Vets and Owners JARs:

```
jar tf vets/target/vets-*.jar | grep -E "owner|Owner"
jar tf owners/target/owners-*.jar | grep -E "vet/|Vet\."
```

Expected: the Vets JAR contains no classes from the `owner` package. The Owners JAR contains no classes from the `vet` package. Both greps return empty output.

**Proves**: SC-004.

### 2.4 KPI-2 Suite at S2

Run the full KPI-2 suite on H2:

```
./mvnw verify -P h2 -pl vets,owners -am
```

Expected: `OwnerControllerTests`, `PetControllerTests`, `VisitControllerTests`, `VetControllerTests`, `CrashControllerTests`, `ClinicServiceTests` (both modules), and `PetClinicIntegrationTests` all pass. Failing-test count: 0. No expected result has been edited.

Compare the set of test method names against the KPI-2 baseline recorded in §1.1. The set must be identical (same methods, same assertions, redistributed by module).

**Proves**: KPI-2, FR-024.

### 2.5 MySQL and PostgreSQL Integration Tests

```
./mvnw verify -P mysql -pl vets,owners -am
./mvnw verify -P postgres -pl vets,owners -am
```

Expected: `MySqlIntegrationTests` and `PostgresIntegrationTests` pass in both modules. Testcontainers starts the appropriate database engine. Failing-test count: 0.

**Proves**: KPI-2 (MySQL and PostgreSQL variants), FR-024.

### 2.6 Path-Filtered CI Workflows

Create two test branches:

1. A branch that modifies only a file under `vets/src/`. Push it. Observe GitHub Actions.
   - Expected: only `deploy-vets` workflow is triggered. `deploy-owners` is not triggered. The Owners deployment record is unchanged.

2. A branch that modifies only a file under `owners/src/`. Push it. Observe GitHub Actions.
   - Expected: only `deploy-owners` workflow is triggered. `deploy-vets` is not triggered. The Vets deployment record is unchanged.

NEEDS CLARIFICATION: the exact workflow file names and path filter patterns must be confirmed in E4-S3 (research.md §6a). Update this step once E4-S3 is complete.

**Proves**: FR-002, KPI-1 mechanism, User Story 1 scenario 1, User Story 2 scenario 1.

---

## §3 — W2 / S2: Edge in Front of Monolith, Vets Dark

**Purpose**: Verify that the edge routes correctly with the monolith still serving all traffic, and that the dark Vets service matches the monolith byte-for-byte via shadow comparison.

**Proves**: FR-010, FR-011, FR-012, FR-025, SC-003, E3-S8 accepted-when criteria.

### 3.1 Edge Routing Table Verification

With the edge deployed in front of the monolith (all traffic still on the monolith):

```
curl -s -o /dev/null -w "%{http_code}" $VETS_APP_URL/vets.html
curl -s -o /dev/null -w "%{http_code}" $VETS_APP_URL/vets
curl -s -o /dev/null -w "%{http_code}" $VETS_APP_URL/owners/find
curl -s -o /dev/null -w "%{http_code}" $VETS_APP_URL/actuator/health
curl -s -o /dev/null -w "%{http_code}" $VETS_APP_URL/livez
curl -s -o /dev/null -w "%{http_code}" $VETS_APP_URL/readyz
```

Expected:
- `/vets.html` → 200 (served by monolith through edge)
- `/vets` → 200 (served by monolith through edge)
- `/owners/find` → 200 (served by monolith through edge)
- `/actuator/health` → 404 (edge returns 404; no upstream request forwarded)
- `/livez` → 404 (edge returns 404; no upstream request forwarded)
- `/readyz` → 404 (edge returns 404; no upstream request forwarded)

Verify that the upstream request count for the monolith does not increment for the 404 responses. Check the edge access log or the monolith's `http.server.requests` metric on its management port.

**Proves**: FR-010, FR-011, User Story 5 scenario 1.

### 3.2 Golden-Master Contract Tests

Run the contract test suite recorded in E3-S1 against the monolith through the edge:

```
./mvnw verify -pl contracts-tests -P golden-master
```

NEEDS CLARIFICATION: the contract test module name and Maven profile are to be confirmed in E3-S1. Update this step once E3-S1 is complete.

Expected: all golden-master fixtures for GET `/vets` (JSON, XML, no-Accept, `*/*`), GET `/vets.html` (all pages, page size 5, out-of-range redirect), and the owner/pet/visit flows produce an empty diff against the recorded fixtures. Diff count: 0 for status, Content-Type, and body.

**Proves**: SC-003, FR-005, FR-004.

### 3.3 Shadow Comparison (S2 Mirror)

With the dark Vets service running and the edge configured to mirror GET `/vets` and GET `/vets.html` to it (no cookies forwarded):

Allow the mirror to run for the agreed S2 window. Then retrieve the shadow comparison report:

```
# Location of the report is determined by the edge technology and the diff tool chosen in E3-S8
# NEEDS CLARIFICATION: exact command depends on edge technology (research.md §14a, resolved in E4-S6)
```

Expected: diff count over the agreed window is 0 for status, Content-Type, and body between the monolith response and the dark Vets service response. The mirror carries no `JSESSIONID` or locale cookie. A mirror failure has no effect on user-facing responses.

Store the shadow comparison report as a CI artifact. This report is required for the S3 approval gate (E1-S14).

**Proves**: FR-025, SC-003, E3-S8 accepted-when criteria.

### 3.4 Operational Paths — No Upstream Forwarding

Confirm that the edge does not forward operational path requests to either service. Query the upstream request counters before and after sending requests to `/actuator/health`, `/actuator/prometheus`, `/livez`, and `/readyz` through the public edge:

```
curl -s $VETS_APP_URL/actuator/health
curl -s $VETS_APP_URL/actuator/prometheus
curl -s $VETS_APP_URL/livez
curl -s $VETS_APP_URL/readyz
```

Expected: all four return 404. The upstream request count for both services does not increment. Verify via the `http.server.requests` metric on each management port.

**Proves**: FR-011, User Story 5 scenario 1.

---

## §4 — W3 / S3: Route Flip

**Purpose**: Verify that after the route flip, `/vets` and `/vets.html` are served by the Vets service, all other user-facing paths are served by the Owners service, and the flip and rollback each complete within the agreed time with no failed owner requests.

**Proves**: FR-010, SC-002, SC-003, User Story 1 scenarios 2 and 3, User Story 2 scenarios 2 and 3, User Story 3 scenarios 1–5.

**Gate**: This section may only be executed after E1-S14 (delivery lead approval) is recorded. The shadow comparison report from §3.3 must show 0 diffs and the rollback rehearsal from E1-S13 must have passed.

### 4.1 Route Flip Timing

Record the start time. Apply the routing table change (single reviewed file change in the repository, deployed via `deploy-edge`). Record the end time when the first request to `/vets.html` is served by the Vets service.

Expected: the flip completes within the agreed platform time (assumed 10 minutes or less; SC-002). Confirm with the platform team before executing.

**Proves**: SC-002.

### 4.2 Vets Service Responses Post-Flip

```
curl -s -o /dev/null -w "%{http_code}" $VETS_APP_URL/vets.html
curl -s -H "Accept: application/json" -o /dev/null -w "%{http_code}" $VETS_APP_URL/vets
curl -s -H "Accept: application/xml" -o /dev/null -w "%{http_code}" $VETS_APP_URL/vets
```

Expected: all return 200. The response body for GET `/vets` (JSON and XML) is byte-equal to the golden master recorded in E3-S1 for the same data. The response body for GET `/vets.html` matches the golden master for page 1 (page size 5).

**Proves**: SC-003, FR-004, FR-005, User Story 1 scenario 2, User Story 1 scenario 3.

### 4.3 Pagination and Out-of-Range Redirect

```
curl -s -o /dev/null -w "%{http_code} %{redirect_url}" "$VETS_APP_URL/vets.html?page=0"
curl -s -o /dev/null -w "%{http_code} %{redirect_url}" "$VETS_APP_URL/vets.html?page=9999"
```

Expected: both return a redirect (HTTP 302 or 301) to `/vets.html?page=1`. The `Location` header must use the public host or be a relative URL. It must not contain an internal service hostname or port.

**Proves**: FR-004, edge case (out-of-range page number).

### 4.4 Owner Routes Unaffected During Flip

While the flip is in progress (or immediately after), exercise the owner flows:

```
curl -s -o /dev/null -w "%{http_code}" "$OWNERS_APP_URL/owners/find"
curl -s -o /dev/null -w "%{http_code}" "$OWNERS_APP_URL/owners?lastName=Davis"
```

Expected: both return 200. No failed requests during the flip window. The Owners deployment record is unchanged (no new Owners deploy was triggered by the flip).

**Proves**: SC-002 (zero failed owner requests during flip), User Story 2 scenario 2.

### 4.5 Full KPI-2 Suite Post-Flip

```
./mvnw verify -P h2 -pl vets,owners -am
```

Expected: 0 failing tests. No expected result has been edited. The set of test methods is identical to the KPI-2 baseline.

**Proves**: KPI-2, FR-024, User Story 3 scenario 5.

### 4.6 Rollback Rehearsal

Execute the rollback: revert the routing table change via `deploy-edge`. Record the start and end times.

Expected: the revert completes within 5 minutes (E4-S8). Owner routes see zero failed requests during the revert. After the revert, GET `/vets.html` is served by the monolith again. The golden-master diff after the revert is empty.

Re-apply the flip after the rehearsal is recorded.

**Proves**: SC-002, FR-023, E4-S8 accepted-when criteria.

### 4.7 User-Facing Behaviour Unchanged

Manually exercise the following flows through the edge after the flip:

1. Visit `/` — welcome page renders with the same layout as the monolith.
2. Search for an owner by last name — results page renders correctly.
3. Add a new visit for a pet — visit is saved and appears in the pet's visit history.
4. Submit an owner registration form with an invalid telephone number (not matching `\d{10}`) — the same validation error message is shown as in the monolith; no owner record is created.
5. Navigate to `/oups` — error page renders with the same layout as the monolith.

**Proves**: User Story 3 scenarios 1, 3, 4; FR-007, FR-015.

---

## §5 — W4 / S4: Vet Code Removed from Owners Image

**Purpose**: Verify that after three clean releases of the Vets service, the Owners image contains no vet package classes, and that KPI-1 is live and measurable.

**Proves**: FR-001, SC-004, KPI-1 (live measurement), User Story 1 scenario 4, User Story 2 scenario 4.

**Gate**: This section may only be executed after three clean releases of the Vets service post-S3 (E1-S12 accepted-when criterion).

### 5.1 Owners Artifact Contents Post-S4

```
jar tf owners/target/owners-*.jar | grep -E "vet/|Vet\."
```

Expected: empty output. The Owners image contains no classes from the `vet` package.

**Proves**: SC-004, FR-001.

### 5.2 KPI-1 Live Measurement

Deploy a change confined to the vet module. Observe GitHub Actions and the GitHub Deployments API.

Expected:
- Only `deploy-vets` is triggered.
- `deploy-owners` is not triggered.
- The Owners deployment record is unchanged.
- The KPI-1 report job (scheduled) reads the GitHub Deployment records and outputs: count of Owners service deployments in the Vets release window = 0.

Deploy a change confined to the owner module. Observe the same.

Expected:
- Only `deploy-owners` is triggered.
- `deploy-vets` is not triggered.
- The Vets deployment record is unchanged.
- The KPI-1 report outputs: count of Vets service deployments in the Owners release window = 0.

**Proves**: KPI-1, FR-003, User Story 1 scenario 4, User Story 2 scenario 4.

### 5.3 KPI-2 Suite Post-S4

```
./mvnw verify -P h2 -pl vets,owners -am
./mvnw verify -P mysql -pl vets,owners -am
./mvnw verify -P postgres -pl vets,owners -am
```

Expected: 0 failing tests on all three profiles. No expected result has been edited.

**Proves**: KPI-2, FR-024.

---

## §6 — W5 / S5: Optional Vet Schema Copy

**Purpose**: Verify the S5 vet data copy, reconciliation, and freeze window on each supported engine. This section is executed only if the sponsor approves S5 in E1-S15.

**Proves**: FR-021, FR-022, FR-023, SC-001, SC-005, User Story 4 scenarios 1, 2, 4, 5.

**Gate**: Sponsor decision recorded in E1-S15. If the sponsor declines S5, skip this section and close the S5 and S6 stories. KPI-1 is judged on S3 and S4 only.

### 6.1 S5 Rehearsal on Production-Like Data

Execute the S5 rehearsal on a restored copy of production-like data for each supported engine:

```
# MySQL rehearsal
# NEEDS CLARIFICATION: exact command depends on the copy tool chosen in E2-S5 (research.md §15a)

# PostgreSQL rehearsal
# NEEDS CLARIFICATION: exact command depends on the copy tool chosen in E2-S5 (research.md §15a)
```

Record the start and end times of the freeze window (the period during which manual DML on vet tables is suspended).

Expected: freeze window is 15 minutes or less for each engine (SC-001).

**Proves**: SC-001, FR-023.

### 6.2 Reconciliation Report

After the copy completes, run the reconciliation tool:

```
# NEEDS CLARIFICATION: exact command depends on the reconciliation tool chosen in E2-S5
```

Expected:
- Row counts for `vets`, `specialties`, and `vet_specialties` are equal on source and target.
- Per-range checksums for all three tables are equal on source and target.
- Any mismatch causes the tool to exit non-zero and block the switch.
- The reconciliation report is stored as a CI artifact.

**Proves**: FR-021, User Story 4 scenario 1.

### 6.3 Owner PII Scan of S5 Artefacts

Before the switch is approved, run the automated PII scan over all S5 artefacts (copy logs, reconciliation report, any intermediate dump files):

```
# NEEDS CLARIFICATION: exact scan command depends on the tooling chosen in E2-S7
# The scan must check for owner column names: name, address, telephone, and the table name: owners
```

Expected: no owner column name, owner table name, or owner field value appears in any S5 artefact. The scan exits 0. If any match is found, the switch is blocked.

**Proves**: FR-022, SC-005, User Story 4 scenario 4.

### 6.4 spring.sql.init.mode=never Verification

After the S5 switch, restart both services against the populated store. Check the startup logs for both services.

Expected: neither service runs `schema.sql` or `data.sql` at startup. The log contains no DDL execution. `spring.sql.init.mode=never` is in effect for both services.

**Proves**: FR-019, User Story 4 scenario 5.

### 6.5 S5 Rollback

Execute the S5 rollback: redeploy the previous Vets configuration against the old vet tables.

Expected:
- The old vet tables are intact (checksum matches the pre-copy baseline).
- GET `/vets` and GET `/vets.html` return correct responses within 10 minutes of the rollback start (SC-002, E4-S8).
- The rollback is declared invalid and the step stops for re-planning if any write to the vet tables is detected after the S5 copy completed (edge case in spec).

**Proves**: FR-023, User Story 4 scenario 2.

---

## §7 — W5 / S6: Optional Table Drop

**Purpose**: Verify that S6 is blocked until all pre-conditions are met and that the drop is safe.

**Proves**: FR-023, User Story 4 scenario 3.

**Gate**: This section may only be executed after E1-S16 approval: backup taken, restore test succeeded, and sponsor explicit approval given. Three further clean releases after S5 must have occurred (E1-S16 accepted-when criterion).

### 7.1 S6 Pre-Condition Check

Before executing S6, verify each pre-condition:

1. A backup of the old vet tables has been taken and is stored in the agreed location.
2. A restore test has been executed successfully: restore the backup to a test environment and verify row counts and checksums match the pre-drop state.
3. The sponsor has given explicit written approval (recorded in E1-S16).
4. The old vet tables are checksum-unchanged since the S5 switch.

Expected: all four pre-conditions are met. If any is not met, S6 is blocked.

**Proves**: FR-023, User Story 4 scenario 3.

### 7.2 Post-Drop Verification

After the table drop:

```
curl -s -H "Accept: application/json" $VETS_APP_URL/vets
curl -s $VETS_APP_URL/vets.html
```

Expected: both return correct responses from the Vets service using the new schema. The golden-master diff is empty.

**Proves**: SC-003.

---

## §8 — Cross-Cutting: Operational Endpoints

**Purpose**: Verify that operational endpoints are accessible only on the management port and that the edge returns 404 for all operational paths on the public host.

**Proves**: FR-011, FR-016, FR-017, User Story 5 scenarios 1–5.

### 8.1 Edge Returns 404 for Operational Paths

```
curl -s -o /dev/null -w "%{http_code}" $VETS_APP_URL/actuator/health
curl -s -o /dev/null -w "%{http_code}" $VETS_APP_URL/actuator/prometheus
curl -s -o /dev/null -w "%{http_code}" $VETS_APP_URL/livez
curl -s -o /dev/null -w "%{http_code}" $VETS_APP_URL/readyz
```

Expected: all return 404. The upstream request count for both services does not increment (verify via `http.server.requests` on each management port).

**Proves**: FR-011, User Story 5 scenario 1.

### 8.2 Management Port Responds Correctly

```
curl -s $VETS_MGMT_URL/actuator/prometheus
curl -s $OWNERS_MGMT_URL/actuator/health
```

Expected:
- The Vets prometheus response contains `http.server.requests` and `cache.gets` with tag `cache=vets`.
- The Owners health response returns `{"status":"UP"}` (or equivalent; no owner field values in the response body).

**Proves**: FR-016, User Story 5 scenario 2.

### 8.3 Cache Hit Metric

Send two GET `/vets` requests to the Vets service (through the edge or directly):

```
curl -s $VETS_APP_URL/vets
curl -s $VETS_APP_URL/vets
```

Then query the Vets management port:

```
curl -s "$VETS_MGMT_URL/actuator/metrics/cache.gets?tag=cache:vets&tag=result:hit"
```

Expected: the `cache.gets` value with tags `cache=vets` and `result=hit` is greater than 0 after the second request.

**Proves**: FR-006, User Story 5 scenario 3.

### 8.4 Effective Actuator Exposure

Query the effective configuration for both services:

```
curl -s $VETS_MGMT_URL/actuator/info
curl -s $OWNERS_MGMT_URL/actuator/info
```

Then verify that `env`, `heapdump`, `beans`, `mappings`, and `configprops` are not exposed:

```
curl -s -o /dev/null -w "%{http_code}" $VETS_MGMT_URL/actuator/env
curl -s -o /dev/null -w "%{http_code}" $VETS_MGMT_URL/actuator/heapdump
curl -s -o /dev/null -w "%{http_code}" $OWNERS_MGMT_URL/actuator/env
```

Expected: `env`, `heapdump`, `beans`, `mappings`, and `configprops` all return 404 on the management port. The effective `management.endpoints.web.exposure.include` is exactly `health,info,metrics,prometheus` for both services (verify via a configuration test in the CI suite, E1-S10).

**Proves**: FR-016, User Story 5 scenario 4.

### 8.5 Management Port Network Isolation

Attempt a connection to the management port from outside the monitoring namespace (e.g., from a pod in the default namespace):

```
# From a pod outside the monitoring namespace:
# curl -s --connect-timeout 5 http://<vets-pod-ip>:<mgmt-port>/actuator/health
```

Expected: the connection is refused (TCP RST or timeout). The NetworkPolicy is in effect.

**Proves**: FR-017, User Story 5 scenario 5.

---

## §9 — Cross-Cutting: Locale and Session

**Purpose**: Verify that a language selection on one service applies on the other service, that the Vets service issues no session cookie, and that locale cookie attributes are correct.

**Proves**: FR-014, SC-006, FR-007 (telephone validation message in correct language).

### 9.1 Cross-Service Locale Persistence

1. In a browser (or with a cookie-aware HTTP client), navigate to an Owners page and set the language to German: `$OWNERS_APP_URL/owners/find?lang=de`
2. Navigate to the Vets page: `$VETS_APP_URL/vets.html`

Expected: the vets list page is displayed in German. The locale cookie set on the Owners page is sent to the Vets service and honoured.

**Proves**: SC-006, FR-014, User Story 3 scenario 2.

### 9.2 Reverse Direction

1. Set the language to German on the Vets page: `$VETS_APP_URL/vets.html?lang=de`
2. Navigate to an Owners page: `$OWNERS_APP_URL/owners/find`

Expected: the owner search page is displayed in German.

**Proves**: SC-006, FR-014.

### 9.3 No Session Cookie from Vets

```
curl -s -D - $VETS_APP_URL/vets.html | grep -i "set-cookie"
```

Expected: no `JSESSIONID` cookie is set in the response from the Vets service.

**Proves**: E3-S4 accepted-when criterion.

### 9.4 Locale Cookie Attributes

```
curl -s -D - "$VETS_APP_URL/vets.html?lang=de" | grep -i "set-cookie"
```

Expected: the `Set-Cookie` header for the locale cookie carries `HttpOnly` and `SameSite=Lax`. On a TLS endpoint it also carries `Secure`.

**Proves**: E5-S9 accepted-when criterion.

### 9.5 Invalid Locale Cookie Fallback

Send a request with a garbage locale cookie value:

```
curl -s -o /dev/null -w "%{http_code}" -H "Cookie: LOCALE=zzz_INVALID" $VETS_APP_URL/vets.html
```

Expected: 200 response in English (default locale). No 500 error.

**Proves**: E5-S9 accepted-when criterion.

---

## §10 — Cross-Cutting: Owner PII Protection

**Purpose**: Verify that owner personal data does not appear in any Vets-side artefact, log, or metric.

**Proves**: FR-022, SC-005, constitution Section III.

### 10.1 Edge Log Masking

Perform an owner search for a known last name (e.g., "Davis"):

```
curl -s "$OWNERS_APP_URL/owners?lastName=Davis"
```

Retrieve the edge access log for the request. Search for the last name in the log:

```
# NEEDS CLARIFICATION: exact log location depends on the edge technology chosen in E4-S6
grep -i "Davis" <edge-access-log>
```

Expected: the last name "Davis" does not appear in the edge access log. The query string is masked. One request ID can be followed from the edge log to the Owners service application log.

**Proves**: E5-S6 accepted-when criterion, FR-022.

### 10.2 No Owner Values in Vets Metrics

Query the Vets prometheus endpoint:

```
curl -s $VETS_MGMT_URL/actuator/prometheus
```

Expected: no metric tag contains an owner name, address, or telephone number value.

**Proves**: E5-S2 accepted-when criterion, FR-022.

### 10.3 Vets Database Role Cannot Read Owner Tables

Using the Vets database principal:

```
# Connect with DB_VETS_CONN and attempt:
# SELECT * FROM owners LIMIT 1;
# SELECT * FROM pets LIMIT 1;
# SELECT * FROM visits LIMIT 1;
# SELECT * FROM types LIMIT 1;
```

Expected: each query is denied with a permission error. The Vets principal has no SELECT on owner tables.

**Proves**: FR-020, E5-S3 accepted-when criterion.

### 10.4 Visit Append-Only Enforcement

Using the Owners database principal:

```
# Connect with DB_OWNERS_CONN and attempt:
# DELETE FROM visits WHERE id = 1;
```

Expected: the DELETE is denied with a permission error.

**Proves**: FR-008, E5-S8 accepted-when criterion.

---

## §11 — Cross-Cutting: Edge Resilience

**Purpose**: Verify that a failure of one service does not affect the responses of the other, that POST requests are not retried, and that the edge returns the correct error responses.

**Proves**: FR-012, FR-013, edge cases (Vets down, Owners down, POST connection reset).

### 11.1 Vets Service Down — Owner Routes Unaffected

Stop the Vets service (or simulate it being unavailable). Then:

```
curl -s -o /dev/null -w "%{http_code}" $OWNERS_APP_URL/owners/find
curl -s -o /dev/null -w "%{http_code}" $VETS_APP_URL/vets.html
```

Expected:
- `/owners/find` returns 200. Owner routes continue to work without any failed requests.
- `/vets.html` returns 503 with a `Retry-After` header. The response renders the petclinic-ui error page layout.

**Proves**: FR-012, edge case (Vets service down).

### 11.2 Owners Service Down — Vets Routes Unaffected

Stop the Owners service (or simulate it being unavailable). Then:

```
curl -s -o /dev/null -w "%{http_code}" $VETS_APP_URL/vets.html
curl -s -o /dev/null -w "%{http_code}" $OWNERS_APP_URL/owners/find
```

Expected:
- `/vets.html` returns 200 with the correct vets list. The edge does not propagate the Owners failure to the Vets response.
- `/owners/find` returns 503 (or the edge circuit-breaker response).

**Proves**: FR-012, edge case (Owners service down).

### 11.3 POST Not Retried on Connection Reset

Simulate a connection reset after the request body has been sent for a POST to an owner or pet form. Verify the upstream request count:

```
# NEEDS CLARIFICATION: exact fault injection mechanism depends on the edge technology and test tooling
# The upstream request count must be exactly 1 after the reset
```

Expected: the upstream request count is exactly 1. No duplicate owner, pet, or visit record is created. The edge returns the error immediately with no second attempt.

**Proves**: FR-013, edge case (POST connection reset).

---

## Mapping: Success Criteria to Validation Steps

| Success Criterion | Validation Step(s) |
|-------------------|--------------------|
| KPI-1: 0 redeploys of the other service per release | §2.6, §5.2 |
| KPI-2: 0 failing tests, no edits to expected results | §2.4, §2.5, §4.5, §5.3 |
| SC-001: S5 freeze window ≤ 15 minutes | §6.1 |
| SC-002: S3 flip and rollback ≤ 10 minutes, 0 failed owner requests | §4.1, §4.4, §4.6 |
| SC-003: Golden-master diff empty for /vets and /vets.html | §3.2, §3.3, §4.2, §7.2 |
| SC-004: Vets artifact has no owner classes; Owners artifact has no vet classes | §2.3, §5.1 |
| SC-005: Owner PII not in any Vets-side artefact | §6.3, §10.1, §10.2, §10.3 |
| SC-006: Cross-service locale selection with no additional user action | §9.1, §9.2 |

---

## NEEDS CLARIFICATION Summary

The following items in this guide cannot be fully specified until the corresponding research or implementation decisions are made. Each is marked inline above.

| ID | Item | Blocking Story | Section |
|----|------|----------------|---------|
| 5a | Edge router technology; exact curl/admin commands for routing verification, mirroring, and fault injection | E4-S6 | §3.1, §3.3, §11.3 |
| 6a | Exact CI workflow file names and path filter patterns | E4-S3 | §2.6 |
| 7a | KPI-1 counting rule (config-only redeploys, UI bumps, edge redeploys) | E4-S1 | §1.2 |
| 8a | Migration job tool and real MySQL/PostgreSQL script content | E2-S3 | §6.1 |
| 12a | Management port numbers for each service | E4-S5 | §8.2, §8.3, §8.4, §8.5 |
| 14a | Mirroring mechanism and diff tool implementation | E3-S8 | §3.3 |
| 15a | S5 copy tool and reconciliation tool commands | E2-S5, E2-S6 | §6.1, §6.2 |
| 2a | ArchUnit import-check test location and isolation command | E1-S4 | §2.2 |
| E2-S7 | PII scan tool and command for S5 artefacts | E2-S7 | §6.3 |

Update this document in place when each clarification is resolved. Do not create a separate version; amend the relevant step and remove the NEEDS CLARIFICATION marker.
