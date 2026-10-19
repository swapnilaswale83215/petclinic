# Feature Specification: Production Database Migration — MySQL 8.0 to Managed PostgreSQL

**Feature Branch**: `009-production-database-mysql-8-0-8e2187cf`

**Created**: 2026-10-19

**Status**: Draft

**Input**: User description: "Move Petclinic's production database from our self-managed MySQL 8.0 server to managed PostgreSQL."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Data Copied Intact to PostgreSQL (Priority: P1)

A database administrator runs the forward data copy from the frozen MySQL source to the empty pre-staged PostgreSQL schema. Every owner, pet, visit, vet, pet type, specialty and vet-specialty row arrives on PostgreSQL byte-identical to the source, referential integrity is intact, and the reconciliation tool confirms zero differing rows across all seven tables.

**Why this priority**: Without a verified, complete and correct copy of production data, no other step in the migration can proceed safely. This is the irreducible core of the migration.

**Independent Test**: Can be fully tested by running the db-copier against a production-sized rehearsal copy of MySQL into a freshly created PostgreSQL schema, then running the reconciliation tool and confirming exit code 0 with zero differing rows for all seven tables, before any application is started.

**Acceptance Scenarios**:

1. **Given** the MySQL source has super_read_only enabled and all seven target tables are empty, **When** the db-copier runs with `--assert-frozen`, **Then** it exits 0, the JSON report lists equal row counts and matching SHA-256 bucket checksums for owners, pets, visits, vets, types, specialties and vet_specialties, and no file containing row values is written on the copier host. *(SPEC-DATA-2, SPEC-DATA-4, KPI-1)*
2. **Given** the copy has completed, **When** the reconciliation tool compares the frozen MySQL manifest to PostgreSQL, **Then** counts and all per-1,000-id bucket checksums match for all seven tables, the tool exits 0, and the report contains no owner personal data. *(SPEC-DATA-4, KPI-1)*
3. **Given** the copy has completed, **When** orphan queries run on PostgreSQL (pets without owner, visits without pet, pets without type, vet_specialties without vet or specialty), **Then** each query returns the same count as on the frozen MySQL source. *(SPEC-DATA-5, SPEC-APP-6)*
4. **Given** the copy has completed, **When** the identity sequences are reset, **Then** for each of the six id-bearing tables the next identity value is ≥ max(id)+1, and creating a new owner, pet and visit through the application produces no duplicate-key error. *(SPEC-DATA-3)*
5. **Given** a non-empty target table exists before the copy starts, **When** the db-copier is invoked, **Then** it exits 2 before writing any row. *(SPEC-APP-9, SPEC-DATA-2)*
6. **Given** the MySQL source does not have super_read_only enabled, **When** the db-copier is invoked without `--assert-frozen`, **Then** it exits 2 before writing any row. *(SPEC-APP-9, SPEC-DATA-2)*
7. **Given** a forced mid-copy failure occurs during the visits table step, **When** the failure is detected, **Then** the copier exits 3, no partial data is accepted, and a full re-run after dropping and recreating the target schema exits 0 with zero differing rows. *(SPEC-DATA-2, SPEC-INT-5)*

---

### User Story 2 — Application Serves All Screens Identically on PostgreSQL (Priority: P1)

A clinic user (receptionist or administrator) uses every screen of the Petclinic application — owner search and list, owner create and edit, pet create and edit with type selection, visit creation and history, and the vet list with specialties — and observes no difference in behaviour, content or order compared with the MySQL-backed application.

**Why this priority**: The migration must be invisible to users. Any screen regression discovered after cutover would require an immediate rollback, so parity must be proven before the maintenance window opens.

**Independent Test**: Can be fully tested by running the golden-master contract test suite against both the MySQL and PostgreSQL rehearsal copies and confirming all recorded responses are equal, including search results for 'davis', 'DAVIS' and 'Davis' returning the same owners in the same order. *(SPEC-INT-1, SPEC-APP-2)*

**Acceptance Scenarios**:

1. **Given** the application runs on the `postgres,prod` profile, **When** a user searches for owners by last-name prefix using 'davis', 'DAVIS' or 'Davis', **Then** the same owners are returned in the same order as on the MySQL-backed application. *(SPEC-APP-2, SPEC-DATA-9, DEF-1)*
2. **Given** the application runs on the `postgres,prod` profile, **When** a user searches with a last-name prefix containing `%` or `_`, **Then** those characters are treated as literals, matching the MySQL behaviour. *(SPEC-APP-2, SPEC-INT-1)*
3. **Given** the application runs on the `postgres,prod` profile, **When** a user opens the vets page, **Then** vets with zero specialties are shown, the list order matches MySQL, and the second request is served from the cache without a database query. *(SPEC-APP-2, SPEC-INT-1)*
4. **Given** the application runs on the `postgres,prod` profile, **When** a user opens the pet registration form, **Then** every pet type is listed and a new pet can be saved without error. *(SPEC-APP-2, SPEC-INT-1)*
5. **Given** the application runs on the `postgres,prod` profile, **When** a user creates a new owner, adds a pet and records a visit, **Then** all three records are persisted and visible on the relevant screens with no duplicate-key error. *(SPEC-APP-2, SPEC-DATA-3)*
6. **Given** the application runs on the `postgres,prod` profile, **When** invalid input is submitted on any form, **Then** the same validation error messages and HTTP status codes are returned as on MySQL. *(SPEC-INT-1)*
7. **Given** the application runs on the `postgres,prod` profile, **When** the owner list, vet list and visit-per-pet list are rendered, **Then** the row order is identical to MySQL, or an explicit ORDER BY has been added with no visible change to the user. *(SPEC-APP-2, SPEC-DATA-9)*

---

### User Story 3 — Production Cutover Completes Within the Maintenance Window (Priority: P1)

The operations team executes the production cutover during a weekend maintenance window: they freeze writes, copy data, reset sequences, reconcile, switch the Service selector to the green PostgreSQL-backed deployment, and confirm the application is serving traffic — all within 30 minutes of downtime.

**Why this priority**: The 30-minute downtime constraint is a hard business requirement. Exceeding it triggers Rollback A. The entire cutover sequence must be rehearsed and timed before the window.

**Independent Test**: Can be fully tested by executing the full cutover runbook end-to-end on a production-sized rehearsal copy, recording the elapsed time from T0 to the first green `/readyz` 200 response through the Service, and confirming the result is ≤ 25 minutes (with a hard ceiling of 30 minutes). *(SPEC-APP-3, SPEC-APP-4, SPEC-DATA-8, KPI-2)*

**Acceptance Scenarios**:

1. **Given** the maintenance window starts (T0), **When** the application is stopped and the maintenance responder is activated, **Then** every HTTP request on every path returns 503 with `Retry-After` and `Cache-Control: no-store`, and no application pod is serving. *(SPEC-APP-3, SPEC-INT-3)*
2. **Given** the maintenance responder is active, **When** MySQL super_read_only is set at T0+2, **Then** an INSERT as the application MySQL user fails, confirming the source is frozen. *(SPEC-APP-3)*
3. **Given** the data copy and reconciliation complete at T+20, **When** the go/no-go criteria are evaluated (reconciliation green, orphan checks equal, identity values ≥ max(id)+1, green `/readyz` 200, read-only smoke passed, counts unchanged after first boot), **Then** all criteria are met and the Service selector is switched to green. *(SPEC-APP-4)*
4. **Given** any go/no-go criterion fails at T+20, **When** the failure is detected, **Then** Rollback A is triggered without discussion and the Service selector returns to blue (MySQL). *(SPEC-APP-4, SPEC-APP-5)*
5. **Given** the Service selector is switched to green, **When** the first request reaches the PostgreSQL-backed application, **Then** `/readyz` returns 200 with the database included in the readiness group, and `/` and `/vets.html` serve correct content. *(SPEC-INT-2, SPEC-PLAT-1)*
6. **Given** the cutover is complete, **When** the elapsed time from T0 to the first green `/readyz` 200 through the Service is measured, **Then** it is ≤ 30 minutes, and the measured time is recorded as KPI-2 evidence. *(KPI-2)*

---

### User Story 4 — Rollback Path Rehearsed and Ready Before the Window (Priority: P1)

Before the production maintenance window opens, the operations team has successfully rehearsed both rollback forms on a production-sized copy: Rollback A (return to untouched MySQL before any PostgreSQL write) and Rollback B (copy PostgreSQL back into a new empty MySQL schema after test writes), and has confirmed the application on MySQL passes the KPI-1 reconciliation in both cases.

**Why this priority**: A tested rollback is a hard prerequisite (KPI-3). Without it the maintenance window must not open.

**Independent Test**: Can be fully tested by executing Rollback A and Rollback B rehearsals on a production-sized copy, logging start and end times per step, and confirming the application on `mysql,prod` passes the KPI-1 reconciliation with zero differing rows in both cases. *(SPEC-APP-5, SPEC-DATA-7, SPEC-DATA-8, KPI-3)*

**Acceptance Scenarios**:

1. **Given** the forward copy has completed and no write has yet reached PostgreSQL, **When** Rollback A is executed, **Then** it completes in ≤ 5 minutes, the Service selector returns to blue, and the application on `mysql,prod` passes the KPI-1 reconciliation against the frozen snapshot. *(SPEC-APP-5)*
2. **Given** test writes have been made to PostgreSQL after cutover, **When** Rollback B is executed (reverse copy into a new empty MySQL schema from db/mysql/schema.sql), **Then** it completes in ≤ 30 minutes, every row including the test writes reconciles to zero differing rows on MySQL, and the original MySQL schema checksum is identical before and after. *(SPEC-APP-5, SPEC-DATA-7)*
3. **Given** Rollback B is about to run, **When** the pre-check detects a PostgreSQL pet name that differs from an existing MySQL name only by case or accent for the same owner, or a first name exceeding 30 characters, **Then** the copier exits 2 before any write to the new MySQL schema. *(SPEC-DATA-7)*
4. **Given** at least one successful rehearsal of each rollback form has been logged, **When** the production window opens, **Then** the rehearsal logs (with per-step start and end times and KPI-1 evidence) are attached to the cutover record. *(KPI-3, SPEC-DATA-8)*

---

### User Story 5 — Production Profile Overlay Protects Data and Probes (Priority: P2)

An operator deploying the application with the `postgres,prod` or `mysql,prod` profile confirms that startup SQL is disabled, actuator exposure is restricted to `/actuator/health` and `/actuator/info`, owner personal data does not appear in any actuator or probe output, and the Kubernetes liveness and readiness probes use `/livez` and `/readyz` respectively.

**Why this priority**: Data protection and correct probe behaviour are required for a safe production deployment, but they can be validated independently of the data migration steps.

**Independent Test**: Can be fully tested by starting the application with `postgres,prod` and `mysql,prod` profiles in the rehearsal environment, querying all actuator paths, and confirming the probe and data-exposure behaviour described below. *(SPEC-APP-1, SPEC-APP-7, SPEC-INT-2)*

**Acceptance Scenarios**:

1. **Given** the application starts with `postgres,prod`, **When** `spring.sql.init.mode` is resolved, **Then** it is `never` and row counts of all seven tables are identical before and after the first boot. *(SPEC-APP-1)*
2. **Given** the application runs on either `postgres,prod` or `mysql,prod`, **When** `/actuator/health`, `/actuator/info`, `/livez` and `/readyz` are requested, **Then** all return 200; every other `/actuator/*` path returns 404; none of the responses contains owner name, address, telephone or any row-level data. *(SPEC-APP-1, SPEC-APP-7, SPEC-INT-2)*
3. **Given** the application runs on either engine profile, **When** the database is unreachable, **Then** `/readyz` returns 503 and `/livez` returns 200, and the readiness group resolves to `readinessState,db`. *(SPEC-APP-1, SPEC-INT-2)*
4. **Given** the production datasource URL is inspected, **When** the TLS configuration is checked, **Then** the PostgreSQL URL includes `sslmode=verify-full` and the MySQL rollback URL uses an equivalent TLS setting; no credential appears in the repository, manifests or image. *(SPEC-APP-7, SPEC-INT-6)*

---

### User Story 6 — Visit Append-Only and Referential Integrity Survive the Migration (Priority: P2)

A data auditor confirms that no visit record has been deleted, re-created or re-keyed by any migration step or by the application running on PostgreSQL, that every pet still belongs to exactly one owner, every visit to exactly one pet, and every pet has a valid type.

**Why this priority**: These are non-negotiable business rules (constitution §II). They must be verified as a discrete step, independently of the full cutover sequence.

**Independent Test**: Can be fully tested by running the orphan and integrity queries on both the frozen MySQL source and the PostgreSQL target after the copy, comparing counts, and reviewing the copier SQL to confirm no DELETE, UPDATE or TRUNCATE touches visits on either engine. *(SPEC-APP-6, SPEC-DATA-5, SPEC-DATA-6)*

**Acceptance Scenarios**:

1. **Given** the forward copy has completed, **When** visit ids and dates on PostgreSQL are compared to the frozen MySQL manifest, **Then** they are identical, and the visit count on PostgreSQL is ≥ the frozen MySQL count at any later time. *(SPEC-DATA-6, SPEC-APP-6)*
2. **Given** a code and SQL review of the copier, **When** all SQL statements against visits are inspected, **Then** the source sees only SELECT and the target sees only INSERT; no DELETE, UPDATE or TRUNCATE appears on visits in either direction. *(SPEC-DATA-6)*
3. **Given** the forward copy has completed, **When** orphan queries run on PostgreSQL, **Then** pets without owner, visits without pet, pets without type, and vet_specialties without vet or specialty each return the same count as on the frozen MySQL source. *(SPEC-DATA-5)*
4. **Given** Rollback B has completed, **When** the original MySQL visits table checksum is compared before and after the rehearsal, **Then** it is identical. *(SPEC-DATA-6, SPEC-APP-5)*

---

### Edge Cases

- What happens when the db-copier is invoked against a target that already has rows in one or more tables? → It must exit 2 before writing any row to any table. *(SPEC-APP-9)*
- What happens when a mid-copy failure occurs after rows have been written to the visits table? → The copier exits 3; recovery requires dropping and recreating the entire target schema and running a full copy from the beginning. *(SPEC-DATA-2, SPEC-INT-5)*
- What happens when `owners.last_name` contains non-ASCII or accented characters? → The pre-check reports the count; if any exist, accent-sensitivity differences between MySQL's collation and PostgreSQL's encoding are compared and either resolved or accepted in writing by the sponsor before G1. *(SPEC-DATA-1, SPEC-DATA-9, SPEC-APP-2)*
- What happens when the duplicate `(owner_id, lower(name))` pre-check on MySQL returns non-zero rows? → The rows are reported to the sponsor and resolved before the maintenance window opens. *(SPEC-DATA-1, SPEC-APP-6)*
- What happens when the copy plus reconciliation step exceeds 15 minutes in rehearsal? → The design is escalated per ADR-APP-3 (fallback to CDC) before G2; the cutover window does not open until the timing constraint is met. *(SPEC-DATA-8)*
- What happens when any go/no-go criterion fails at T+20? → Rollback A is triggered immediately without discussion. *(SPEC-APP-4)*
- What happens when a POST to create-owner or create-visit is received while the maintenance responder is active? → The request returns 503 and no row change occurs on either database. *(SPEC-INT-3)*
- What happens when the integer primary key of any id-bearing table is at or near the 32-bit signed maximum (2,147,483,647)? → The pre-check blocks the cutover and reports the table. *(SPEC-DATA-1)*
- What happens when a `0000-00-00` date or a NUL character is found in the MySQL source? → The pre-check blocks the cutover and reports the affected rows. *(SPEC-DATA-1)*
- What happens when a new consumer of the MySQL database is discovered during rehearsal? → It is added to the consumer inventory, assigned an owner and a cutover action, and re-confirmed before the window. *(SPEC-INT-7)*

---

## Requirements *(mandatory)*

### Functional Requirements

#### Application Configuration

- **FR-001** *(SPEC-APP-1)*: The system MUST provide a `prod` profile overlay that sets `spring.sql.init.mode=never`, restricts actuator exposure to `/actuator/health` and `/actuator/info`, and works with both the `postgres` and `mysql` engine profiles without modifying `application-mysql.properties`.
- **FR-002** *(SPEC-APP-1)*: The `prod` profile overlay MUST enable Kubernetes probe paths `/livez` and `/readyz` (`probes.enabled=true`, `probes.add-additional-paths=true`) and configure the readiness group to include `readinessState` and `db`; the liveness group MUST NOT include `db`.
- **FR-003** *(SPEC-APP-2, DEF-1)*: The `OwnerRepository` MUST expose a `findByLastNameStartingWithIgnoreCase` method that performs case-insensitive prefix search on both MySQL and PostgreSQL, replacing the previous case-sensitive method. This is the only permitted application code change in the cutover release.
- **FR-004** *(SPEC-APP-8)*: The cutover release MUST be built from one pinned commit. No schema, entity, validation or controller change other than the `OwnerRepository` method rename and its call sites MAY be merged between the first rehearsal and the production cutover.

#### Data Copy — Forward Direction (MySQL → PostgreSQL)

- **FR-005** *(SPEC-DATA-1)*: The target PostgreSQL schema MUST be created from `db/postgres/schema.sql` unchanged, with one additional script adding a functional index on `lower(last_name)` with `text_pattern_ops` on the `owners` table (ADR-DATA-5). All seven tables MUST be empty before the copy starts.
- **FR-006** *(SPEC-DATA-2, SPEC-APP-9)*: The db-copier MUST copy all seven tables — types, specialties, vets, owners, pets, visits, vet_specialties — in that order, preserving ids, dates and text byte-for-byte, over TLS, without writing any file containing row values on the copier host.
- **FR-007** *(SPEC-APP-9)*: The db-copier MUST use exactly four exit codes: 0 (copied and verified), 1 (usage/config/connection error), 2 (precondition failed — non-empty target, unfrozen source, or missing `--assert-frozen`), 3 (copy error or checksum mismatch). No other exit codes are permitted.
- **FR-008** *(SPEC-APP-9)*: The db-copier MUST NOT be resumable. Recovery from any failure MUST require dropping and recreating the target schema from the pre-stage DDL and running a full copy from the beginning.
- **FR-009** *(SPEC-DATA-3)*: After the copy and before any application start, the identity sequence of each of the six id-bearing tables (owners, pets, visits, vets, types, specialties) MUST be set to max(id)+1 (or 1 for an empty table), followed by ANALYZE.
- **FR-010** *(SPEC-DATA-4)*: The reconciliation tool MUST compute per-table row counts and SHA-256 canonical checksums per 1,000-id bucket for all seven tables on both engines using one definition and one output format, compare the target to the frozen manifest, and exit 0 only when all counts and checksums match.

#### Data Copy — Reverse Direction (PostgreSQL → MySQL, Rollback B)

- **FR-011** *(SPEC-DATA-7, SPEC-APP-5)*: The db-copier MUST support copying from PostgreSQL into a new empty MySQL schema created from `db/mysql/schema.sql`, under the same contract as the forward copy (SPEC-APP-9). The original MySQL schema MUST NOT be touched.
- **FR-012** *(SPEC-DATA-7)*: Before the reverse copy, a pre-check MUST detect and block (exit 2) on: a PostgreSQL pet name that differs from an existing MySQL name only by case or accent for the same owner, or a first name exceeding 30 characters.

#### Write Freeze and Cutover Sequence

- **FR-013** *(SPEC-APP-3)*: During the cutover freeze, the application MUST be stopped behind a maintenance responder that returns HTTP 503 with `Retry-After` and `Cache-Control: no-store` for every request on every path and method, reaching no database.
- **FR-014** *(SPEC-APP-3)*: MySQL MUST be set to `super_read_only` no later than T0+2 minutes. The total freeze duration from T0 to the application serving traffic on PostgreSQL MUST NOT exceed 30 minutes.
- **FR-015** *(SPEC-APP-4)*: The cutover MUST follow the ordered steps and time budgets of ADR-APP-4: freeze manifest T0+2, copy T+2 to T+14, identity reset T+14 to T+15, reconciliation T+15 to T+20, go/no-go at T+20.
- **FR-016** *(SPEC-APP-4)*: The go/no-go at T+20 MUST evaluate all of: reconciliation green (exit 0), orphan checks equal, identity values ≥ max(id)+1, green `/readyz` 200 (database included), read-only smoke passed, and counts unchanged after first boot. Any failed criterion MUST trigger Rollback A without discussion.
- **FR-017** *(SPEC-PLAT-1)*: The Service selector switch between blue (MySQL), maintenance and green (PostgreSQL) deployments MUST be atomic and idempotent, take effect in ≤ 10 seconds, and leave the Service name and port unchanged for clients.

#### Rollback

- **FR-018** *(SPEC-APP-5)*: Rollback A (before the first PostgreSQL write) MUST return the Service to the untouched MySQL-backed blue deployment in ≤ 5 minutes, and the application on `mysql,prod` MUST pass the KPI-1 reconciliation against the frozen snapshot.
- **FR-019** *(SPEC-APP-5)*: Rollback B (after PostgreSQL writes) MUST copy all data including post-cutover writes into a new empty MySQL schema in ≤ 30 minutes, reconcile to zero differing rows, and leave the original MySQL schema checksum unchanged.
- **FR-020** *(KPI-3)*: At least one successful rehearsal of each rollback form (A and B) MUST be logged with per-step start and end times before the production maintenance window opens.

#### Data Integrity and Visit Append-Only

- **FR-021** *(SPEC-DATA-6, SPEC-APP-6)*: No migration step or application code path on PostgreSQL MAY issue a DELETE, UPDATE or TRUNCATE on the visits table on either engine. The copier's source credentials on MySQL MUST be SELECT-only.
- **FR-022** *(SPEC-DATA-5)*: Referential integrity constraints (foreign keys) MUST be enabled on PostgreSQL during and after the load. No `session_replication_role` bypass is permitted.

#### Owner Personal Data Protection

- **FR-023** *(SPEC-APP-7)*: The PostgreSQL datasource URL in production MUST include `sslmode=verify-full`. The MySQL rollback URL MUST use an equivalent TLS setting. All credentials MUST come from the platform secret store; none MAY appear in the repository, manifests or image.
- **FR-024** *(SPEC-APP-7)*: The db-copier JSON report and logs MUST contain no owner personal data (name, address, telephone). Any staging files, if created, MUST be encrypted and deleted after use, with deletion logged.
- **FR-025** *(SPEC-APP-7, SPEC-APP-1)*: Actuator, `/livez` and `/readyz` output on the production profile MUST contain no owner personal data.

#### Pre-Flight Checks

- **FR-026** *(SPEC-DATA-1)*: Pre-flight checks MUST run in every rehearsal and again at T0 on the frozen source, and MUST block the cutover if any of the following are found: max(id) > 2,147,483,647 for any id-bearing table; `0000-00-00` dates; NUL characters; charset other than utf8mb4 (or containing 4-byte characters); duplicate `(owner_id, lower(name))` pairs; non-ASCII characters in `owners.last_name` (count reported, not blocking unless the accent decision is unresolved).

#### Consumer Inventory

- **FR-027** *(SPEC-INT-7)*: Before G2, every consumer of the changed interfaces (HTTP/probe consumers and direct MySQL clients) MUST be listed with an owner, access method, cutover action and confirmation date. No row MAY have an unknown owner.

#### CI Gate

- **FR-028** *(SPEC-APP-8)*: The CI pipeline MUST include a PostgreSQL test gate (ClinicServiceTests, controller tests, PetClinicConcurrencyTests, owner-search case-parity test, probe-path test) that runs against the pinned commit and passes before the cutover release is approved.

---

### Key Entities

- **Owner**: Holds name, address, city and telephone number (sensitive zone per constitution §III). Migrated intact; personal data protected in transit and at rest. Identified by integer primary key; sequence reset after copy.
- **Pet**: Belongs to exactly one Owner; has a PetType; carries an append-only visit history. Identified by integer primary key; sequence reset after copy.
- **Visit**: Immutable once created (constitution §II); associated with exactly one Pet. Ids and dates must be identical source-to-target; count on PostgreSQL must be ≥ frozen MySQL count at all times after cutover.
- **Veterinarian (Vet)**: May have zero or many Specialties. Vet list with specialties (including zero-specialty vets) and its cache must keep working on PostgreSQL.
- **PetType**: Required at pet registration. Lookup data must be copied intact and remain selectable on PostgreSQL.
- **Specialty**: Optional; zero or many per Vet. Copied intact; vet-specialty associations verified by composite key in reconciliation.
- **vet_specialties** (join table): Verified by composite key (vet_id, specialty_id) in reconciliation and orphan checks.
- **db-copier** (migration tool, `tools/db-copier`): Bidirectional JDBC batch copier. Not resumable; requires empty target and frozen source; uses exit codes 0/1/2/3. Owned by the data track for detailed spec (SPEC-DATA-2); contract defined in SPEC-APP-9.
- **Reconciliation tool**: Computes per-table counts and SHA-256 canonical checksums per 1,000-id bucket on both engines; produces a report containing no row values; exits 0 only on full equality.
- **Frozen manifest**: The per-table row counts and checksums captured at T0+2 (after super_read_only is set) against which all subsequent reconciliations are compared.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **KPI-1**: Zero owner, pet, visit or vet rows differ between MySQL and PostgreSQL after cutover. | Metric: rows differing between the frozen MySQL manifest and the PostgreSQL target, per table (owners, pets, visits, vets, types, specialties, vet_specialties), measured by the reconciliation tool's per-1,000-id bucket SHA-256 checksums and row counts. | Target: 0 differing rows across all seven tables.
- **KPI-2**: Production downtime is at most 30 minutes. | Metric: minutes of production unavailability from T0 (maintenance responder activated) to the first green `/readyz` 200 response through the Service, recorded from health endpoint and monitoring logs. | Target: ≤ 30 minutes; timed dress rehearsal must complete in ≤ 25 minutes.
- **KPI-3**: The rollback path to MySQL has been tested before the switch. | Metric: count of successful rehearsals of each rollback form (A and B) completed on a production-sized copy before the cutover window, each passing the KPI-1 reconciliation on MySQL. | Target: ≥ 1 successful rehearsal of each form, logged with per-step timings, completed before the window opens.
- **SC-001**: Every screen behaves identically on PostgreSQL and MySQL. | Metric: golden-master contract test pass rate across all routes and methods (owner search and lists, owner/pet/visit create and edit, pet-type selection, vet list). | Target: 100% of recorded responses equal on both engines, including case-insensitive search parity for 'davis', 'DAVIS' and 'Davis'.
- **SC-002**: The application recovers readiness automatically when the database returns after a transient outage, without a pod restart. | Metric: `/readyz` returns 200 within the probe's failure-threshold window after the database is restored, while `/livez` remained 200 throughout. | Target: recovery observed in at least one rehearsal scenario.
- **SC-003**: The identity sequence reset completes within budget. | Metric: elapsed time for the identity reset step (T+14 to T+15 budget). | Target: ≤ 1 minute in the timed rehearsal.
- **SC-004**: The reconciliation step completes within budget. | Metric: elapsed time for the reconciliation step (T+15 to T+20 budget). | Target: ≤ 5 minutes on the production-sized rehearsal copy.
- **SC-005**: The data copy step completes within budget. | Metric: elapsed time for the db-copier forward run (T+2 to T+14 budget). | Target: ≤ 12 minutes on the production-sized rehearsal copy; if exceeded, CDC escalation is raised before G2.
- **SC-006**: No owner personal data is exposed in any migration artefact, log, report or endpoint. | Metric: search of the db-copier JSON report, copier logs and actuator/probe responses for rehearsal owner names, addresses and telephone numbers. | Target: zero matches found.

---

## Assumptions

- The managed PostgreSQL service is already provisioned, network-accessible from the petclinic and copier namespaces only, TLS-enforced, encrypted at rest, highly available with a standby, and configured for point-in-time recovery (PITR) before the maintenance window. *(SPEC-PLAT-2)*
- The production MySQL 8.0 data volume (all seven tables) fits within the 12-minute copy budget and the 5-minute reconciliation budget on the available network and hardware. If rehearsal timing exceeds these budgets, a CDC-based fallback will be evaluated per ADR-APP-3 before G2.
- The H2 in-memory default profile and all non-production environments (development, test, staging using H2) are out of scope for this migration and are not modified.
- Open GitHub issues #2, #3 and #5 and open PRs #1 and #4 are confirmed not part of the cutover release and will not be merged between the first rehearsal and the production window.
- The `db/postgres/schema.sql` file already exists in the repository and correctly represents the target schema with one-to-one type mapping from MySQL (ADR-DATA-1). The only addition is the `lower(last_name) text_pattern_ops` index applied by a separate pre-stage script.
- The `db/mysql/schema.sql` file and `application-mysql.properties` are unchanged by this migration and remain the authoritative rollback target definition.
- The platform secret store is available and can supply separate credentials for the application role, the copier/admin role and the MySQL rollback user as environment variables.
- The production MySQL character set is utf8mb4 and contains no `0000-00-00` dates, NUL characters or integer ids at or near the 32-bit signed maximum. If the pre-flight checks find otherwise, the cutover is blocked until the issues are resolved.
- The accent-sensitivity question (MySQL accent-insensitive collation vs PostgreSQL default collation) will be resolved or accepted in writing by the sponsor before G1, based on the non-ASCII character count reported by the pre-flight check. If no non-ASCII last names exist in production data, this is recorded as evidence and no further action is required.
- The `vet_specialties` join table has no surrogate integer primary key; reconciliation uses the composite key `(vet_id, specialty_id)`.
- The blue/green Kubernetes deployment structure (blue = MySQL, green = PostgreSQL, maintenance = 503 responder) and the Service selector switch mechanism are already in place or will be in place before the first rehearsal, as specified in SPEC-PLAT-1.
- The uptime monitor is configured to treat the maintenance window as planned downtime for alerting purposes, while still logging the outage duration for KPI-2 evidence.
- No functional or screen changes, schema changes beyond engine-compatibility requirements, or business-rule changes are in scope. Any such change proposed during the migration must be deferred and tracked separately.
- The `PetClinicConcurrencyTests`, `ClinicServiceTests`, `MySqlIntegrationTests` and `PostgresIntegrationTests` suites all pass on the pinned commit before the cutover release is approved.
