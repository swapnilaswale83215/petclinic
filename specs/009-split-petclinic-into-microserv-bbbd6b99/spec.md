# Feature Specification: Split PetClinic into Microservices

**Feature Branch**: `009-split-petclinic-into-microserv-bbbd6b99`

**Created**: 2026-10-19

**Status**: Draft

**Input**: User description: "Split PetClinic into independently deployable services so the Vets and Owners teams can release separately."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Vets Team Releases Without Waiting for Owners Team (Priority: P1)

A developer on the Vets team merges a change to the vet package. The CI pipeline builds and deploys only the Vets service. The Owners service is not rebuilt, retested, or redeployed. The vets list page and the JSON vets resource continue to work for end users without interruption.

**Why this priority**: This is the primary stated goal of the split. Until a change to one service can be released without touching the other, the migration has not delivered its core value. All other stories depend on this independence being real and verifiable.

**Independent Test**: Merge a commit that changes only a file in the vet package. Confirm that only the deploy-vets workflow runs after merge, that deploy-owners does not run, and that GET /vets.html and GET /vets return correct responses throughout.

**Acceptance Scenarios**:

1. **Given** a commit that modifies only the vet package, **When** the commit is merged to main, **Then** only the Vets service build and deploy workflow is triggered; the Owners service workflow is not triggered and the Owners deployment record is unchanged.
2. **Given** the Vets service has been redeployed with a new image, **When** a user visits /vets.html, **Then** the vets list renders correctly with page size 5 and the same layout as before the deploy.
3. **Given** the Vets service has been redeployed, **When** a client sends GET /vets with Accept: application/json, **Then** the response body, field names, and Content-Type are identical to those of the monolith for the same data.
4. **Given** a production deploy of the Vets service, **When** the KPI-1 report is generated for that release window, **Then** the count of Owners service deployments in that window is 0.

---

### User Story 2 — Owners Team Releases Without Waiting for Vets Team (Priority: P1)

A developer on the Owners team merges a change to the owner package. The CI pipeline builds and deploys only the Owners service. The Vets service is not rebuilt, retested, or redeployed. Owner search, owner and pet editing, and visit creation continue to work for end users without interruption.

**Why this priority**: Equal in importance to User Story 1. The split must be symmetric: both teams gain release independence, not just one.

**Independent Test**: Merge a commit that changes only a file in the owner package. Confirm that only the deploy-owners workflow runs, that deploy-vets does not run, and that the full owner, pet, and visit flows work correctly throughout.

**Acceptance Scenarios**:

1. **Given** a commit that modifies only the owner package, **When** the commit is merged to main, **Then** only the Owners service build and deploy workflow is triggered; the Vets service workflow is not triggered and the Vets deployment record is unchanged.
2. **Given** the Owners service has been redeployed, **When** a user searches for an owner by last name, **Then** the search results page renders correctly with the same layout and data as before the deploy.
3. **Given** the Owners service has been redeployed, **When** a user adds a new visit for a pet, **Then** the visit is saved and appears in the pet's visit history; no existing visit record is altered or deleted.
4. **Given** a production deploy of the Owners service, **When** the KPI-1 report is generated for that release window, **Then** the count of Vets service deployments in that window is 0.

---

### User Story 3 — End User Sees No Change After the Split (Priority: P1)

A clinic receptionist uses PetClinic as normal after the split is complete. Every page they visit — the welcome page, owner search, owner and pet forms, the vets list, error pages — looks and behaves exactly as it did before. No URL changes, no layout differences, no missing translations, no new error messages.

**Why this priority**: The agreed brief explicitly prohibits any change to what a user sees. Regression here would invalidate the migration regardless of the independence achieved.

**Independent Test**: Run the full existing UI and controller test suite (OwnerControllerTests, PetControllerTests, VisitControllerTests, VetControllerTests, CrashControllerTests, ClinicServiceTests, PetClinicIntegrationTests) against the split system with no edits to expected results. All must pass.

**Acceptance Scenarios**:

1. **Given** the split system is running behind the edge router, **When** a user visits /, **Then** the welcome page is identical in layout and content to the monolith's welcome page.
2. **Given** the split system is running, **When** a user sets the language to German on an Owners page and then navigates to /vets.html, **Then** the vets list page is displayed in German.
3. **Given** the split system is running, **When** a user submits an owner registration form with an invalid telephone number (not matching \d{10}), **Then** the same validation error message is shown as in the monolith, and no owner record is created.
4. **Given** the split system is running, **When** a user navigates to /oups, **Then** the error page renders with the same layout as in the monolith.
5. **Given** the full existing test suite is run against the split system, **When** all tests complete, **Then** the count of failing tests is 0 and no expected result has been edited.

---

### User Story 4 — Staged Migration Proceeds One Step at a Time Without Data Loss (Priority: P2)

The migration team executes the cutover in defined stages (S2 through S6). At each stage the system is verifiably correct, rollback is available, and no owner data is exposed or lost. The vet data copy (S5) is preceded by reconciliation and followed by verification. The old vet tables are not dropped (S6) until a backup has been taken and a restore test has succeeded.

**Why this priority**: The staged approach is a hard constraint from the brief. Each stage must be independently safe. Data integrity and the ability to roll back are prerequisites for sponsor approval to proceed to the next stage.

**Independent Test**: Execute the S5 rehearsal on a restored copy of production-like data on each supported engine (MySQL, PostgreSQL). Confirm that row counts and checksums match, the freeze window is under 15 minutes, and rollback by redeploying the previous Vets config against the old tables succeeds.

**Acceptance Scenarios**:

1. **Given** the S5 copy has completed, **When** the reconciliation tool runs, **Then** row counts and per-range checksums for vets, specialties, and vet_specialties are equal on source and target; any mismatch blocks the switch.
2. **Given** the S5 switch has been made, **When** a rollback is executed, **Then** the previous Vets config is redeployed against the old tables (which are intact by checksum), and GET /vets and GET /vets.html return correct responses within the agreed time (10 minutes or less).
3. **Given** S6 is proposed, **When** the pre-conditions are checked, **Then** S6 is blocked until a backup has been taken, a restore test has succeeded, and the sponsor has given explicit approval.
4. **Given** the S5 copy and reconciliation reports, **When** they are scanned for owner data, **Then** no owner name, address, telephone number, or any owner column appears in any report, dump, or log; only counts and hashes of owner tables are present.
5. **Given** the migration job runs DDL against a persistent store, **When** either service starts, **Then** neither service re-runs schema.sql or data.sql against that store (spring.sql.init.mode=never is in effect).

---

### User Story 5 — Operational Endpoints Are Accessible Only on the Management Port (Priority: P2)

A platform engineer configures liveness and readiness probes and a Prometheus scrape job for each service. Health, info, metrics, and prometheus endpoints are reachable on the dedicated management port. No operational path is reachable through the public-facing edge. The edge returns 404 for /actuator/**, /livez, and /readyz on the public host.

**Why this priority**: This is a required change (ADR-APP-9, SPEC-APP-12) that the sponsor must agree to. It is a prerequisite for the platform topology and for the KPI-2 test suite to pass. It also protects owner data from accidental exposure through operational endpoints.

**Independent Test**: Send requests to /actuator/health, /actuator/prometheus, /livez, and /readyz through the edge and confirm each returns 404 with no upstream request recorded. Then send the same requests directly to the management port of each service and confirm correct responses.

**Acceptance Scenarios**:

1. **Given** the split system is running, **When** a request is sent to /actuator/health through the public edge, **Then** the response is 404 and neither service's upstream request count increments.
2. **Given** the split system is running, **When** a request is sent to /actuator/prometheus on the Vets management port, **Then** the response contains http.server.requests and cache.gets with tag cache=vets.
3. **Given** the Vets service has received two calls to findAll, **When** cache.gets with tag cache=vets and result=hit is queried on the Vets management port, **Then** the value is greater than 0.
4. **Given** the effective management.endpoints.web.exposure.include is checked for both services, **When** the configuration is read, **Then** the value is exactly health,info,metrics,prometheus for each service.
5. **Given** a connection attempt is made to the management port from outside the monitoring network, **When** the network policy is in effect, **Then** the connection is refused.

---

### Edge Cases

- What happens when a user requests a vets page number below 1 or above the last page? The Vets service must redirect to /vets.html?page=1, as the monolith does; the redirect Location must use the public host or be relative and must never contain an internal service hostname or port.
- What happens when the Vets service is down and a user visits /vets.html? The edge must return a 503 with a Retry-After header and render the petclinic-ui error page layout; owner routes must continue to work without any failed requests.
- What happens when the Owners service is down and a user visits /vets.html? The Vets service must return 200 with the correct vets list; the edge must not propagate the Owners failure to the Vets response.
- What happens when a POST to an owner or pet form receives a connection reset after the request body has been sent? The edge must not retry the request; the upstream request count must be exactly 1; no duplicate owner, pet, or visit record must be created.
- What happens when a write to a vet table is detected after the S5 copy has completed? The S5 rollback must be declared invalid and the step must stop for re-planning; the switch must not proceed.
- What happens when the CI import check detects an import from the vet package into the owner package or vice versa? The build must fail immediately; the violation must be reported in the PR check output.
- What happens when two services start against the same H2 in-memory store? This configuration is not required or supported; each H2 instance holds only its own service's tables.
- What happens when a reconciliation report for owner tables is generated? The report must contain only counts and hashes; it must never contain owner names, addresses, telephone numbers, or any other owner field value.

---

## Requirements *(mandatory)*

### Functional Requirements

**Service Independence**

- **FR-001** (SPEC-APP-7, SPEC-PLAT-1): The repository MUST build into two independently versioned deployable artifacts — Vets and Owners — plus the petclinic-ui artifact. Neither service MUST depend on the other at build time or at run time. There MUST be no shared Java library between them.
- **FR-002** (SPEC-APP-7, SPEC-PLAT-2): The CI pipeline MUST enforce that an import from the vet package into the owner package, or the reverse, fails the build. A change confined to the vet package MUST trigger only the Vets deploy workflow; a change confined to the owner package MUST trigger only the Owners deploy workflow.
- **FR-003** (SPEC-PLAT-3, KPI-1): Every production deploy MUST create a deployment record naming the service, the git SHA, the environment, and the release identifier, so that KPI-1 (redeploys of the other service per release of one service, target 0) can be measured and reported.

**Vets Service**

- **FR-004** (SPEC-APP-1): The Vets service MUST serve GET /vets.html with pagination of 5 per page and MUST redirect any out-of-range page number (below 1 or above the last page) to /vets.html?page=1, as the monolith does today. The Vets artifact MUST contain no classes from the owner package.
- **FR-005** (SPEC-APP-2, SPEC-INT-2): The Vets service MUST serve GET /vets returning the same status, Content-Type, field names, and values as the monolith, in JSON or XML according to the Accept header. The XML marshalling dependency MUST be retained.
- **FR-006** (SPEC-APP-6): VetRepository.findAll MUST retain @Cacheable("vets") with cache statistics enabled, backed by CacheConfiguration, in the Vets service only. The Owners service MUST have no cache named "vets". No eviction behaviour MUST be added.

**Owners Service**

- **FR-007** (SPEC-APP-5): The Owners service MUST keep Owner, Pet, PetType, and Visit with the same JPA mappings (cascade ALL, EAGER), the same foreign keys, and the same URL routes as the monolith. Owner.java MUST move with no change to its content, including the telephone regex \d{10} and all @NotBlank rules.
- **FR-008** (SPEC-APP-5, SPEC-DATA-4): There MUST be no delete route and no delete repository method for Visit in the Owners service. Visit records MUST be append-only.
- **FR-009** (SPEC-DATA-1): The unique constraint on (owner_id, name) on the pets table MUST exist on H2, MySQL, and PostgreSQL after every stage of the migration.

**Edge Routing**

- **FR-010** (SPEC-APP-3, SPEC-INT-1): A single-origin edge router MUST route GET /vets and GET /vets.html to the Vets service and every other user-facing path to the Owners service, with the same paths, redirects, and headers as the monolith. The routing table MUST be a reviewed file in the repository.
- **FR-011** (SPEC-APP-3, SPEC-INT-8, ADR-APP-9): The edge MUST answer 404 for /actuator, /actuator/**, /livez, and /readyz on the public host and MUST NOT forward these requests to either service. This replaces the current include=* actuator exposure and is an accepted change requiring sponsor agreement.
- **FR-012** (SPEC-INT-6): The edge MUST apply a 1-second connect timeout, read timeouts of 10 seconds for Vets and static assets and 30 seconds for Owners, one jittered retry for GET and HEAD requests only, and a circuit breaker per upstream. A failure of one service MUST NOT affect the responses of the other.
- **FR-013** (SPEC-INT-7): The edge MUST NOT retry POST, PUT, or DELETE requests. An upstream failure on a write MUST return the edge error immediately with no second attempt.

**Shared Pages and Locale**

- **FR-014** (SPEC-APP-4, SPEC-INT-5): Both services MUST use CookieLocaleResolver with default English and the lang query parameter. A language selected on a page of one service MUST apply on the pages of the other service. Layout, welcome page, error pages, and all 11 message bundles MUST come from a pinned petclinic-ui artifact.
- **FR-015** (SPEC-APP-11, SPEC-INT-9): The error pages and the CrashController /oups route MUST look and behave as in the monolith from both services. /oups MUST be served by the Owners service. The Vets service MUST use the same error.html from petclinic-ui for its own errors.

**Operational Endpoints**

- **FR-016** (SPEC-APP-12, SPEC-INT-8): Each service MUST expose only health, info, metrics, and prometheus through Spring Boot Actuator, on a dedicated management port. The effective management.endpoints.web.exposure.include MUST be exactly health,info,metrics,prometheus for both services. Liveness and readiness probes MUST use the health groups on that management port.
- **FR-017** (SPEC-PLAT-4, SPEC-INT-8): The management port of each service MUST NOT be routed by the edge. Network policy MUST limit the management port to the monitoring and orchestration network. A connection to the management port from outside that network MUST be refused.

**Data Ownership and Migration**

- **FR-018** (SPEC-DATA-1, SPEC-APP-8): Each database table MUST have exactly one owning service. Vets owns vets, specialties, and vet_specialties. Owners owns owners, pets, visits, and types. There MUST be no foreign key, view, or cross-service query between the two sets.
- **FR-019** (SPEC-DATA-3, SPEC-APP-8): In environments with a persistent MySQL or PostgreSQL store, DDL MUST be applied only by the migration job. Both services MUST start with spring.sql.init.mode=never against a populated store. In the H2 profile each service MUST initialise only its own table subset.
- **FR-020** (SPEC-DATA-5, SPEC-APP-8): The Vets database role MUST be denied SELECT on owners, pets, visits, and types, and denied INSERT, UPDATE, and DELETE on the vet tables (which have no application writer). After S5, the Owners database role MUST be denied any access to the vet tables.
- **FR-021** (SPEC-DATA-6, SPEC-DATA-7): Before the S5 switch, the migration tool MUST prove that row counts and per-range checksums for vets, specialties, and vet_specialties are equal on source and target. A mismatch MUST fail the job and block the switch. The reconciliation report MUST be stored as a CI artifact.
- **FR-022** (SPEC-DATA-9): Owner personal data (name, address, telephone) MUST NOT be copied, exported, moved, or transformed by any data step. No dump, copy, log, test fixture, or reconciliation report on the Vets side MUST contain an owner column or row value. Reconciliation reports for owner tables MUST contain only counts and hashes.
- **FR-023** (SPEC-DATA-8): Each stage S2 through S6 MUST have a rehearsed rollback. S6 MUST be blocked until a backup has been taken, a restore test has succeeded, and the sponsor has given explicit approval. The freeze window for S5 MUST be 15 minutes or less.

**Test Suite**

- **FR-024** (SPEC-APP-9, SPEC-DATA-10): The existing tests MUST be redistributed by service with no edits to expected results. The set of test methods and their assertions before and after the split MUST be identical. The failing-test count MUST be 0 at every stage and at the final cutover build, on H2 and on the MySQL and PostgreSQL integration variants.
- **FR-025** (SPEC-INT-11): Before the S3 route flip, live GET /vets and GET /vets.html traffic MUST be mirrored to the dark Vets service and each response compared with the monolith's. The diff count over the agreed S2 window MUST be 0 for status, Content-Type, and body. The mirror MUST send no session or locale cookie.

### Key Entities

- **Vets Service boundary**: Vet, Specialty, VetController, VetRepository — the vet package in its entirety. This service owns the vets, specialties, and vet_specialties tables and the "vets" cache. It has no application writer; vet data is read-only from the application's perspective.
- **Owners Service boundary**: Owner, Pet, PetType, Visit, and their controllers and repositories — the owner package in its entirety. This service owns the owners, pets, visits, and types tables. It is the sole writer of owner, pet, and visit data.
- **petclinic-ui artifact**: A pinned, independently versioned artifact containing layout.html, error.html, the welcome page, static assets (/resources/**, /webjars/**), and all 11 i18n message bundles. Both services depend on the same pinned version of this artifact; neither service owns it exclusively.
- **Edge router**: The single-origin component that routes user-facing requests to the correct service, enforces timeouts and circuit breaking, and answers 404 for all operational paths on the public host. It holds the authoritative routing table as a reviewed file in the repository.
- **Migration job**: The component responsible for applying DDL and copying vet data during the staged migration. It is the only component permitted to write the vet tables during the S5 freeze window. It is separate from both services and runs independently.
- **Deployment record**: A GitHub Deployment object created for every production deploy, naming the service, git SHA, environment, and release identifier. It is the data source for KPI-1 measurement.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **KPI-1**: The Vets service deploys without redeploying the Owners service, and the reverse. Measured as: the count of deployments of the other service per release of one service. Target: 0. Verified by the scheduled KPI-1 report job reading GitHub Deployment records.
- **KPI-2**: No change to what a user sees. Measured as: the count of failing tests in the existing UI and controller suite (OwnerControllerTests, PetControllerTests, VisitControllerTests, VetControllerTests, CrashControllerTests, ClinicServiceTests, PetClinicIntegrationTests) with no edits to expected results. Target: 0 failing tests, on H2 at every stage and on MySQL and PostgreSQL integration variants before each release.
- **SC-001**: The S5 freeze window — the period during which manual DML on vet tables is suspended — is 15 minutes or less. Verified by the rehearsal report for each supported engine (MySQL, PostgreSQL).
- **SC-002**: The S3 route flip and its rollback each complete within the agreed platform time (assumed 10 minutes or less). Verified by the rehearsal report. Owner routes see zero failed requests during the flip and the revert.
- **SC-003**: The golden-master diff for GET /vets (JSON and XML) and GET /vets.html (all pages, page size 5) between the monolith and the split system is empty (byte-equal for the same data). Verified by the S2 shadow comparison report stored with the S3 approval.
- **SC-004**: The Vets artifact contains no classes from the owner package, and the Owners artifact contains no classes from the vet package. Verified by the CI import check on every pull request.
- **SC-005**: Owner personal data (name, address, telephone) does not appear in any Vets-side dump, copy, log, test fixture, or reconciliation report. Verified by automated scan of all S5 artefacts before the switch is approved.
- **SC-006**: A language selection made on a page of one service applies on the pages of the other service, with no additional user action. Verified by the cross-service locale acceptance scenario in SPEC-APP-4 and SPEC-INT-5.

---

## Assumptions

- The migration proceeds through stages S2, S3, S4, S5, and S6 as defined in the architecture design. The exact stage definitions and their sequencing are taken from ADR-APP-5 and ADR-DATA-1 as described in the context; this spec does not redefine them.
- The agreed platform time for a route flip and rollback is 10 minutes or less. If the platform team sets a different target, SC-002 and the accepted-when criteria for SPEC-APP-10 and SPEC-INT-12 must be updated before S3 is rehearsed.
- The removal of the current include=* actuator exposure on the public host is an accepted change, but it requires explicit sponsor agreement before S3. This spec records it as a requirement (FR-011) and a prerequisite for the S3 approval gate.
- The S6 drop of the old vet tables requires a separate explicit sponsor approval in addition to the technical pre-conditions (backup taken, restore test succeeded). This approval is not assumed to be granted automatically at any stage.
- The list of other readers of vet or owner data (reports, exports, backups, BI tools) is to be compiled at S0 as required by SPEC-DATA-5. This spec assumes that list does not exist yet and that compiling it is a task for the migration team, not a prerequisite for writing this specification.
- The petclinic-ui artifact versioning and pinning mechanism is to be established as part of this feature. The exact artifact coordinates and repository location are not settled by the inputs to this spec and are left to the implementation plan.
- The H2 profile is used for development and CI testing only. Running both services against a single shared H2 instance is not a supported or required configuration; each service uses its own H2 instance holding only its own tables.
- GitHub Actions is the CI platform. The deploy-vets and deploy-owners workflow names used in this spec are illustrative; the exact workflow file names are to be confirmed during implementation.
- The existing open GitHub issues (#2, #3, #5) are explicitly out of scope and MUST NOT be addressed as part of this feature, even if the migration work touches related code.
- The constitution's Modular Monolith Architecture principle (Section I) describes the pre-split state. After this feature is complete, the architecture transitions to two independently deployable services. The constitution will require amendment to reflect the new architecture once the migration is ratified by the maintainer.
- Java 17 and Spring Boot remain unchanged throughout the migration. No upgrade or downgrade of either is in scope.
- There is no hard deadline. Stages may be paused between steps without time pressure, subject to sponsor review.
