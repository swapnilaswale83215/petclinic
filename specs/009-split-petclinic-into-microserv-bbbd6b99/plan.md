# Implementation Plan: Split PetClinic into Microservices

**Branch**: `009-split-petclinic-into-microserv-bbbd6b99` | **Date**: 2026-10-19 | **Spec**: `/specs/009-split-petclinic-into-microserv-bbbd6b99/spec.md`

**Input**: Feature specification from `/specs/009-split-petclinic-into-microserv-bbbd6b99/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

---

## Summary

Split the Spring Boot PetClinic monolith into two independently deployable services — **Vets** and **Owners** — so that the Vets team and the Owners team can build, test, and release without waiting for each other (KPI-1 target: 0 redeploys of the other service per release). A shared **petclinic-ui** artifact carries layout, error pages, static assets, and all 11 i18n bundles; both services pin the same version. A single-origin **edge router** routes `/vets` and `/vets.html` to the Vets service and every other user-facing path to the Owners service. Every existing user-facing URL, page layout, validation message, and redirect must be preserved byte-for-byte (KPI-2 target: 0 failing tests in the existing suite with no edits to expected results).

The migration is staged (S2 → S6) following ADR-APP-5 and ADR-DATA-1. The repository is restructured as a Maven multi-module project (`vets/`, `owners/`, `petclinic-ui/`). Model classes are copied verbatim into each module; there is no shared Java library. Table ownership is clean: Vets owns `vets`, `specialties`, `vet_specialties`; Owners owns `owners`, `pets`, `visits`, `types`. In MySQL/PostgreSQL environments DDL is applied only by a dedicated migration job; both services start with `spring.sql.init.mode=never`. The optional S5 vet schema copy and S6 table drop require explicit sponsor approval and are gated behind reconciliation, backup, and restore-test pre-conditions.

---

## Technical Context

**Language/Version**: Java 17 (unchanged throughout; no upgrade or downgrade in scope per spec Assumptions)

**Primary Dependencies**:
- Spring Boot (existing version; unchanged)
- Spring MVC + Thymeleaf (server-side rendering; both services)
- Spring Data JPA + Hibernate (both services, scoped to their own table sets)
- Spring Boot Actuator + Micrometer (both services; management port only)
- JCache (`@Cacheable("vets")` in Vets service only, backed by `CacheConfiguration`)
- Jackson + JAXB/Jackson-dataformat-xml (Vets service; XML marshalling retained per FR-005)
- Jakarta Bean Validation (both services; `Owner.java` content unchanged per FR-007)
- Maven Wrapper (`mvnw`); no external Maven installation required
- GitHub Actions (CI platform)
- Docker Compose (local containerised runs); Kubernetes manifests in `k8s/` (cluster deployment)
- petclinic-ui artifact (pinned version; coordinates NEEDS CLARIFICATION — see research item 4a)
- Edge router (technology NEEDS CLARIFICATION — see research item 5a; chosen in E4-S6)
- Testcontainers (MySQL and PostgreSQL integration tests)
- ArchUnit (import boundary enforcement; test location NEEDS CLARIFICATION — see research item 2a)

**Storage**:
- H2 in-memory (dev/CI; each service uses its own instance with only its own table subset)
- MySQL (production-representative; profile-activated)
- PostgreSQL (production-representative; profile-activated)
- Table ownership: Vets → `vets`, `specialties`, `vet_specialties`; Owners → `owners`, `pets`, `visits`, `types`
- Migration job is the sole DDL path for MySQL/PostgreSQL; both services start with `spring.sql.init.mode=never` against a populated store
- Migration job tool: NEEDS CLARIFICATION (Flyway, Liquibase, or custom SQL — see research item 8a)
- S5 separate schema vs. separate instance: NEEDS CLARIFICATION (see research item 8b)

**Testing**:
- `@WebMvcTest` + Mockito for all controller tests (per constitution)
- `ClinicServiceTests` split verbatim by service (exact method distribution NEEDS CLARIFICATION — see research item 18a)
- `MySqlIntegrationTests` and `PostgresIntegrationTests` with Testcontainers (scoped per module)
- `PetClinicConcurrencyTests` in Owners module
- `PetClinicIntegrationTests` in Owners module
- `I18nPropertiesSyncTest` in both modules (pinned petclinic-ui bundles)
- ArchUnit import-check test (location NEEDS CLARIFICATION — see research item 2a)
- Golden-master contract tests for `/vets`, `/vets.html`, and owner/pet/visit flows (E3-S1)
- KPI-2 suite: `OwnerControllerTests`, `PetControllerTests`, `VisitControllerTests`, `VetControllerTests`, `CrashControllerTests`, `ClinicServiceTests`, `PetClinicIntegrationTests` — 0 failing tests required at every stage

**Target Platform**: Kubernetes (cluster deployment via `k8s/` manifests); Docker Compose (local); Linux containers (JDK 17 base image with SBOM per E4-S2)

**Project Type**: Two independently deployable web services (Spring Boot, server-side rendering) + one shared UI artifact + one edge router + one migration job

**Performance Goals**:
- S5 freeze window: 15 minutes or less (SC-001)
- S3 route flip and rollback: 10 minutes or less (SC-002; assumed platform target — must be confirmed with platform team per spec Assumptions)
- S3 revert from pipeline: 5 minutes or less (E4-S8)
- S4 and S5 rollback: 10 minutes or less (E4-S8)
- Vets service: GET /vets and GET /vets.html responses byte-equal to monolith for the same data (SC-003)
- Edge read timeout: 10 s for Vets and static assets; 30 s for Owners (FR-012)
- Edge connect timeout: 1 s (FR-012)

**Constraints**:
- No shared Java library between Vets and Owners (FR-001)
- No cross-package import (vet ↔ owner) — CI import check fails the build (FR-002, SC-004)
- No change to any user-facing URL, page layout, validation message, redirect, or test assertion (FR-024, KPI-2)
- No owner PII (name, address, telephone) in any Vets-side dump, log, fixture, or reconciliation report (FR-022, SC-005)
- No delete route or delete repository method for Visit (FR-008)
- `spring.sql.init.mode=never` against any persistent store (FR-019)
- Actuator exposure exactly `health,info,metrics,prometheus` on management port only; edge returns 404 for `/actuator/**`, `/livez`, `/readyz` on public host (FR-011, FR-016)
- Management port not routed by edge; NetworkPolicy restricts it to monitoring/orchestration network (FR-017)
- S6 blocked until backup taken, restore test succeeded, and sponsor approval given (FR-023)
- GitHub issues #2, #3, #5 explicitly out of scope (spec Assumptions)
- Constitution Section I amendment deferred until migration is ratified (spec Assumptions)

**Scale/Scope**:
- 5 epics, 54 stories, 6 waves (W0–W5) as defined in the work plan
- 55 locked specs, 2 KPIs
- Two production services + petclinic-ui artifact + edge router + migration job
- 3 supported database engines (H2, MySQL, PostgreSQL)
- 11 i18n message bundles
- Staged migration: S2 (multi-module build), S3 (route flip), S4 (vet code removal from Owners image), S5 (optional vet schema copy), S6 (optional table drop)

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Gate 1 — Modular Monolith Architecture (Section I)

**Principle**: The application MUST be structured as a modular monolith with server-side rendering via Thymeleaf. Package boundaries MUST be respected. Cross-package dependencies MUST be introduced only when explicitly justified and reviewed.

**Assessment**: **VIOLATION — JUSTIFIED**. This feature intentionally transitions the architecture from a modular monolith to two independently deployable services. The constitution's Section I describes the pre-split state. The spec's Assumptions section explicitly acknowledges this: "The constitution's Modular Monolith Architecture principle (Section I) describes the pre-split state. After this feature is complete, the architecture transitions to two independently deployable services. The constitution will require amendment to reflect the new architecture once the migration is ratified by the maintainer." The violation is the stated purpose of the feature and has been accepted by the spec author. A constitution amendment is required as a follow-on task after ratification (research item 22).

**Justification recorded**: The split is the primary deliverable. The constitution is an unratified draft (Version 1.0.0, Status: Unratified draft). The amendment is planned and out of scope for this implementation.

### Gate 2 — Business-Rule Integrity (Section II)

**Principle**: Domain rules (Pet belongs to one Owner, Visit is append-only, Owner telephone regex `\d{10}`, etc.) MUST be enforced verbatim. No separate standalone validator classes that duplicate or contradict domain-embedded constraints.

**Assessment**: **PASS**. FR-007 requires `Owner.java` to move with no change to its content, including the telephone regex and all `@NotBlank` rules. FR-008 requires Visit to be append-only with no delete route or repository method. FR-009 requires the unique constraint on `(owner_id, name)` on `pets` to exist on all three engines at every stage. The split does not alter any business rule; it redistributes the classes that enforce them.

### Gate 3 — Sensitive Data Handling (Section III)

**Principle**: Owner `name`, `address`, and `telephone` fields MUST NOT be exposed in unprotected endpoints, error pages, stack traces, or actuator outputs. Logging of Owner sensitive fields is prohibited.

**Assessment**: **PASS with active controls required**. FR-022 and SC-005 prohibit owner PII from appearing in any Vets-side artefact. FR-020 requires the Vets database role to be denied SELECT on owner tables. E5-S6 requires query strings (owner last-name search) to be masked at the edge. E5-S2 requires no owner values in metric tags. The plan enforces these controls at the database role level, the edge log-masking level, and the CI artefact scan level. No new exposure is introduced; existing protections are preserved and strengthened.

### Gate 4 — Profile-Aware Persistence (Section IV)

**Principle**: H2 for dev/test; MySQL and PostgreSQL for production-representative environments. Schema management via Spring Data JPA/Hibernate DDL or versioned scripts appropriate to the active profile. Manual schema changes MUST NOT be applied outside the profile-managed mechanism.

**Assessment**: **PASS with clarification required**. FR-019 requires `spring.sql.init.mode=never` against persistent stores and DDL only via the migration job. The H2 profile is retained for dev/CI with each service initialising only its own table subset. The migration job tool (Flyway, Liquibase, or custom SQL) is NEEDS CLARIFICATION (research item 8a) and must be resolved in E2-S3 before the migration job is designed. The real MySQL and PostgreSQL schema scripts have not been read (DEF-8); E2-S3 must read them first. No manual schema changes are introduced.

### Gate 5 — Service-Layer Caching Contract (Section V)

**Principle**: `@Cacheable` MUST be applied at the service/repository layer for vet lookups via `VetRepository`. Cache configuration MUST be managed exclusively in `CacheConfiguration`. Controllers MUST NOT implement their own caching logic for vet data.

**Assessment**: **PASS**. FR-006 retains `@Cacheable("vets")` on `VetRepository.findAll` in the Vets service only, backed by `CacheConfiguration`, with cache statistics enabled and no eviction added. The Owners service has no cache named "vets". Research item 10 confirms this is a direct carry-forward of the existing implementation.

### Gate 6 — Scope Boundary Enforcement (Section VI)

**Principle**: Billing, payment, inventory, insurance, and multi-clinic capabilities MUST NOT be introduced.

**Assessment**: **PASS**. This feature introduces no out-of-scope capabilities. The split is purely structural.

### Gate 7 — Observability and Health (Section VII)

**Principle**: Health checks and metrics MUST be exposed via Spring Boot Actuator and Micrometer. Actuator endpoints MUST NOT expose sensitive Owner data. Observability configuration MUST NOT be removed or disabled without an ADR.

**Assessment**: **PASS with accepted change**. FR-016 limits actuator exposure to `health,info,metrics,prometheus` on a dedicated management port. This removes `include=*` from the public host, which is a breaking change from the current monolith configuration. This change is recorded as an accepted change requiring explicit sponsor agreement before S3 (E1-S3, ADR-APP-9, DEF-6). The change strengthens rather than weakens observability security. The management port retains full observability for the monitoring network.

### Post-Phase-1 Re-check

After Phase 1 design artefacts (data-model.md, contracts/, quickstart.md) are complete, Gates 2, 3, and 4 must be re-evaluated against the concrete entity definitions, contract schemas, and H2 initialisation scripts to confirm no regression has been introduced.

---

## Project Structure

### Documentation (this feature)

```text
specs/009-split-petclinic-into-microserv-bbbd6b99/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── vets-http.md     # HTTP contract for GET /vets and GET /vets.html
│   ├── owners-http.md   # HTTP contract for owner, pet, visit routes
│   └── routing-table.md # Edge routing table contract
└── tasks.md             # Phase 2 output (/speckit-tasks command — NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
# Multi-module Maven layout (post-split target state)

pom.xml                          # Root POM; coordinates build; no deployable artifact
mvnw / mvnw.cmd                  # Maven wrapper (retained; no external Maven required)

vets/                            # Vets service module
├── pom.xml
└── src/
    ├── main/
    │   ├── java/
    │   │   └── org/springframework/samples/petclinic/
    │   │       ├── VetsApplication.java          # Service entry point
    │   │       ├── vet/                          # Vet, Specialty, VetController, VetRepository
    │   │       └── system/                       # CacheConfiguration, WebConfiguration (CookieLocaleResolver)
    │   └── resources/
    │       ├── application.properties            # management port, spring.sql.init.mode=never
    │       ├── application-h2.properties         # H2 profile; initialises vets/specialties/vet_specialties only
    │       ├── application-mysql.properties
    │       ├── application-postgres.properties
    │       └── db/
    │           ├── h2/
    │           │   ├── schema.sql                # Vets table subset for H2
    │           │   └── data.sql                  # Vets seed data for H2
    │           ├── mysql/
    │           │   └── schema.sql                # Vets table subset for MySQL (migration job only)
    │           └── postgres/
    │               └── schema.sql                # Vets table subset for PostgreSQL (migration job only)
    └── test/
        └── java/
            └── org/springframework/samples/petclinic/
                ├── vet/
                │   └── VetControllerTests.java
                ├── service/
                │   └── ClinicServiceTests.java   # Vet-side methods only (verbatim)
                ├── MySqlIntegrationTests.java    # Vets tables only
                └── PostgresIntegrationTests.java # Vets tables only

owners/                          # Owners service module
├── pom.xml
└── src/
    ├── main/
    │   ├── java/
    │   │   └── org/springframework/samples/petclinic/
    │   │       ├── OwnersApplication.java        # Service entry point
    │   │       ├── owner/                        # Owner, Pet, PetType, Visit, controllers, repositories
    │   │       └── system/                       # WebConfiguration (CookieLocaleResolver), CrashController
    │   └── resources/
    │       ├── application.properties            # management port, spring.sql.init.mode=never
    │       ├── application-h2.properties         # H2 profile; initialises owners/pets/visits/types only
    │       ├── application-mysql.properties
    │       ├── application-postgres.properties
    │       └── db/
    │           ├── h2/
    │           │   ├── schema.sql                # Owners table subset for H2
    │           │   └── data.sql                  # Owners seed data for H2
    │           ├── mysql/
    │           │   └── schema.sql                # Owners table subset for MySQL (migration job only)
    │           └── postgres/
    │               └── schema.sql                # Owners table subset for PostgreSQL (migration job only)
    └── test/
        └── java/
            └── org/springframework/samples/petclinic/
                ├── owner/
                │   ├── OwnerControllerTests.java
                │   ├── PetControllerTests.java
                │   └── VisitControllerTests.java
                ├── system/
                │   └── CrashControllerTests.java
                ├── service/
                │   └── ClinicServiceTests.java   # Owner-side methods only (verbatim)
                ├── PetClinicIntegrationTests.java
                ├── PetClinicConcurrencyTests.java
                ├── MySqlIntegrationTests.java    # Owners tables only
                └── PostgresIntegrationTests.java # Owners tables only

petclinic-ui/                    # Shared UI artifact module
├── pom.xml
└── src/
    └── main/
        └── resources/
            ├── templates/
            │   ├── layout.html
            │   ├── error.html
            │   └── welcome.html
            ├── static/
            │   └── resources/   # CSS, JS, images (/resources/**)
            └── messages/
                └── messages_*.properties  # All 11 i18n bundles

migration/                       # Migration job module (DDL-only; not a runtime service)
├── pom.xml
└── src/
    └── main/
        └── resources/
            └── db/
                ├── mysql/
                │   ├── V1__vets_schema.sql
                │   └── V1__owners_schema.sql
                └── postgres/
                    ├── V1__vets_schema.sql
                    └── V1__owners_schema.sql

edge/                            # Edge router configuration (technology TBD — see research item 5a)
└── routing-table.[yml|conf]     # Authoritative routing table; reviewed file in repository (FR-010)

k8s/                             # Kubernetes manifests
├── vets/
│   ├── deployment.yaml
│   ├── service.yaml             # ClusterIP; application port only (management port not exposed)
│   └── networkpolicy.yaml       # Management port → monitoring namespace only
├── owners/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── networkpolicy.yaml
├── edge/
│   └── [edge-specific manifests]
└── migration/
    └── job.yaml

.github/
└── workflows/
    ├── pr-verify.yml            # Full KPI-2 suite, import check, actuator exposure test, Sonar
    ├── deploy-vets.yml          # Path-filtered: vets/** triggers only this workflow
    ├── deploy-owners.yml        # Path-filtered: owners/** triggers only this workflow
    ├── deploy-edge.yml          # Edge configuration changes
    ├── deploy-petclinic-ui.yml  # petclinic-ui publish workflow
    └── kpi-1-report.yml         # Scheduled; reads GitHub Deployment records

# Pre-split monolith (current state; retained until S4)
src/
├── main/
│   └── java/
│       └── org/springframework/samples/petclinic/
│           ├── PetClinicApplication.java
│           ├── vet/
│           ├── owner/
│           └── system/
└── test/
    └── java/
        └── org/springframework/samples/petclinic/
            ├── vet/
            ├── owner/
            └── system/
```

**Structure Decision**: Maven multi-module layout with four modules (`vets`, `owners`, `petclinic-ui`, `migration`) plus a root POM. The existing `src/` monolith tree is retained until S4 (E1-S12). The `edge/` directory holds the routing table as a reviewed file in the repository (FR-010). The `.github/workflows/` directory holds path-filtered deploy workflows (FR-002, E4-S3). Exact workflow file names are illustrative and must be confirmed in E4-S3 (research item 6a). The migration module file names use Flyway-style versioned scripts as a placeholder; the actual tool is NEEDS CLARIFICATION (research item 8a).

---

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Constitution Section I (Modular Monolith) — intentional architectural transition | The primary deliverable is two independently deployable services so that Vets and Owners teams can release separately (KPI-1). The monolith structure is the pre-split state being replaced. | Keeping the monolith satisfies Section I but does not deliver the feature. The constitution is an unratified draft and explicitly anticipates this amendment (spec Assumptions). |
| Actuator exposure change (`include=*` → `health,info,metrics,prometheus` on management port only) — accepted breaking change | FR-016 and ADR-APP-9 require this. Exposing `env`, `heapdump`, `beans`, and `configprops` on the public host risks leaking owner data (constitution Section III). | Retaining `include=*` violates FR-016 and the sensitive data principle. The change requires explicit sponsor agreement before S3 (E1-S3). |
| No shared Java library (model classes copied verbatim into each module) — duplication by design | FR-001 explicitly prohibits a shared Java library. The two domains are genuinely independent after the split; no entity is shared at runtime. | A shared `model` module would violate FR-001. A shared module published as a versioned artifact also violates FR-001 (it is still a shared library). |
