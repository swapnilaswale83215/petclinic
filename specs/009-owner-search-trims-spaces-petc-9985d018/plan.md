# Implementation Plan: Owner Search Trims Spaces

**Branch**: `009-owner-search-trims-spaces-petc-9985d018` | **Date**: 2026-10-18 | **Spec**: `/specs/009-owner-search-trims-spaces-petc-9985d018/spec.md`

**Input**: Feature specification from `/specs/009-owner-search-trims-spaces-petc-9985d018/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

---

## Summary

A clinic receptionist pasting an owner's last name into the Find Owners search box may inadvertently include leading or trailing whitespace. The current behaviour returns no results for a padded term such as "Davis " even though owners named Davis exist, causing the receptionist to believe the owner is absent. The fix removes all leading and trailing Unicode whitespace from the `lastName` search parameter exactly once, at the top of `OwnerController.processFindForm`, before any branch — repository lookup, single-match redirect, out-of-range redirect, or no-match error path — so that every padded variant produces the same result as the equivalent trimmed term.

The working assumption (Case A) is that the cached controller at commit 3266d9f already contains the `String.strip()` call, meaning the defect is already corrected in production code and the pull request consists of one file only: a new `@Test` method `processFindFormPaddedTermMatchesTrimmedTermForMultipleOwners` added to `OwnerControllerTests`. This assumption is conditional on the SPEC-APP-6 reproduction record (E1-S1, E1-S2), which has not yet been completed. All code work is gated on that record. If Case B or Case C is revealed, the plan does not hold and must return to the G0 owner before G1 is signed.

The new test submits the three padded Davis variants and the trimmed term against a mocked `OwnerRepository`, asserts identical view name and model attributes for each, and uses Mockito to verify the repository is called only with `"Davis"` and never with a padded value. This constitutes the machine-verifiable evidence for KPI-1. KPI-2 (100 % pass rate) is satisfied by leaving all existing tests unmodified.

---

## Technical Context

**Language/Version**: Java 17 (Spring Boot 3.x minimum; `String.strip()` available since Java 11)

**Primary Dependencies**:
- Spring Boot (Spring MVC, Spring Data JPA, Thymeleaf)
- JUnit 5 (`@WebMvcTest`, `@Test`)
- Mockito (mocked `OwnerRepository` in `OwnerControllerTests`)
- MockMvc (HTTP layer simulation in `@WebMvcTest`)
- H2 (in-memory database for dev/test profile)

**Storage**: H2 (dev/test); MySQL and PostgreSQL (production profiles, profile-activated). No storage change in this pull request. Seed data contains Betty Davis (id 2) and Harold Davis (id 4).

**Testing**: JUnit 5 + Mockito + MockMvc via `@WebMvcTest`. Maven Wrapper (`mvnw`) or Gradle Wrapper (`gradlew`). CI via GitHub Actions.

**Target Platform**: JVM / Linux server (GitHub Actions CI runner). No platform change.

**Project Type**: Modular monolith web application (Spring MVC + Thymeleaf server-side rendering).

**Performance Goals**: No new performance requirement. Page size fixed at 5; out of scope.

**Constraints**:
- Pull request diff limited to `OwnerControllerTests.java` under Case A (at most `OwnerController.java` + `OwnerControllerTests.java` under Case B).
- No change to `OwnerRepository`, templates, build files, schema, seed, CI workflow, or deployment artefacts.
- `String.strip()` must be used (not `String.trim()`) to handle U+00A0 and other Unicode whitespace.
- No Owner sensitive field (name, address, telephone) may appear in any new log statement, model attribute, redirect parameter, or error message.

**Scale/Scope**: Single controller method (`processFindForm`), one new test method, one production file at most. Minimal blast radius by design.

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

### Gate 1 — Modular Monolith Architecture (Principle I)

**Status**: PASS

The change is confined to the `owner` package (`OwnerController`, `OwnerControllerTests`). No cross-package dependency is introduced. The controller continues to return model attributes consumed by Thymeleaf templates; no REST API behaviour is added. Templates are not modified.

### Gate 2 — Business-Rule Integrity (Principle II)

**Status**: PASS

No domain rule is altered. The `Owner` entity, `Pet`, `Visit`, `PetType`, and `Veterinarian` are untouched. No new validator class is introduced. The trimming of the search parameter is a controller-layer input normalisation, not a domain constraint change. Jakarta Bean Validation annotations in domain classes are unaffected.

### Gate 3 — Sensitive Data Handling (Principle III)

**Status**: PASS (with reviewer verification required)

The new test uses only synthetic owner values already present in the test class (last name "Davis", ids 2 and 4). No real owner name, address, or telephone number is introduced. No new log statement, model attribute, redirect parameter, or error message carries any Owner sensitive field. The reviewer must confirm at pull request time that the diff contains no `logger.*`, `System.out`, or new model attribute referencing the raw padded term. FR-008 and SPEC-SEC-1 enforce this.

### Gate 4 — Profile-Aware Persistence (Principle IV)

**Status**: PASS

No schema, seed, migration, entity, or repository change. H2, MySQL, and PostgreSQL profiles are unaffected. `ClinicServiceTests` and `PetClinicConcurrencyTests` (which exercise `OwnerRepository.findByLastNameStartingWith`) are not modified and must pass unchanged.

### Gate 5 — Service-Layer Caching Contract (Principle V)

**Status**: PASS (not applicable)

The caching contract applies to veterinarian lookups via `VetRepository`. The owner search path does not use `@Cacheable`. `CacheConfiguration` is not modified.

### Gate 6 — Scope Boundary Enforcement (Principle VI)

**Status**: PASS

The change introduces no billing, payment, inventory, insurance, or multi-location functionality. It is a narrow input-normalisation fix within the existing owner search flow.

### Gate 7 — Observability and Health (Principle VII)

**Status**: PASS (with residual risk noted)

No Actuator endpoint, Micrometer metric, or health check is modified. The residual exposure (`include=*` actuator configuration, THR-5 unauthenticated `/owners`, THR-6 no audit log, THR-7 no server-side length limit) is pre-existing and out of scope for this pull request. These are recorded in research.md (R-015) and require explicit accept/reject from the G1 approver. No new observability configuration is added or removed.

### Gate 8 — Testing Requirements (Constitution: Development Workflow)

**Status**: PASS

The new test follows the mandated `@WebMvcTest` + Mockito pattern for controller tests. No existing test method is modified, removed, or skipped. The full suite must pass on the H2 profile in CI on the pull request. `ClinicServiceTests` and `PetClinicConcurrencyTests` are unaffected. The `I18nPropertiesSyncTest` is unaffected (no new UI strings). `PetClinicRuntimeHints` is unaffected (no new reflection or serialisation).

### Gate 9 — CI Pipeline (Constitution: Development Workflow)

**Status**: PASS

No change to the GitHub Actions workflow, `pom.xml`, `build.gradle`, Docker files, or `application*.properties`. The existing pipeline runs format check, checkstyle, and the full test suite without modification. FR-012 enforces this.

### Gate 10 — Internationalisation (Constitution: Technology Stack)

**Status**: PASS (not applicable)

No new user-facing string is introduced in any Thymeleaf template. `findOwners.html` and `ownersList.html` are not modified. The `I18nPropertiesSyncTest` is unaffected.

### Constitution Check — Post-Phase 1 Re-evaluation

All gates remain PASS after Phase 1 design. The data model introduces no new entity or relationship. The contracts section documents the unchanged GET /owners HTTP contract. The quickstart confirms the validation scenarios are exercisable with the existing toolchain and no new infrastructure. No gate status changes.

---

## Project Structure

### Documentation (this feature)

```text
specs/009-owner-search-trims-spaces-petc-9985d018/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── get-owners.md
└── tasks.md             # Phase 2 output (/speckit-tasks command — NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
src/
└── main/
    └── java/
        └── org/springframework/samples/petclinic/
            └── owner/
                └── OwnerController.java          # processFindForm — strip() call lives here
                                                  # (in diff only under Case B)

src/
└── test/
    └── java/
        └── org/springframework/samples/petclinic/
            └── owner/
                └── OwnerControllerTests.java     # New test method added here (always in diff)

src/
└── main/
    └── resources/
        ├── templates/owner/
        │   ├── findOwners.html                   # NOT modified
        │   └── ownersList.html                   # NOT modified
        └── db/
            ├── h2/
            │   ├── schema.sql                    # NOT modified
            │   └── data.sql                      # NOT modified
            ├── mysql/                            # NOT modified
            └── postgres/                         # NOT modified

.github/
└── workflows/                                    # NOT modified

pom.xml (or build.gradle)                         # NOT modified
```

**Structure Decision**: Single-project Spring Boot monolith. The only files touched are within `src/test/.../owner/OwnerControllerTests.java` (always) and `src/main/.../owner/OwnerController.java` (Case B only). All other source, resource, build, and infrastructure files are explicitly out of scope per FR-009 and FR-012.

---

## Complexity Tracking

No constitution violations requiring justification. All gates pass. No complexity exceptions are needed for this change.
