---
description: "Task list template for feature implementation"
---

# Tasks: Split PetClinic into Microservices

**Input**: Design documents from `/specs/009-split-petclinic-into-microserv-bbbd6b99/`

**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: Not explicitly requested in the feature specification. Test redistribution tasks are included because FR-024 and KPI-2 require the existing test suite to be moved verbatim — these are migration tasks, not new test authoring tasks.

**Organization**: Tasks are grouped by user story and wave to enable independent implementation and testing of each story. Wave numbers from the work plan are noted in comments for traceability.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US5)
- Exact file paths are given for every task; NEEDS CLARIFICATION items from research.md are flagged inline

---

## Phase 1: Setup — Blocking Decisions and KPI Baselines (Wave 0)

**Purpose**: Record the decisions that gate all subsequent work. No code moves until these are done. Corresponds to W0 items E1-S1, E1-S2, E1-S3, E4-S1, E2-S4, E5-S12.

- [ ] T001 Record the baseline spec set decision (DEF-2): confirm SPEC-APP-5 traces only to behaviour present at the split commit; mark 005-007 email and duplicate-date requirements out of scope or as pending PRs; record Java 17 decision; record merge/rebase order for open PRs #4 and #1 — document in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E1-S1-baseline.md`
- [ ] T002 Record the petclinic-ui compatibility rule decision (DEF-1): choose N/N-1 window or coordinated UI release excluded from KPI-1 count; rewrite parity acceptance criteria for SPEC-APP-4, SPEC-PLAT-9, SPEC-INT-4 to match — document in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E1-S2-ui-rule.md` — NEEDS CLARIFICATION: artifact coordinates (groupId, artifactId, registry URL) per research item 4a
- [ ] T003 Record the accepted-changes table (DEF-6): sponsor explicitly agrees to (a) actuator exposure change from `include=*` to `health,info,metrics,prometheus` on management port only, (b) locale cookie attributes, (c) edge 503 when Vets is down; confirm KPI-2 definition; verify no existing test or document relies on public `/actuator/**`, `/livez`, or `/readyz` — document in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E1-S3-accepted-changes.md`
- [ ] T004 Capture KPI baselines (DEF-9): name the GitHub Deployments API as the KPI-1 source system; record the KPI-1 counting rule (decide whether config-only redeploys, petclinic-ui bumps, and edge-only redeploys count — NEEDS CLARIFICATION per research item 7a); record the baseline KPI-1 value (0 before split); run the full existing test suite on `main` and record the KPI-2 failing-test count — document in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E4-S1-kpi-baselines.md`
- [ ] T005 Inventory other readers of vet and owner data (reports, exports, BI tools, backups) and map data lineage; record any reader not yet mapped as an open issue — document in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E2-S4-data-lineage.md`
- [ ] T006 Record G1 approver acceptance or rejection of residual risk THR-14 (no authentication, authorisation, or CSRF on owner routes) and all other residual risks — document in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E5-S12-residual-risk.md`

**Checkpoint**: All six decision records exist and are approved. No code task may begin until T001–T006 are complete.

---

## Phase 2: Foundational — Multi-Module Build and Golden Masters (Wave 1 core)

**Purpose**: Restructure the repository as a Maven multi-module project, copy model classes verbatim, establish the CI import check, record golden masters, and confirm KPI-2 is green — all while production still runs the unchanged monolith. Corresponds to W1 items E1-S4, E1-S8, E1-S11, E2-S1, E2-S2, E3-S1, E4-S2, E4-S3, E4-S4, E4-S9, E5-S4, E5-S10.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Root POM and Module Scaffolding

- [ ] T007 Create root `pom.xml` as a Maven multi-module aggregator with modules `vets`, `owners`, `petclinic-ui`, `migration`; set `<packaging>pom</packaging>`; carry forward the existing `<parent>` Spring Boot BOM; retain `mvnw` and `mvnw.cmd` at repository root — file: `pom.xml`
- [ ] T008 [P] Create `vets/pom.xml` as a Spring Boot module: inherit root POM; declare dependencies for Spring MVC, Thymeleaf, Spring Data JPA, Spring Boot Actuator, Micrometer, JCache, Jackson, `jackson-dataformat-xml` (FR-005), Jakarta Bean Validation; set `<artifactId>vets</artifactId>` — file: `vets/pom.xml`
- [ ] T009 [P] Create `owners/pom.xml` as a Spring Boot module: inherit root POM; declare dependencies for Spring MVC, Thymeleaf, Spring Data JPA, Spring Boot Actuator, Micrometer, Jakarta Bean Validation; set `<artifactId>owners</artifactId>`; explicitly omit `jackson-dataformat-xml` and JCache — file: `owners/pom.xml`
- [ ] T010 [P] Create `petclinic-ui/pom.xml` as a resource-only module: inherit root POM; set `<artifactId>petclinic-ui</artifactId>`; configure Maven resources plugin to package `templates/`, `static/`, and `messages/` into the artifact JAR — file: `petclinic-ui/pom.xml`
- [ ] T011 [P] Create `migration/pom.xml` as a non-deployable module: inherit root POM; set `<artifactId>migration</artifactId>`; declare the chosen migration tool dependency — NEEDS CLARIFICATION: tool (Flyway, Liquibase, or custom SQL) per research item 8a — file: `migration/pom.xml`

### Shared Infrastructure Classes (Copied Verbatim into Both Modules)

- [ ] T012 Read the monolith source to identify the exact set of shared infrastructure classes in `src/main/java/org/springframework/samples/petclinic/model/` and `system/` that are used by both the vet and owner packages (candidates: `BaseEntity`, `NamedEntity`, `Person`) — NEEDS CLARIFICATION per data-model.md; record findings in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/base-entity-set.md`
- [ ] T013 Copy `BaseEntity` (and any other shared infrastructure classes identified in T012) verbatim into `vets/src/main/java/org/springframework/samples/petclinic/model/` — no content change; FR-001 prohibits a shared module
- [ ] T014 [P] Copy `BaseEntity` (and any other shared infrastructure classes identified in T012) verbatim into `owners/src/main/java/org/springframework/samples/petclinic/model/` — no content change

### Vets Module — Source Classes (Verbatim Copy)

- [ ] T015 Copy `Vet.java` verbatim from `src/main/java/org/springframework/samples/petclinic/vet/Vet.java` to `vets/src/main/java/org/springframework/samples/petclinic/vet/Vet.java` — no content change; fields: `id` (INT PK), `firstName` (VARCHAR 30, `@NotBlank`), `lastName` (VARCHAR 30, `@NotBlank`), `specialties` (`@ManyToMany EAGER` via `vet_specialties`)
- [ ] T016 [P] Copy `Specialty.java` verbatim to `vets/src/main/java/org/springframework/samples/petclinic/vet/Specialty.java` — no content change; fields: `id` (INT PK), `name` (VARCHAR 80, `@NotBlank`)
- [ ] T017 [P] Copy `Vets.java` verbatim to `vets/src/main/java/org/springframework/samples/petclinic/vet/Vets.java` — no content change; retains `@XmlRootElement` and `@XmlElement` annotations required for XML marshalling (FR-005)
- [ ] T018 [P] Copy `VetRepository.java` verbatim to `vets/src/main/java/org/springframework/samples/petclinic/vet/VetRepository.java` — no content change; retains `@Cacheable("vets")` on `findAll()`
- [ ] T019 [P] Copy `VetController.java` verbatim to `vets/src/main/java/org/springframework/samples/petclinic/vet/VetController.java` — no content change; routes: GET `/vets.html` (pagination 5/page, out-of-range redirect to `/vets.html?page=1`), GET `/vets` (JSON/XML)
- [ ] T020 [P] Copy `CacheConfiguration.java` verbatim to `vets/src/main/java/org/springframework/samples/petclinic/system/CacheConfiguration.java` — no content change; backs `@Cacheable("vets")` with JCache and statistics enabled; no eviction (FR-006)
- [ ] T021 [P] Copy `WebConfiguration.java` verbatim to `vets/src/main/java/org/springframework/samples/petclinic/system/WebConfiguration.java` — no content change; provides `CookieLocaleResolver` with default English and `lang` query parameter (FR-014)
- [ ] T022 Create `VetsApplication.java` in `vets/src/main/java/org/springframework/samples/petclinic/VetsApplication.java` — standard `@SpringBootApplication` entry point; component scan scoped to `org.springframework.samples.petclinic`

### Vets Module — Resources

- [ ] T023 Create `vets/src/main/resources/application.properties` with: `management.server.port=<management-port>` (NEEDS CLARIFICATION per research item 12a), `management.endpoints.web.exposure.include=health,info,metrics,prometheus`, `management.endpoint.health.show-details=never`, `spring.sql.init.mode=never` (FR-019)
- [ ] T024 [P] Create `vets/src/main/resources/application-h2.properties` with: `spring.sql.init.mode=always`; datasource pointing to a Vets-only H2 in-memory instance; `spring.jpa.hibernate.ddl-auto=none`
- [ ] T025 [P] Create `vets/src/main/resources/application-mysql.properties` with: datasource for MySQL; `spring.sql.init.mode=never`; Vets runtime role credentials placeholder
- [ ] T026 [P] Create `vets/src/main/resources/application-postgres.properties` with: datasource for PostgreSQL; `spring.sql.init.mode=never`; Vets runtime role credentials placeholder
- [ ] T027 [P] Create `vets/src/main/resources/db/h2/schema.sql` containing only the Vets table subset extracted verbatim from the monolith's `schema.sql`: `vets`, `specialties`, `vet_specialties` — no owner tables; UNIQUE constraint on `vet_specialties(vet_id, specialty_id)` PK preserved
- [ ] T028 [P] Create `vets/src/main/resources/db/h2/data.sql` containing only the vet and specialty seed rows extracted verbatim from the monolith's `data.sql` — no owner seed rows
- [ ] T029 [P] Create `vets/src/main/resources/db/mysql/schema.sql` containing only the Vets table subset for MySQL — NEEDS CLARIFICATION: real MySQL script content per research item 8a; placeholder until E2-S3 reads the actual scripts
- [ ] T030 [P] Create `vets/src/main/resources/db/postgres/schema.sql` containing only the Vets table subset for PostgreSQL — NEEDS CLARIFICATION: real PostgreSQL script content per research item 8a

### Owners Module — Source Classes (Verbatim Copy)

- [ ] T031 Copy `Owner.java` verbatim from `src/main/java/org/springframework/samples/petclinic/owner/Owner.java` to `owners/src/main/java/org/springframework/samples/petclinic/owner/Owner.java` — no content change (FR-007 explicit); fields: `id` (INT PK), `firstName` (VARCHAR 30, `@NotBlank`), `lastName` (VARCHAR 30, `@NotBlank`), `address` (VARCHAR 255, `@NotBlank`), `city` (VARCHAR 80, `@NotBlank`), `telephone` (VARCHAR 20, `@NotBlank`, `@Pattern(regexp="\\d{10}")`), `pets` (`@OneToMany cascade=ALL fetch=EAGER`)
- [ ] T032 [P] Copy `Pet.java` verbatim to `owners/src/main/java/org/springframework/samples/petclinic/owner/Pet.java` — no content change; fields: `id` (INT PK), `name` (VARCHAR 30, not blank), `birthDate` (DATE, nullable), `type` (`@ManyToOne EAGER`, not null), `owner` (`@ManyToOne`, not null), `visits` (`@OneToMany cascade=ALL fetch=EAGER`)
- [ ] T033 [P] Copy `PetType.java` verbatim to `owners/src/main/java/org/springframework/samples/petclinic/owner/PetType.java` — no content change; fields: `id` (INT PK), `name` (VARCHAR 80, `@NotBlank`)
- [ ] T034 [P] Copy `Visit.java` verbatim to `owners/src/main/java/org/springframework/samples/petclinic/owner/Visit.java` — no content change; fields: `id` (INT PK), `date` (DATE NOT NULL, defaults to today), `description` (VARCHAR 255, `@NotBlank`), `pet` (`@ManyToOne`, not null); append-only (FR-008)
- [ ] T035 [P] Copy `OwnerRepository.java` verbatim to `owners/src/main/java/org/springframework/samples/petclinic/owner/OwnerRepository.java` — no content change; methods: `findByLastName`, `findById`, `save`; no delete method
- [ ] T036 [P] Copy `PetRepository.java` verbatim to `owners/src/main/java/org/springframework/samples/petclinic/owner/PetRepository.java` — no content change; methods: `findPetTypes`, `findById`, `save`; no delete method
- [ ] T037 [P] Copy `VisitRepository.java` verbatim to `owners/src/main/java/org/springframework/samples/petclinic/owner/VisitRepository.java` — no content change; method: `save` only; explicitly no `delete`, `deleteById`, or any removal method (FR-008 hard constraint)
- [ ] T038 [P] Copy `PetValidator.java` verbatim to `owners/src/main/java/org/springframework/samples/petclinic/owner/PetValidator.java` — no content change
- [ ] T039 [P] Copy all owner controllers verbatim: `OwnerController.java`, `PetController.java`, `VisitController.java` to `owners/src/main/java/org/springframework/samples/petclinic/owner/` — no content change; routes preserved per owners-http.md contract
- [ ] T040 [P] Copy `WebConfiguration.java` verbatim to `owners/src/main/java/org/springframework/samples/petclinic/system/WebConfiguration.java` — no content change; same `CookieLocaleResolver` configuration as Vets copy (FR-014)
- [ ] T041 [P] Copy `CrashController.java` verbatim to `owners/src/main/java/org/springframework/samples/petclinic/system/CrashController.java` — no content change; serves `/oups` from Owners service only (FR-015)
- [ ] T042 Create `OwnersApplication.java` in `owners/src/main/java/org/springframework/samples/petclinic/OwnersApplication.java` — standard `@SpringBootApplication` entry point

### Owners Module — Resources

- [ ] T043 Create `owners/src/main/resources/application.properties` with: `management.server.port=<management-port>` (NEEDS CLARIFICATION per research item 12a), `management.endpoints.web.exposure.include=health,info,metrics,prometheus`, `management.endpoint.health.show-details=never`, `spring.sql.init.mode=never` (FR-019)
- [ ] T044 [P] Create `owners/src/main/resources/application-h2.properties` with: `spring.sql.init.mode=always`; datasource pointing to an Owners-only H2 in-memory instance (separate from Vets H2 instance per spec Assumptions)
- [ ] T045 [P] Create `owners/src/main/resources/application-mysql.properties` with: datasource for MySQL; `spring.sql.init.mode=never`; Owners runtime role credentials placeholder
- [ ] T046 [P] Create `owners/src/main/resources/application-postgres.properties` with: datasource for PostgreSQL; `spring.sql.init.mode=never`; Owners runtime role credentials placeholder
- [ ] T047 [P] Create `owners/src/main/resources/db/h2/schema.sql` containing only the Owners table subset extracted verbatim from the monolith's `schema.sql`: `owners`, `pets`, `visits`, `types`; include `UNIQUE (owner_id, name)` on `pets` (FR-009); no vet tables
- [ ] T048 [P] Create `owners/src/main/resources/db/h2/data.sql` containing only the owner, pet, visit, and type seed rows extracted verbatim from the monolith's `data.sql` — no vet seed rows
- [ ] T049 [P] Create `owners/src/main/resources/db/mysql/schema.sql` containing only the Owners table subset for MySQL — NEEDS CLARIFICATION: real MySQL script content per research item 8a
- [ ] T050 [P] Create `owners/src/main/resources/db/postgres/schema.sql` containing only the Owners table subset for PostgreSQL — NEEDS CLARIFICATION: real PostgreSQL script content per research item 8a

### petclinic-ui Module — Shared UI Artifact

- [ ] T051 Move `layout.html`, `error.html`, `welcome.html` from `src/main/resources/templates/` to `petclinic-ui/src/main/resources/templates/` — no content change
- [ ] T052 [P] Move all static assets from `src/main/resources/static/resources/` to `petclinic-ui/src/main/resources/static/resources/` — no content change; preserves `/resources/**` paths
- [ ] T053 [P] Move all 11 i18n message bundle files (`messages_*.properties`) from `src/main/resources/` to `petclinic-ui/src/main/resources/messages/` — no content change (FR-014)
- [ ] T054 Configure both `vets/pom.xml` and `owners/pom.xml` to declare a dependency on the pinned petclinic-ui artifact version; add checksum verification to the dependency declaration — NEEDS CLARIFICATION: artifact coordinates and registry URL per research item 4a; file: `vets/pom.xml`, `owners/pom.xml`
- [ ] T055 Create `.github/workflows/deploy-petclinic-ui.yml`: publish petclinic-ui artifact to the chosen registry; run `layout.html` and `error.html` parity test per the rule chosen in T002 before publishing; publishing must not deploy either service — file: `.github/workflows/deploy-petclinic-ui.yml`

### Native Image Runtime Hints

- [ ] T056 Read `src/main/java/org/springframework/samples/petclinic/PetClinicRuntimeHints.java` to determine which classes it covers; if hints are for vet-side classes only, copy verbatim to `vets/`; if mixed, copy verbatim into both modules — NEEDS CLARIFICATION per research item 19a; files: `vets/src/main/java/org/springframework/samples/petclinic/VetsRuntimeHints.java` and/or `owners/src/main/java/org/springframework/samples/petclinic/OwnersRuntimeHints.java`

### Schema Split and Data Ownership Scripts

- [ ] T057 Split the monolith's `schema.sql` per engine (H2, MySQL, PostgreSQL) into vet and owner subsets by verbatim extraction; verify that the union of the two subsets equals the original script per engine (diff ignoring statement order) — produces files already listed in T027–T030 and T047–T050; record the diff result in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E2-S1-schema-split.md`
- [ ] T058 [P] Create data ownership and integrity rule scripts for H2, MySQL, and PostgreSQL that verify: (a) no FK between the vet table set and the owner table set, (b) `UNIQUE (owner_id, name)` exists on `pets` (FR-009), (c) no vet column appears in owner tables and vice versa; record the S0 owner-table checksum baseline — files: `migration/src/main/resources/db/verify/ownership-rules-h2.sql`, `ownership-rules-mysql.sql`, `ownership-rules-postgres.sql`

### Test Redistribution (KPI-2 — Verbatim Move, No Assertion Changes)

- [ ] T059 Read `src/test/java/org/springframework/samples/petclinic/service/ClinicServiceTests.java` to determine the exact split of methods between vet-side and owner-side data — NEEDS CLARIFICATION per research item 18a; record findings in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E1-S11-clinicservice-split.md`
- [ ] T060 Copy `VetControllerTests.java` verbatim to `vets/src/test/java/org/springframework/samples/petclinic/vet/VetControllerTests.java` — no assertion changes (FR-024, KPI-2)
- [ ] T061 [P] Copy the vet-side methods of `ClinicServiceTests.java` verbatim to `vets/src/test/java/org/springframework/samples/petclinic/service/ClinicServiceTests.java` — only vet-repository-exercising methods; no assertion changes
- [ ] T062 [P] Copy `OwnerControllerTests.java` verbatim to `owners/src/test/java/org/springframework/samples/petclinic/owner/OwnerControllerTests.java` — no assertion changes
- [ ] T063 [P] Copy `PetControllerTests.java` verbatim to `owners/src/test/java/org/springframework/samples/petclinic/owner/PetControllerTests.java` — no assertion changes
- [ ] T064 [P] Copy `VisitControllerTests.java` verbatim to `owners/src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java` — no assertion changes
- [ ] T065 [P] Copy `CrashControllerTests.java` verbatim to `owners/src/test/java/org/springframework/samples/petclinic/system/CrashControllerTests.java` — no assertion changes
- [ ] T066 [P] Copy the owner-side methods of `ClinicServiceTests.java` verbatim to `owners/src/test/java/org/springframework/samples/petclinic/service/ClinicServiceTests.java` — only owner-repository-exercising methods; no assertion changes
- [ ] T067 [P] Copy `PetClinicIntegrationTests.java` verbatim to `owners/src/test/java/org/springframework/samples/petclinic/PetClinicIntegrationTests.java` — no assertion changes
- [ ] T068 [P] Copy `PetClinicConcurrencyTests.java` verbatim to `owners/src/test/java/org/springframework/samples/petclinic/PetClinicConcurrencyTests.java` — no assertion changes
- [ ] T069 [P] Create `vets/src/test/java/org/springframework/samples/petclinic/MySqlIntegrationTests.java` scoped to Vets tables only (`vets`, `specialties`, `vet_specialties`) using Testcontainers; copy verbatim from monolith's MySQL integration test, retaining only vet-table assertions — no assertion changes
- [ ] T070 [P] Create `vets/src/test/java/org/springframework/samples/petclinic/PostgresIntegrationTests.java` scoped to Vets tables only using Testcontainers — no assertion changes
- [ ] T071 [P] Create `owners/src/test/java/org/springframework/samples/petclinic/MySqlIntegrationTests.java` scoped to Owners tables only (`owners`, `pets`, `visits`, `types`) using Testcontainers — no assertion changes
- [ ] T072 [P] Create `owners/src/test/java/org/springframework/samples/petclinic/PostgresIntegrationTests.java` scoped to Owners tables only using Testcontainers — no assertion changes
- [ ] T073 [P] Create `I18nPropertiesSyncTest.java` in both `vets/src/test/` and `owners/src/test/` that verifies all 11 message bundle keys are present in the pinned petclinic-ui artifact — files: `vets/src/test/java/org/springframework/samples/petclinic/I18nPropertiesSyncTest.java`, `owners/src/test/java/org/springframework/samples/petclinic/I18nPropertiesSyncTest.java`

### CI Import Boundary Check

- [ ] T074 Add an ArchUnit import-check test that fails the build if any class in the `vet` package imports a class from the `owner` package or vice versa — NEEDS CLARIFICATION: exact module location per research item 2a; place in a dedicated `build-checks` module or per-service test class pending that decision; file: `vets/src/test/java/org/springframework/samples/petclinic/vet/VetPackageBoundaryTest.java` and `owners/src/test/java/org/springframework/samples/petclinic/owner/OwnerPackageBoundaryTest.java` (per-service option until 2a is resolved)

### CI Pipelines and Build Verification

- [ ] T075 Create `.github/workflows/pr-verify.yml`: run the full KPI-2 suite (`VetControllerTests`, `OwnerControllerTests`, `PetControllerTests`, `VisitControllerTests`, `CrashControllerTests`, `ClinicServiceTests` in both modules, `PetClinicIntegrationTests`), the ArchUnit import check, an actuator exposure config test (asserts effective `management.endpoints.web.exposure.include` equals exactly `health,info,metrics,prometheus`), and Sonar — file: `.github/workflows/pr-verify.yml`
- [ ] T076 Create `.github/workflows/deploy-vets.yml`: path-filtered on `vets/**`; builds only the Vets module (`./mvnw -pl vets -am verify`); produces OCI image with SBOM; creates a GitHub Deployment record naming service=`vets`, git SHA, environment, and release identifier (FR-003); does not trigger Owners deploy — NEEDS CLARIFICATION: exact path filter patterns per research item 6a — file: `.github/workflows/deploy-vets.yml`
- [ ] T077 [P] Create `.github/workflows/deploy-owners.yml`: path-filtered on `owners/**`; builds only the Owners module; produces OCI image with SBOM; creates a GitHub Deployment record naming service=`owners`; does not trigger Vets deploy — NEEDS CLARIFICATION: exact path filter patterns per research item 6a — file: `.github/workflows/deploy-owners.yml`
- [ ] T078 [P] Create `.github/workflows/deploy-edge.yml`: triggered on changes to `edge/`; deploys edge configuration change — file: `.github/workflows/deploy-edge.yml`
- [ ] T079 [P] Create `.github/workflows/kpi-1-report.yml`: scheduled job; reads GitHub Deployment records via the GitHub Deployments API; counts deployments of the other service per release of one service; outputs the KPI-1 report; target count is 0 (FR-003, KPI-1) — file: `.github/workflows/kpi-1-report.yml`
- [ ] T080 Verify that `./mvnw -pl vets -am verify` builds without the `owners` module and `./mvnw -pl owners -am verify` builds without the `vets` module; record the result in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E4-S2-build-isolation.md`

### Per-Service Secrets and Deploy Identities

- [ ] T081 Configure per-service deploy identities in GitHub Actions: the Vets pipeline credential must not be able to deploy Owners and vice versa; each deploy must be logged with service, commit, actor, and timestamp — file: `.github/workflows/deploy-vets.yml`, `.github/workflows/deploy-owners.yml` (update T076, T077); run a secret scan to confirm no credential is embedded in any file

### petclinic-ui Supply Chain Controls

- [ ] T082 Add a CI check to `pr-verify.yml` that fails the build if the petclinic-ui dependency in either service POM is unpinned or if the declared SHA-256 checksum does not match the resolved artifact (FR-014, SC-004) — file: `.github/workflows/pr-verify.yml` (update T075)
- [ ] T083 [P] Add a CI check to `pr-verify.yml` that fails if any Thymeleaf template uses `th:utext` on request-derived data or contains an inline script sourced from request data — file: `.github/workflows/pr-verify.yml` (update T075)

### Golden Masters

- [ ] T084 Record golden masters from the running monolith for: GET `/vets` (JSON, XML, no-Accept, `*/*`), GET `/vets.html` (all pages, page size 5, out-of-range page), and all owner/pet/visit flows listed in routing-table.md; store fixtures in `specs/009-split-petclinic-into-microserv-bbbd6b99/golden-masters/` — these are the reference for SC-003 and the S2 shadow comparison (FR-025)
- [ ] T085 [P] Build contract tests that replay the golden master fixtures against the monolith and assert an empty diff for status, `Content-Type`, and body; confirm all pass against the monolith before any routing change — file: `specs/009-split-petclinic-into-microserv-bbbd6b99/golden-masters/contract-tests/`

**Checkpoint**: Multi-module build is green, KPI-2 failing-test count is 0, golden masters are recorded, import check is enforced, and production still runs the unchanged monolith.

---

## Phase 3: User Story 1 — Vets Team Releases Without Waiting for Owners Team (Priority: P1)

**Goal**: A change confined to the vet package triggers only the Vets service deploy workflow; the Owners service is not rebuilt, retested, or redeployed. GET `/vets.html` and GET `/vets` continue to work throughout.

**Independent Test**: Merge a commit that changes only a file in `vets/`. Confirm that only `deploy-vets.yml` runs, that `deploy-owners.yml` does not run, and that GET `/vets.html` and GET `/vets` return correct responses throughout. Verify the KPI-1 report shows 0 Owners deployments for that release window.

**Corresponds to**: W1 items E4-S2, E4-S3, E4-S4; W2 items E1-S5, E1-S6, E1-S10, E3-S8; W3 items E1-S13, E1-S14, E3-S9.

### Vets Service — Application Correctness

- [ ] T086 [US1] Verify `VetController.java` in `vets/` serves GET `/vets.html` with page size 5 and redirects any out-of-range page number (below 1 or above the last page) to `/vets.html?page=1`; the `Location` header must use a relative path or the public host and must never contain an internal Kubernetes service hostname or port (FR-004) — file: `vets/src/main/java/org/springframework/samples/petclinic/vet/VetController.java`
- [ ] T087 [US1] Verify `VetController.java` in `vets/` serves GET `/vets` returning JSON when `Accept: application/json` and XML when `Accept: application/xml`; field names, values, and `nrOfSpecialties` must be byte-equal to the monolith golden master for the same data (SC-003, FR-005) — file: `vets/src/main/java/org/springframework/samples/petclinic/vet/VetController.java`
- [ ] T088 [US1] Verify `VetRepository.java` in `vets/` retains `@Cacheable("vets")` on `findAll()`; confirm `CacheConfiguration.java` is present in `vets/system/` with statistics enabled and no eviction behaviour added (FR-006) — files: `vets/src/main/java/org/springframework/samples/petclinic/vet/VetRepository.java`, `vets/src/main/java/org/springframework/samples/petclinic/system/CacheConfiguration.java`
- [ ] T089 [US1] Confirm the Vets artifact contains no classes from the `owner` package by running the ArchUnit import-check test (T074) and the CI import check (T075) against the Vets module; record the result as evidence for SC-004 — file: `vets/src/test/java/org/springframework/samples/petclinic/vet/VetPackageBoundaryTest.java`

### Vets Service — Actuator and Management Port

- [ ] T090 [US1] Set `management.server.port=<management-port>` (NEEDS CLARIFICATION per research item 12a) and `management.endpoints.web.exposure.include=health,info,metrics,prometheus` in `vets/src/main/resources/application.properties`; add a configuration test that asserts the effective exposure include equals exactly `health,info,metrics,prometheus` — file: `vets/src/main/resources/application.properties`
- [ ] T091 [US1] Verify that after two calls to `VetRepository.findAll`, the metric `cache.gets` with tag `cache=vets` and `result=hit` is greater than 0 on the Vets management port (FR-006, User Story 5 scenario 3); add this assertion to `VetControllerTests.java` or a dedicated cache test — file: `vets/src/test/java/org/springframework/samples/petclinic/vet/VetControllerTests.java`

### CI Path-Filter Verification

- [ ] T092 [US1] Verify that `deploy-vets.yml` path filter is set to `vets/**` and that a commit touching only `vets/` triggers `deploy-vets.yml` and does not trigger `deploy-owners.yml`; verify the reverse for `owners/**` — NEEDS CLARIFICATION: exact path filter patterns per research item 6a — files: `.github/workflows/deploy-vets.yml`, `.github/workflows/deploy-owners.yml`
- [ ] T093 [US1] Verify that each production deploy of the Vets service creates a GitHub Deployment record with fields: `environment`, `service=vets`, `sha`, `releaseId`; verify the KPI-1 report job reads these records and outputs the count of Owners deployments per Vets release (target: 0) — file: `.github/workflows/kpi-1-report.yml`

### S2 Shadow Comparison (Pre-S3 Gate)

- [ ] T094 [US1] Configure the edge to mirror live GET `/vets` and GET `/vets.html` requests to the dark Vets service during the S2 window; the mirror must be passive (mirror failure has no effect on users) and must carry no session or locale cookies (FR-025) — NEEDS CLARIFICATION: mirroring mechanism depends on edge technology choice per research item 14a — file: `edge/routing-table.[yml|conf]` (technology TBD per research item 5a)
- [ ] T095 [US1] Run the S2 shadow comparison over the agreed window; verify the diff count is 0 for status, `Content-Type`, and body for GET `/vets` (JSON, XML, no-Accept, `*/*`) and GET `/vets.html` (all pages, page size 5) between the monolith and the dark Vets service; store the comparison report as a CI artifact (SC-003, FR-025) — file: `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E3-S8-shadow-report.md`

### S3 Route Flip Rehearsal and Approval Gate

- [ ] T096 [US1] Rehearse the S3 route flip and rollback: flip `/vets` and `/vets.html` to the Vets service via a single reviewed routing-table change; verify the flip and revert each complete within 10 minutes or less (SC-002) with no failed owner requests; record timings in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E1-S13-rollback-rehearsal.md`
- [ ] T097 [US1] Record the S3 approval gate: delivery lead approves the flip after the shadow-comparison report (T095) shows 0 diffs and the rollback rehearsal (T096) has passed — document in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E1-S14-s3-approval.md`
- [ ] T098 [US1] Execute the S3 route flip as a single reviewed routing-table change in `edge/routing-table.[yml|conf]`; record the routing table version with the deploy; verify the flip completes within the agreed time; verify the golden-master diff after the flip is empty — file: `edge/routing-table.[yml|conf]`

**Checkpoint**: GET `/vets.html` and GET `/vets` are served by the Vets service through the edge. A commit to `vets/` triggers only `deploy-vets.yml`. KPI-1 report shows 0 Owners deployments for the Vets release window. KPI-2 failing-test count is 0.

---

## Phase 4: User Story 2 — Owners Team Releases Without Waiting for Vets Team (Priority: P1)

**Goal**: A change confined to the owner package triggers only the Owners service deploy workflow; the Vets service is not rebuilt, retested, or redeployed. Owner search, owner and pet editing, and visit creation continue to work throughout.

**Independent Test**: Merge a commit that changes only a file in `owners/`. Confirm that only `deploy-owners.yml` runs, that `deploy-vets.yml` does not run, and that the full owner, pet, and visit flows work correctly throughout. Verify the KPI-1 report shows 0 Vets deployments for that release window.

**Corresponds to**: W4 item E1-S12 (S4 — remove vet code from monolith so it becomes the Owners service).

### Owners Service — Application Correctness

- [ ] T099 [US2] Verify all owner, pet, and visit routes in `owners/` match the owners-http.md contract exactly: GET `/`, GET `/owners/find`, GET `/owners`, GET `/owners/new`, POST `/owners/new`, GET `/owners/{ownerId}/edit`, POST `/owners/{ownerId}/edit`, GET `/owners/{ownerId}`, GET `/owners/{ownerId}/pets/new`, POST `/owners/{ownerId}/pets/new`, GET `/owners/{ownerId}/pets/{petId}/edit`, POST `/owners/{ownerId}/pets/{petId}/edit`, GET `/owners/{ownerId}/pets/{petId}/visits/new`, POST `/owners/{ownerId}/pets/{petId}/visits/new`, GET `/oups` — files: `owners/src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java`, `PetController.java`, `VisitController.java`, `owners/src/main/java/org/springframework/samples/petclinic/system/CrashController.java`
- [ ] T100 [US2] Verify `Owner.java` in `owners/` has no content change from the monolith: telephone regex `\d{10}` and all `@NotBlank` rules are preserved verbatim (FR-007); verify no delete route and no delete repository method exist for Visit (FR-008) — files: `owners/src/main/java/org/springframework/samples/petclinic/owner/Owner.java`, `VisitRepository.java`
- [ ] T101 [US2] Verify the `UNIQUE (owner_id, name)` constraint exists on the `pets` table in `owners/src/main/resources/db/h2/schema.sql`, `db/mysql/schema.sql`, and `db/postgres/schema.sql` (FR-009) — files: `owners/src/main/resources/db/h2/schema.sql`, `owners/src/main/resources/db/mysql/schema.sql`, `owners/src/main/resources/db/postgres/schema.sql`
- [ ] T102 [US2] Confirm the Owners artifact contains no classes from the `vet` package by running the ArchUnit import-check test (T074) against the Owners module; record the result as evidence for SC-004 — file: `owners/src/test/java/org/springframework/samples/petclinic/owner/OwnerPackageBoundaryTest.java`

### S4 — Remove Vet Code from Monolith (Monolith Becomes Owners Service)

- [ ] T103 [US2] After 3 clean releases of the Vets service through the edge (verified by KPI-1 report), remove the `vet` package and `CacheConfiguration.java` from the monolith `src/` tree; the remaining `src/` tree becomes the Owners service source; retain the previous monolith OCI image in the registry for at least 3 releases for rollback (FR-023) — files: `src/main/java/org/springframework/samples/petclinic/vet/` (delete), `src/main/java/org/springframework/samples/petclinic/system/CacheConfiguration.java` (delete from monolith)
- [ ] T104 [US2] After S4, run the full KPI-2 suite against the Owners service; verify the failing-test count is 0; verify the Owners image contains no vet package classes (SC-004) — file: `.github/workflows/pr-verify.yml`

### CI Path-Filter Verification (Symmetric)

- [ ] T105 [US2] Verify the symmetric path-filter property: a commit touching only `owners/` triggers `deploy-owners.yml` and does not trigger `deploy-vets.yml`; verify the KPI-1 report shows 0 Vets deployments for the Owners release window — files: `.github/workflows/deploy-owners.yml`, `.github/workflows/kpi-1-report.yml`

**Checkpoint**: Both teams can release independently. A commit to `vets/` triggers only the Vets deploy; a commit to `owners/` triggers only the Owners deploy. KPI-1 target of 0 is met for both directions. KPI-2 failing-test count is 0.

---

## Phase 5: User Story 3 — End User Sees No Change After the Split (Priority: P1)

**Goal**: Every page a clinic receptionist visits — welcome page, owner search, owner and pet forms, vets list, error pages — looks and behaves exactly as before the split. No URL changes, no layout differences, no missing translations, no new error messages.

**Independent Test**: Run the full existing UI and controller test suite (`OwnerControllerTests`, `PetControllerTests`, `VisitControllerTests`, `VetControllerTests`, `CrashControllerTests`, `ClinicServiceTests`, `PetClinicIntegrationTests`) against the split system with no edits to expected results. All must pass. Failing-test count must be 0.

**Corresponds to**: W2 items E1-S7, E1-S9, E3-S2, E3-S3, E3-S4, E3-S5, E3-S6, E3-S7, E5-S1, E5-S2, E5-S9, E5-S11.

### Edge Router — Routing Table

- [ ] T106 [US3] Create the authoritative edge routing table file `edge/routing-table.[yml|conf]` (technology TBD per research item 5a) implementing all five rules from routing-table.md in order: (1) block `/actuator`, `/actuator/**`, `/livez`, `/readyz` → 404 with no upstream request; (2) route `/vets.html` → Vets with 1 s connect / 10 s read timeout, GET/HEAD-only jittered retry, per-upstream circuit breaker; (3) route `/vets` → Vets with same timeouts; (4) route `/resources/**`, `/webjars/**` → Owners (pending E3-S3 resolution); (5) default all other paths → Owners with 1 s connect / 30 s read timeout, GET/HEAD-only retry, no retry on POST/PUT/DELETE (FR-010, FR-011, FR-012, FR-013) — file: `edge/routing-table.[yml|conf]`
- [ ] T107 [US3] Add a route-inventory test that asserts the set of user-facing paths reachable through the edge after the split is identical to the set reachable through the monolith before the split; use the path list from routing-table.md as the reference; the test must fail if any monolith path is missing or any new path is added — file: `specs/009-split-petclinic-into-microserv-bbbd6b99/golden-masters/contract-tests/RouteInventoryTest.java`
- [ ] T108 [US3] Add a routing-table contract test that verifies: only `/vets` and `/vets.html` reach the Vets upstream; `/vets/` (trailing slash) and all other user-facing paths reach the Owners upstream; `/actuator/**`, `/livez`, and `/readyz` return 404 and the upstream request counter for both services remains 0 — file: `specs/009-split-petclinic-into-microserv-bbbd6b99/golden-masters/contract-tests/RoutingTableContractTest.java`

### Edge Router — Technology Selection

- [ ] T109 [US3] Choose the edge technology (Spring Cloud Gateway, Nginx, Envoy, or Traefik) against the capability checklist from research item 5a: exact-path routing, 404-without-forward for operational paths, GET/HEAD-only retry with jitter, per-upstream circuit breaker, fallback 503 with `Retry-After`, request mirroring for S2, query-string masking in logs, forwarded-header stripping, no session propagation to Vets, configurable per-upstream timeouts, routing table as a reviewed file in the repository — NEEDS CLARIFICATION per research item 5a; record the decision in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E4-S6-edge-technology.md`
- [ ] T110 [US3] Put the chosen edge in front of the unchanged monolith as stage S1b with all traffic still on the monolith; run the golden-master contract tests (T085) and the full KPI-2 suite through the edge; verify both pass; rehearse the edge rollback — file: `edge/routing-table.[yml|conf]`

### Edge Router — Resilience

- [ ] T111 [US3] Configure per-upstream circuit breakers in `edge/routing-table.[yml|conf]`: when the Vets upstream is down or the circuit is open, `/vets.html` and `/vets` return `503 Service Unavailable` with a `Retry-After` header and render the petclinic-ui error page layout; all owner, pet, and visit routes must return normal responses without any failed requests (FR-012, edge case in spec) — file: `edge/routing-table.[yml|conf]`
- [ ] T112 [US3] Configure the write-safety rule in `edge/routing-table.[yml|conf]`: the edge must never retry POST, PUT, or DELETE requests to any upstream; an upstream failure on a write must return the edge error immediately with no second attempt (FR-013); add a fault-injection test that sends a connection reset after the request body of POST `/owners/new` has been sent and asserts exactly 1 upstream request and no duplicate owner record — file: `edge/routing-table.[yml|conf]`
- [ ] T113 [US3] Configure the service-isolation rule: a failure of the Owners upstream must not affect responses from the Vets upstream and vice versa; add a test that stops the Vets service and verifies `/owners/find` stays responsive and `/vets.html` returns the shared error page (FR-012, E5-S11) — file: `edge/routing-table.[yml|conf]`

### Edge Router — Header Rules and Forwarded-Header Stripping

- [ ] T114 [US3] Configure the edge to strip inbound `X-Forwarded-Host`, `X-Forwarded-For`, and `X-Forwarded-Proto` headers before forwarding to either upstream (E5-S1); add a test that sends a forged `Host` or `X-Forwarded-Host` header and verifies it never appears in a `Location` response header — file: `edge/routing-table.[yml|conf]`
- [ ] T115 [P] [US3] Configure the edge to rewrite any `Location` header from an upstream that contains an internal Kubernetes hostname or port to use the public host or a relative path; add a test that verifies no redirect `Location` contains an internal service name — file: `edge/routing-table.[yml|conf]`
- [ ] T116 [P] [US3] Configure the edge to not forward `JSESSIONID` from the Owners service to the Vets service and to not forward any Vets response cookie to the Owners service; the locale cookie must pass through unchanged in both directions — file: `edge/routing-table.[yml|conf]`

### Locale and Cross-Service Language Persistence

- [ ] T117 [US3] Verify `CookieLocaleResolver` is configured identically in both `vets/system/WebConfiguration.java` and `owners/system/WebConfiguration.java`: default English, `lang` query parameter, cookie name and domain consistent so the cookie set by one service is readable by the other — NEEDS CLARIFICATION: cookie name, domain, and path attributes depend on deployment topology per research item 11a, resolved in E3-S4 — files: `vets/src/main/java/org/springframework/samples/petclinic/system/WebConfiguration.java`, `owners/src/main/java/org/springframework/samples/petclinic/system/WebConfiguration.java`
- [ ] T118 [US3] Verify that `?lang=de` set on an Owners page applies when the user navigates to `/vets.html` and vice versa; verify the Vets service issues no `JSESSIONID` cookie; verify flash messages still appear after a POST-redirect-GET in the Owners service (FR-014, SC-006, E3-S4) — file: `owners/src/test/java/org/springframework/samples/petclinic/owner/OwnerControllerTests.java`
- [ ] T119 [P] [US3] Configure locale cookie security attributes in both services: `HttpOnly`, `SameSite=Lax`, and `Secure` on TLS (E5-S9); add a test that verifies `Set-Cookie` on `?lang=de` carries `HttpOnly` and `SameSite=Lax` and that a garbage locale cookie value returns `200 OK` in English and never `500` — files: `vets/src/main/java/org/springframework/samples/petclinic/system/WebConfiguration.java`, `owners/src/main/java/org/springframework/samples/petclinic/system/WebConfiguration.java`

### Error Handling

- [ ] T120 [US3] Verify `CrashController.java` in `owners/system/` serves GET `/oups` and that the rendered error page uses `error.html` from the pinned petclinic-ui artifact with layout identical to the monolith (FR-015); verify `CrashControllerTests.java` passes unchanged — file: `owners/src/main/java/org/springframework/samples/petclinic/system/CrashController.java`
- [ ] T121 [P] [US3] Verify the Vets service renders application-level errors using `error.html` from the pinned petclinic-ui artifact; the rendered error page must be visually identical to the monolith's error page; the Vets service has no `CrashController` and `/oups` is not a Vets route (FR-015) — file: `vets/src/main/resources/templates/error.html` (resolved from petclinic-ui artifact)
- [ ] T122 [P] [US3] Verify the edge renders its own errors (503, circuit-breaker open) using the petclinic-ui error page layout; verify the edge never converts a 4xx response from an upstream into a 5xx (E3-S7) — file: `edge/routing-table.[yml|conf]`

### Static Assets and petclinic-ui Artifact

- [ ] T123 [US3] Resolve the cross-service static-asset fallback conflict (DEF-4, E3-S3): decide whether `/resources/**` and `/webjars/**` are served from the Owners upstream or directly from the petclinic-ui artifact by the edge; verify that with the Owners service stopped, `/vets.html` still loads all its assets; verify a page never receives assets from a different petclinic-ui version — NEEDS CLARIFICATION: resolution depends on edge technology and E1-S2 UI rule decision; record the decision in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E3-S3-static-assets.md`; update `edge/routing-table.[yml|conf]` Rule 4 accordingly

### KPI-2 Full Suite Verification

- [ ] T124 [US3] Run the complete KPI-2 suite against the split system: `OwnerControllerTests`, `PetControllerTests`, `VisitControllerTests`, `VetControllerTests`, `CrashControllerTests`, `ClinicServiceTests` (both modules), `PetClinicIntegrationTests`; verify the failing-test count is 0 and no expected result has been edited (FR-024, KPI-2) — file: `.github/workflows/pr-verify.yml`
- [ ] T125 [P] [US3] Run the KPI-2 suite on H2, MySQL (Testcontainers), and PostgreSQL (Testcontainers) variants; verify the failing-test count is 0 on all three engines (FR-024) — files: `vets/src/test/java/org/springframework/samples/petclinic/MySqlIntegrationTests.java`, `vets/src/test/java/org/springframework/samples/petclinic/PostgresIntegrationTests.java`, `owners/src/test/java/org/springframework/samples/petclinic/MySqlIntegrationTests.java`, `owners/src/test/java/org/springframework/samples/petclinic/PostgresIntegrationTests.java`

**Checkpoint**: Every existing user-facing URL returns the same status, headers, redirects, and body as the monolith. KPI-2 failing-test count is 0 on H2, MySQL, and PostgreSQL. The locale cookie persists across services. Error pages are identical to the monolith.

---

## Phase 6: User Story 4 — Staged Migration Proceeds One Step at a Time Without Data Loss (Priority: P2)

**Goal**: The migration team executes the cutover in defined stages S2 through S6. At each stage the system is verifiably correct, rollback is available, and no owner data is exposed or lost. The vet data copy (S5) is preceded by reconciliation and followed by verification. The old vet tables are not dropped (S6) until a backup has been taken and a restore test has succeeded.

**Independent Test**: Execute the S5 rehearsal on a restored copy of production-like data on each supported engine (MySQL, PostgreSQL). Confirm that row counts and checksums match, the freeze window is under 15 minutes, and rollback by redeploying the previous Vets config against the old tables succeeds.

**Corresponds to**: W5 items E1-S15, E1-S16, E2-S5, E2-S6, E5-S7; W2 items E2-S3, E2-S7.

### Migration Job — DDL-Only Path

- [ ] T126 [US4] Read the real MySQL and PostgreSQL `schema.sql` files and profile properties from the monolith (NEEDS CLARIFICATION per research item 8a); design the migration job to be the sole DDL path for MySQL and PostgreSQL; implement the migration job as create-if-missing only with no demo seed data in production; verify idempotence by running the job twice against a copy of production-like data and confirming checksums are equal after both runs (FR-019, E2-S3) — files: `migration/src/main/resources/db/mysql/V1__vets_schema.sql`, `migration/src/main/resources/db/mysql/V1__owners_schema.sql`, `migration/src/main/resources/db/postgres/V1__vets_schema.sql`, `migration/src/main/resources/db/postgres/V1__owners_schema.sql`
- [ ] T127 [US4] Verify that neither the Vets service nor the Owners service runs DDL or `data.sql` at startup against a populated MySQL or PostgreSQL store; confirm `spring.sql.init.mode=never` is in effect for both services on MySQL and PostgreSQL profiles (FR-019) — files: `vets/src/main/resources/application-mysql.properties`, `vets/src/main/resources/application-postgres.properties`, `owners/src/main/resources/application-mysql.properties`, `owners/src/main/resources/application-postgres.properties`
- [ ] T128 [US4] Verify that a failed migration job stops the deploy pipeline and does not leave the schema in a partially migrated state; add a test that simulates a mid-job failure and confirms the deploy is blocked — file: `migration/src/main/resources/db/` (migration job configuration)

### Database Role Enforcement

- [ ] T129 [US4] Create the three database principals on MySQL and PostgreSQL: `vets_runtime` (SELECT on `vets`, `specialties`, `vet_specialties` only; no access to owner tables; no INSERT/UPDATE/DELETE on any table), `owners_runtime` (SELECT/INSERT/UPDATE on `owners`, `pets`, `types`; SELECT/INSERT on `visits`; DELETE denied on `visits`; no access to vet tables after S5), `migration_principal` (DDL + DML on all tables; not used at runtime) — FR-020, research item 9; files: `migration/src/main/resources/db/mysql/roles.sql`, `migration/src/main/resources/db/postgres/roles.sql`
- [ ] T130 [US4] Verify the Vets runtime principal is denied SELECT on `owners`, `pets`, `visits`, and `types` and denied INSERT/UPDATE/DELETE on all tables; run the data ownership rule scripts (T058) under the Vets principal and confirm 0 violating rows — file: `migration/src/main/resources/db/verify/ownership-rules-mysql.sql`, `ownership-rules-postgres.sql`
- [ ] T131 [P] [US4] Verify the KPI-2 suite passes under the Owners runtime principal on Testcontainers MySQL and PostgreSQL (FR-024, E5-S3) — files: `owners/src/test/java/org/springframework/samples/petclinic/MySqlIntegrationTests.java`, `owners/src/test/java/org/springframework/samples/petclinic/PostgresIntegrationTests.java`

### Owner PII Protection

- [ ] T132 [US4] Run the owner PII protection checks: scan the Vets module schema files, H2 `schema.sql`, H2 `data.sql`, test fixtures, and any reconciliation report output for owner column names (`name`, `address`, `telephone`) and owner table names (`owners`); confirm no owner column or row value appears in any Vets-side artefact (FR-022, SC-005) — file: `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E2-S7-pii-scan.md`
- [ ] T133 [P] [US4] Verify that reconciliation reports for owner tables contain only counts and hashes and never contain owner names, addresses, telephone numbers, or any other owner field value (FR-022, edge case in spec) — file: `migration/src/main/resources/db/verify/ownership-rules-mysql.sql`, `ownership-rules-postgres.sql`

### S5 Vet Data Copy and Reconciliation Tool

- [ ] T134 [US4] Sponsor decision gate: record whether the optional S5 separate vet schema is wanted; if S5 is declined, close S5 and S6 stories and record that KPI-1 is judged on S3 and S4 only — document in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E1-S15-s5-decision.md`
- [ ] T135 [US4] Decide whether S5 uses a separate database instance or a separate schema within the same instance (NEEDS CLARIFICATION per research item 8b); record the decision and its effect on the database role configuration (FR-020) and the reconciliation tool design (FR-021) — document in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E2-S5-s5-topology.md`
- [ ] T136 [US4] Implement the S5 vet data copy tool: copy only `vets`, `specialties`, and `vet_specialties` from the shared database to the Vets-owned schema; the copy tool must name exactly these three tables and no others; no owner table, column, or row value must appear in any copy configuration, log, or output (FR-022, E5-S7) — NEEDS CLARIFICATION: copy tool (bulk SQL INSERT/SELECT, `pg_dump`, logical replication) per research item 15a — file: `migration/src/main/resources/db/s5/copy-vet-tables.sql` (or equivalent)
- [ ] T137 [US4] Implement the reconciliation tool: before the S5 switch, verify row counts and per-range checksums for `vets`, `specialties`, and `vet_specialties` are equal on source and target; a mismatch must fail the job and block the switch; store the reconciliation report as a CI artifact (FR-021) — file: `migration/src/main/resources/db/s5/reconcile-vet-tables.sql`
- [ ] T138 [US4] Add an automated scan of all S5 artefacts (copy configuration, reconciliation report, any intermediate files) that checks for owner column names before the switch is approved; the scan must block the switch if any owner column name or value is found (SC-005, FR-022) — file: `migration/src/main/resources/db/s5/scan-for-owner-pii.sh`
- [ ] T139 [US4] Verify that after the S5 copy completes, if a write to a vet table is detected, the S5 rollback is declared invalid and the step stops for re-planning; the switch must not proceed (edge case in spec) — file: `migration/src/main/resources/db/s5/copy-vet-tables.sql`

### S5 and S6 Rehearsal

- [ ] T140 [US4] Rehearse the S5 copy and reconciliation on a restored copy of production-like data for MySQL and PostgreSQL; verify: row counts and checksums match on source and target, the freeze window is 15 minutes or less (SC-001), the S5 rollback by redeploying the previous Vets config against the intact old tables succeeds within 10 minutes (FR-023); record timings in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E2-S6-s5-rehearsal.md`
- [ ] T141 [US4] Verify S6 pre-conditions: S6 is blocked until (a) a backup of the old vet tables has been taken and is encrypted, (b) a restore test has succeeded and is recorded, and (c) the sponsor has given explicit approval; no temporary dump file remains on any host after the backup (FR-023, E5-S7) — document in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E1-S16-s6-approval.md`
- [ ] T142 [US4] Record the S6 approval gate: sponsor explicitly approves the drop of the old vet tables only after all three pre-conditions in T141 are met and 3 further clean releases have been observed — document in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E1-S16-s6-approval.md`

**Checkpoint**: Migration job is the sole DDL path. Both services start with `spring.sql.init.mode=never` against persistent stores. S5 rehearsal report shows freeze window under 15 minutes on MySQL and PostgreSQL. S6 is blocked pending backup, restore test, and sponsor approval. No owner PII appears in any Vets-side artefact.

---

## Phase 7: User Story 5 — Operational Endpoints Accessible Only on the Management Port (Priority: P2)

**Goal**: Health, info, metrics, and prometheus endpoints are reachable on the dedicated management port. No operational path is reachable through the public-facing edge. The edge returns 404 for `/actuator/**`, `/livez`, and `/readyz` on the public host.

**Independent Test**: Send requests to `/actuator/health`, `/actuator/prometheus`, `/livez`, and `/readyz` through the edge and confirm each returns 404 with no upstream request recorded. Then send the same requests directly to the management port of each service and confirm correct responses.

**Corresponds to**: W2 items E1-S10, E3-S6, E4-S5, E4-S7, E4-S10, E5-S2, E5-S5.

### Management Port Configuration

- [ ] T143 [US5] Confirm the management port number for each service against the existing Kubernetes manifests in `k8s/` and the Prometheus scrape configuration (NEEDS CLARIFICATION per research item 12a); record the confirmed port number in `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E4-S5-management-port.md`; update `vets/src/main/resources/application.properties` and `owners/src/main/resources/application.properties` with the confirmed `management.server.port` value
- [ ] T144 [US5] Add a configuration test in both modules that asserts the effective `management.endpoints.web.exposure.include` equals exactly `health,info,metrics,prometheus` and that `management.endpoint.health.show-details=never` is in effect (FR-016) — files: `vets/src/test/java/org/springframework/samples/petclinic/ActuatorExposureConfigTest.java`, `owners/src/test/java/org/springframework/samples/petclinic/ActuatorExposureConfigTest.java`
- [ ] T145 [P] [US5] Verify that `/actuator/env`, `/actuator/heapdump`, `/actuator/beans`, `/actuator/mappings`, and `/actuator/configprops` return `404 Not Found` on the management port of both services (FR-016, E5-S2) — files: `vets/src/test/java/org/springframework/samples/petclinic/ActuatorExposureConfigTest.java`, `owners/src/test/java/org/springframework/samples/petclinic/ActuatorExposureConfigTest.java`
- [ ] T146 [P] [US5] Verify that no metric tag in `/actuator/metrics` or `/actuator/prometheus` on either service contains an owner field value (name, address, telephone) (E5-S2, FR-022) — files: `vets/src/test/java/org/springframework/samples/petclinic/ActuatorExposureConfigTest.java`, `owners/src/test/java/org/springframework/samples/petclinic/ActuatorExposureConfigTest.java`

### Kubernetes Runtime Topology

- [ ] T147 [US5] Create `k8s/vets/deployment.yaml`: Vets Deployment with 1 replica; JDK 17 base image; liveness probe on `GET /actuator/health/liveness` at `<management-port>`; readiness probe on `GET /actuator/health/readiness` at `<management-port>`; application port `8080` (NEEDS CLARIFICATION: confirm against existing manifests in E4-S5) not used for probes (FR-016) — file: `k8s/vets/deployment.yaml`
- [ ] T148 [P] [US5] Create `k8s/vets/service.yaml`: ClusterIP Service exposing only the application port; management port must not be exposed through this Service (FR-017) — file: `k8s/vets/service.yaml`
- [ ] T149 [P] [US5] Create `k8s/owners/deployment.yaml`: Owners Deployment with liveness and readiness probes on the management port; same probe configuration as Vets — file: `k8s/owners/deployment.yaml`
- [ ] T150 [P] [US5] Create `k8s/owners/service.yaml`: ClusterIP Service exposing only the application port; management port not exposed — file: `k8s/owners/service.yaml`
- [ ] T151 [US5] Verify that restarting the Vets Deployment restarts no Owners pod and vice versa; verify the two Deployments are independent Kubernetes objects — files: `k8s/vets/deployment.yaml`, `k8s/owners/deployment.yaml`

### NetworkPolicy — Management Port Isolation

- [ ] T152 [US5] Create `k8s/vets/networkpolicy.yaml`: default-deny ingress; allow ingress to application port from the edge/ingress controller namespace only; allow ingress to management port from the monitoring namespace and orchestration namespace only; deny all other ingress to the management port; deny all traffic between the Vets pod and the Owners pod (FR-017, E5-S5) — file: `k8s/vets/networkpolicy.yaml`
- [ ] T153 [P] [US5] Create `k8s/owners/networkpolicy.yaml`: same NetworkPolicy structure as Vets; deny all traffic between the Owners pod and the Vets pod — file: `k8s/owners/networkpolicy.yaml`
- [ ] T154 [US5] Add a test that verifies a connection attempt to the management port from outside the monitoring namespace is refused (User Story 5 scenario 5, FR-017) — file: `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E4-S10-networkpolicy-test.md`
- [ ] T155 [P] [US5] Add a test that verifies a connection from the Vets pod to the Owners pod is refused and vice versa (E5-S5) — file: `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E5-S5-pod-isolation-test.md`

### Edge — Operational Path Blocking

- [ ] T156 [US5] Verify Rule 1 of `edge/routing-table.[yml|conf]` blocks `/actuator`, `/actuator/**`, `/livez`, and `/readyz` on the public host and returns `404 Not Found` with no upstream request forwarded to either service; verify the upstream request counter for both services remains 0 after requests matching this rule (FR-011, User Story 5 scenario 1) — file: `edge/routing-table.[yml|conf]`
- [ ] T157 [P] [US5] Verify the management port of each service is not listed as an upstream in the edge routing table and is not reachable through the edge under any routing rule (FR-017) — file: `edge/routing-table.[yml|conf]`

### Observability — Metrics and Alerts

- [ ] T158 [US5] Verify that after any HTTP request to the application port, `http.server.requests` is present in `/actuator/prometheus` on the management port of both services (User Story 5 scenario 2) — files: `vets/src/test/java/org/springframework/samples/petclinic/ActuatorExposureConfigTest.java`, `owners/src/test/java/org/springframework/samples/petclinic/ActuatorExposureConfigTest.java`
- [ ] T159 [US5] Verify that after two calls to `VetRepository.findAll`, the Prometheus output on the Vets management port includes `cache_gets_total` (or equivalent) with label `cache="vets"` and the value is greater than 0 (User Story 5 scenario 2 and 3, FR-006) — file: `vets/src/test/java/org/springframework/samples/petclinic/vet/VetControllerTests.java`
- [ ] T160 [US5] Configure observability alerts: stopping the Vets service in staging must raise the readiness and probe alerts within 5 minutes while the Owners readiness probe stays green; configure JSON structured logs with a request ID and service name in each log line (E4-S7, E5-S6) — files: `k8s/vets/deployment.yaml`, `k8s/owners/deployment.yaml`
- [ ] T161 [P] [US5] Configure query-string masking at the edge: the `lastName` query parameter value in requests to `/owners` must be masked in access logs; the log entry must record that the parameter was present but must not record its value (E5-S6, routing-table.md) — file: `edge/routing-table.[yml|conf]`
- [ ] T162 [P] [US5] Verify that a single request ID can be followed from the edge access log to the service application log; verify that an owner search for a known last name leaves no instance of that name in edge or application logs (E5-S6) — file: `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E5-S6-log-tracing-test.md`

### Timed Rollback Per Stage

- [ ] T163 [US5] Verify the timed rollback targets from the pipeline: S3 edge revert completes in 5 minutes or less; S4 and S5 rollbacks complete in 10 minutes or less; the registry retains the last 3 monolith OCI images; S6 is blocked until a restore test is recorded (FR-023, E4-S8) — file: `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/E4-S8-rollback-timings.md`
- [ ] T164 [P] [US5] Verify the NetworkPolicy revert through `deploy-edge.yml` completes in 5 minutes or less (E4-S10) — file: `.github/workflows/deploy-edge.yml`

**Checkpoint**: Health, info, metrics, and prometheus are reachable only on the management port. The edge returns 404 for all operational paths on the public host with 0 upstream requests. NetworkPolicy enforces management-port isolation. Alerts fire within 5 minutes of a service going down.

---

## Phase 8: Polish and Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories, supply-chain hardening, and constitution amendment planning.

- [ ] T165 [P] Add `k8s/edge/` manifests for the chosen edge technology: Deployment or DaemonSet, Service, and any edge-specific configuration resources — file: `k8s/edge/` (technology TBD per T109)
- [ ] T166 [P] Add `k8s/migration/job.yaml`: Kubernetes Job for the migration job; runs DDL only; not a runtime service; uses `migration_principal` credentials — file: `k8s/migration/job.yaml`
- [ ] T167 [P] Run a secret scan across the entire repository to confirm no credential, database password, or API key is embedded in any file; verify the Vets pipeline credential cannot deploy Owners and vice versa (E5-S4) — file: `.github/workflows/pr-verify.yml` (update T075)
- [ ] T168 [P] Add a `pr-verify.yml` check that fails if any direct push to the petclinic-ui release branch is attempted (E5-S10) — file: `.github/workflows/pr-verify.yml` (update T075)
- [ ] T169 [P] Verify that `@DisabledInNativeImage` annotations and their explanatory comments are retained verbatim in whichever module they were moved to (research item 19) — files: `vets/src/test/`, `owners/src/test/`
- [ ] T170 [P] Confirm GitHub issues #2, #3, and #5 have not been touched by any task in this list; add a note to `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/out-of-scope.md` recording that they are explicitly out of scope (spec Assumptions) — file: `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/out-of-scope.md`
- [ ] T171 Plan the constitution Section I amendment: after the migration is ratified by the maintainer, Section I (Modular Monolith Architecture) must be amended to reflect the new two-service architecture; record this as a follow-on task with no implementation in this feature (spec Assumptions, research item 22) — file: `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/constitution-amendment.md`
- [ ] T172 [P] Run the full quickstart.md validation (if quickstart.md exists) against the split system to confirm all scenarios pass end-to-end through the edge — file: `specs/009-split-petclinic-into-microserv-bbbd6b99/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup — Decisions)**: No dependencies. Must complete before any other phase.
- **Phase 2 (Foundational — Multi-Module Build)**: Depends on Phase 1 completion. Blocks all user story phases.
- **Phase 3 (US1 — Vets Release Independence)**: Depends on Phase 2. Requires edge technology decision (T109) before T094–T098.
- **Phase 4 (US2 — Owners Release Independence)**: Depends on Phase 2. T103 additionally depends on Phase 3 (3 clean Vets releases required before S4).
- **Phase 5 (US3 — No User-Visible Change)**: Depends on Phase 2. T110 depends on T109 (edge technology). T123 depends on T002 (UI rule) and T109.
- **Phase 6 (US4 — Staged Migration)**: Depends on Phase 2. T134 depends on Phase 4 (E1-S15 requires S4 complete). T136–T142 depend on T134 (sponsor S5 decision).
- **Phase 7 (US5 — Management Port)**: Depends on Phase 2. T143 depends on T003 (accepted-changes sponsor agreement). T156–T157 depend on T106 (routing table).
- **Phase 8 (Polish)**: Depends on all desired user story phases being complete.

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2. No dependency on US2, US3, US4, or US5.
- **US2 (P1)**: Can start after Phase 2. T103 (S4) depends on US1 being stable for 3 releases.
- **US3 (P1)**: Can start after Phase 2. T110 depends on T109 (edge technology, US3 internal). T123 depends on T002 and T109.
- **US4 (P2)**: Can start after Phase 2. T134 depends on US2 (S4 complete). T136–T142 depend on T134.
- **US5 (P2)**: Can start after Phase 2. T143 depends on T003. T156 depends on T106 (US3).

### Critical Path

```
T001–T006 (Phase 1 decisions)
  → T007–T085 (Phase 2 foundational build, golden masters, CI)
    → T086–T098 (US1: Vets release independence + S3 flip)
    → T099–T105 (US2: Owners release independence + S4)
    → T106–T125 (US3: no user-visible change + edge)
    → T126–T142 (US4: staged migration, S5, S6)
    → T143–T164 (US5: management port)
      → T165–T172 (Polish)
```

### Parallel Opportunities Within Phases

**Phase 2** — after T007 (root POM), all of T008–T011 (module POMs) run in parallel; after T012 (base entity identification), T013 and T014 run in parallel; T015–T022 (Vets source classes) all run in parallel; T023–T030 (Vets resources) all run in parallel after T023; T031–T042 (Owners source classes) all run in parallel; T043–T050 (Owners resources) all run in parallel after T043; T051–T055 (petclinic-ui) run in parallel after T051; T060–T073 (test redistribution) all run in parallel after T059.

**Phase 3** — T086–T089 run in parallel; T090–T091 run in parallel; T092–T093 run in parallel; T094 and T095 are sequential (mirror then compare); T096 and T097 are sequential (rehearse then approve); T098 depends on T097.

**Phase 5** — T107–T108 run in parallel after T106; T111–T116 run in parallel after T106; T117–T119 run in parallel; T120–T122 run in parallel; T124–T125 run in parallel.

**Phase 7** — T144–T146 run in parallel after T143; T147–T150 run in parallel; T152–T155 run in parallel; T156–T157 run in parallel; T158–T162 run in parallel.

---

## Parallel Example: Phase 2 Module Scaffolding

```
# After T007 (root pom.xml), launch in parallel:
T008  vets/pom.xml
T009  owners/pom.xml
T010  petclinic-ui/pom.xml
T011  migration/pom.xml

# After T012 (base entity identification), launch in parallel:
T013  Copy BaseEntity → vets/
T014  Copy BaseEntity → owners/

# After T013, launch in parallel (all Vets source classes):
T015  Vet.java → vets/
T016  Specialty.java → vets/
T017  Vets.java → vets/
T018  VetRepository.java → vets/
T019  VetController.java → vets/
T020  CacheConfiguration.java → vets/
T021  WebConfiguration.java → vets/

# After T031 (Owner.java), launch in parallel (all Owners source classes):
T032  Pet.java → owners/
T033  PetType.java → owners/
T034  Visit.java → owners/
T035  OwnerRepository.java → owners/
T036  PetRepository.java → owners/
T037  VisitRepository.java → owners/
T038  PetValidator.java → owners/
T039  Owner controllers → owners/
T040  WebConfiguration.java → owners/
T041  CrashController.java → owners/
```

---

## Implementation Strategy

### MVP First (User Stories 1 and 3 Only — S3 Route Flip)

1. Complete Phase 1: Decisions (T001–T006)
2. Complete Phase 2: Foundational build, golden masters, CI (T007–T085)
3. Complete Phase 3: US1 Vets release independence through S3 flip (T086–T098)
4. Complete Phase 5 routing and no-regression work: US3 (T106–T125)
5. **STOP and VALIDATE**: KPI-1 shows 0 Owners deploys per Vets release; KPI-2 failing-test count is 0; golden-master diff is empty
6. Deploy/demo if ready

### Incremental Delivery

1. Phase 1 + Phase 2 → Foundation ready; production still on monolith
2. Phase 3 (US1) + Phase 5 (US3) → S3 route flip; Vets team can release independently; no user-visible change
3. Phase 4 (US2) → S4; Owners team can release independently; KPI-1 target met for both directions
4. Phase 7 (US5) → Management port isolation; platform probes and Prometheus scrape configured
5. Phase 6 (US4) → Staged migration S5 and S6 (optional, sponsor-gated)
6. Phase 8 (Polish) → Supply-chain hardening, constitution amendment planning

### Parallel Team Strategy

With multiple developers, once Phase 2 is complete:
- Developer A: US1 (Phase 3) — Vets service correctness and S3 flip
- Developer B: US3 (Phase 5) — Edge routing table and resilience
- Developer C: US5 (Phase 7) — Management port, NetworkPolicy, Kubernetes manifests
- US2 (Phase 4) and US4 (Phase 6) follow sequentially after US1 and US3 are stable

---

## Notes

- `[P]` tasks operate on different files with no dependency on incomplete tasks in the same phase
- `[Story]` labels map each task to a specific user story for KPI-1 and KPI-2 traceability
- Every task marked NEEDS CLARIFICATION must be resolved before the task is started; the blocking research item number is cited inline
- No task edits any test assertion or expected result; all test redistribution is verbatim (FR-024, KPI-2)
- GitHub issues #2, #3, and #5 are explicitly out of scope; no task touches them (T170)
- The constitution Section I amendment is a follow-on task after ratification; it is not implemented here (T171)
- Commit after each task or logical group; stop at each phase checkpoint to validate independently before proceeding
