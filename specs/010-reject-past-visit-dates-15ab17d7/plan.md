# Implementation Plan: Reject Past Visit Dates

**Branch**: `010-reject-past-visit-dates-15ab17d7` | **Date**: 2026-10-26 | **Spec**: `/specs/010-reject-past-visit-dates/spec.md`

**Input**: Feature specification from `/specs/010-reject-past-visit-dates/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Add a server-side past-date rejection rule to `VisitController.processNewVisitForm`: if the bound `visit.date` is non-null and before `LocalDate.now()`, call `result.rejectValue("date", "visit.date.pastNotAllowed", "Visit date must be today or in the future.")` and fall through to the existing `result.hasErrors()` guard. Update `initNewVisitForm` to set `minVisitDate` to `LocalDate.now()` (was `plusDays(1)`). Replace the single existing past-date test in `VisitControllerTests` with one time-relative test that asserts rejection for yesterday and acceptance for today. Only `VisitController.java` and `VisitControllerTests.java` are modified; all other files remain byte-identical.

## Technical Context

**Language/Version**: Java 17 (Spring Boot 3.x; exact Boot version from `pom.xml` — confirmed Spring MVC / Thymeleaf stack)

**Primary Dependencies**: Spring MVC (`@WebMvcTest`), Spring Data JPA (`OwnerRepository`), Thymeleaf (server-side rendering), JUnit 5 + Mockito (test layer), Maven Wrapper (`mvnw`)

**Storage**: H2 in-memory (dev/test profile); MySQL and PostgreSQL (production profiles, Testcontainers for integration tests). No schema or seed changes in this story.

**Testing**: JUnit 5 with `@WebMvcTest` slice tests and Mockito `@MockBean`; `mvn test -pl . -Dtest=VisitControllerTests` for targeted run; full suite via `mvn test`

**Target Platform**: JVM server (Linux CI via GitHub Actions); GraalVM native image compatibility maintained via existing `PetClinicRuntimeHints` (no new hints required for this change)

**Project Type**: Modular monolith web application (Spring MVC + Thymeleaf server-side rendering)

**Performance Goals**: No new performance requirements. The added comparison is a single `LocalDate.isBefore` call on an already-bound object; negligible overhead.

**Constraints**: Only `VisitController.java` and `VisitControllerTests.java` may be modified (FR-007, SC-002). `Visit.java` must remain byte-identical. No template, message bundle, schema, seed, Kubernetes, or CI file may be changed. `spring-javaformat:validate` and `nohttp` checkstyle must pass with no new suppressions (SC-003).

**Scale/Scope**: Single controller method change + single test replacement. Two files, one commit.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Gate 1 — Modular Monolith Architecture (Principle I)

**Status**: PASS

The change is confined to `VisitController.java` in the `owner` package, which already owns Visit-related controller logic. No new cross-package dependency is introduced. The controller continues to return a model attribute consumed by the existing Thymeleaf template. No REST-only pattern is introduced.

### Gate 2 — Business-Rule Integrity (Principle II)

**Status**: PASS WITH RECORDED EXCEPTION

Principle II mandates that validation be enforced via Jakarta Bean Validation annotations on domain classes and prohibits standalone validator classes. This change places the past-date rule in the controller rather than on `Visit.java`.

**Violation**: The past-date check is not a Jakarta Bean Validation annotation on `Visit.date`.

**Justification (ADR-APP-1, ADR-APP-2)**: FR-007 requires `Visit.java` to remain byte-identical; adding `@FutureOrPresent` is therefore prohibited. A standalone `VisitValidator` class is also prohibited by Principle II itself. The constitution is an unratified draft (Version 1.0.0, Status: Unratified draft); the approved brief and the feature spec's Assumptions section explicitly record this as a deliberate, scoped exception and state the approved brief takes precedence. The exception is the minimum necessary deviation: no other file is affected, and the rule is enforced server-side before any persistence call.

### Gate 3 — Sensitive Data Handling (Principle III)

**Status**: PASS

The change reads `visit.date` (a non-sensitive appointment date) and calls `result.rejectValue`. No Owner name, address, or telephone number is read, logged, or exposed. The error message `"Visit date must be today or in the future."` contains no request data.

### Gate 4 — Profile-Aware Persistence (Principle IV)

**Status**: PASS

No schema file, seed file, or database migration is introduced (FR-012). The past-date check is applied only at the controller layer; existing past-dated rows in H2, MySQL, and PostgreSQL seed data remain readable and are not affected. `ClinicServiceTests` (which saves a `new Visit()` with a future default date directly via `OwnerRepository`) is unaffected because the check lives only in the controller.

### Gate 5 — Service-Layer Caching Contract (Principle V)

**Status**: PASS — NOT APPLICABLE

This change does not touch veterinarian data, `VetRepository`, or `CacheConfiguration`. No cache impact.

### Gate 6 — Scope Boundary Enforcement (Principle VI)

**Status**: PASS

The change is a date-validation rule on the visit form. It does not introduce billing, payment, inventory, insurance, or multi-location functionality.

### Gate 7 — Observability and Health (Principle VII)

**Status**: PASS — NOT APPLICABLE

No Actuator endpoint, Micrometer metric, or health-check configuration is changed.

### Gate 8 — Internationalisation Constraint (Technology Stack)

**Status**: PASS WITH RECORDED DEVIATION (DEF-5)

The constitution states all user-facing strings in Thymeleaf templates must be externalised to `messages_*.properties` files and that `I18nPropertiesSyncTest` must pass.

**Deviation**: The error message `"Visit date must be today or in the future."` is supplied as the `defaultMessage` argument to `result.rejectValue` in Java, not as a properties-file key. No `messages*.properties` file is edited.

**Justification**: FR-003 and FR-007 explicitly prohibit editing any `messages*.properties` file. The message is not rendered via a Thymeleaf `#{...}` expression in the template; it surfaces through Spring MVC's `BindingResult` default-message mechanism. `I18nPropertiesSyncTest` passes because no new key is introduced to any properties file (R-013). The accepted deviation (DEF-5) records that non-English locales will display the English text; a follow-up story will add the key to all locale bundles with `I18nPropertiesSyncTest` coverage.

### Gate 9 — Testing Requirements (Development Workflow)

**Status**: PASS

The change replaces one `@WebMvcTest` test with one new `@WebMvcTest` test, keeping the total at 5 tests in `VisitControllerTests`. The new test uses `LocalDate.now()` at runtime (FR-006). `OwnerRepository` is mocked via `@MockBean`; `verify(ownerRepository, never()).save(any())` confirms no save on rejection; `verify(ownerRepository, times(1)).save(any())` confirms save on acceptance. The full suite (`ClinicServiceTests`, `PetClinicIntegrationTests`, `OwnerControllerTests`, `PetControllerTests`, `I18nPropertiesSyncTest`) passes with no assertion edits to any file other than `VisitControllerTests.java` (SC-001, R-012, R-013).

### Post-Phase-1 Re-check

All gates remain in the same state after Phase 1 design. No design artifact introduces a new dependency, entity, schema change, or cross-package reference. The Complexity Tracking table below records the single justified violation.

## Project Structure

### Documentation (this feature)

```text
specs/010-reject-past-visit-dates/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
src/
├── main/
│   └── java/
│       └── org/springframework/samples/petclinic/
│           └── owner/
│               ├── VisitController.java          ← MODIFIED (past-date check + minVisitDate)
│               ├── Visit.java                    ← READ ONLY; byte-identical after change
│               ├── OwnerRepository.java          ← READ ONLY; no change
│               ├── Owner.java                    ← READ ONLY; no change
│               ├── Pet.java                      ← READ ONLY; no change
│               └── PetController.java            ← READ ONLY; no change
└── test/
    └── java/
        └── org/springframework/samples/petclinic/
            └── owner/
                └── VisitControllerTests.java     ← MODIFIED (replace one test method)

src/main/resources/
├── messages.properties                           ← NOT CHANGED
├── messages_de.properties                        ← NOT CHANGED
└── templates/
    └── pets/
        └── createOrUpdateVisitForm.html          ← NOT CHANGED (reads minVisitDate dynamically)

src/main/resources/db/                            ← NOT CHANGED (no schema/seed changes)
k8s/                                              ← NOT CHANGED
.github/                                          ← NOT CHANGED
pom.xml                                           ← NOT CHANGED
```

**Structure Decision**: Single-project Maven layout. The feature touches exactly two files within the existing `owner` package. No new packages, modules, or directories are created. All other source, resource, and configuration files are read-only for this change.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Past-date rule in `VisitController` rather than as a Jakarta Bean Validation annotation on `Visit.date` (Principle II) | FR-007 requires `Visit.java` to remain byte-identical; a standalone `VisitValidator` class is also prohibited by Principle II | `@FutureOrPresent` on `Visit.date` is the constitutionally preferred approach but is blocked by an explicit, approved requirement constraint; no permitted location other than the controller exists |
