# Implementation Plan: Reject Past Visit Dates

**Branch**: `010-reject-past-visit-dates-15ab17d7` | **Date**: 2026-10-26 | **Spec**: `/specs/010-reject-past-visit-dates-15ab17d7/spec.md`

**Input**: Feature specification from `/specs/010-reject-past-visit-dates-15ab17d7/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

On the main branch of the Spring PetClinic application, `VisitController.processNewVisitForm` must reject any POST submission whose `date` field is before `LocalDate.now()` (JVM default time zone). Rejection returns HTTP 200 with the form view `pets/createOrUpdateVisitForm` and registers a `BindingResult` field error on `date` with error code `visit.date.pastNotAllowed` and the exact default message `"Visit date must be today or in the future."`. Submissions dated today or later continue to save and redirect as before. The `minVisitDate` model attribute in `initNewVisitForm` is updated from tomorrow to today so the form hint matches the server rule. The existing test `processNewVisitFormHasErrorsWhenVisitDateIsNotInFuture` is replaced by one time-relative test that asserts both rejection (yesterday) and acceptance (today). Exactly two files change: `VisitController.java` and `VisitControllerTests.java`.

The technical approach, established by research.md, is an imperative null-guarded check inserted in `processNewVisitForm` before the `result.hasErrors()` guard, using `result.rejectValue("date", "visit.date.pastNotAllowed", "Visit date must be today or in the future.")`. No entity annotation, no standalone validator, no properties-file edit, and no schema change are introduced.

## Technical Context

**Language/Version**: Java 17 (Spring Boot 3.x; exact Boot version NEEDS CLARIFICATION — assumed 3.2.x based on standard PetClinic main-branch lineage)

**Primary Dependencies**:
- Spring MVC (`@Controller`, `@ModelAttribute`, `BindingResult`, `@InitBinder`)
- Spring Data JPA (`OwnerRepository`)
- Thymeleaf (server-side rendering; template unchanged)
- Jakarta Bean Validation (present on classpath; not used for this change per ADR-APP-1/ADR-APP-2)
- JUnit 5 + Spring `@WebMvcTest` + Mockito (test layer)
- Maven Wrapper (`mvnw`); `spring-javaformat` and `nohttp` checkstyle plugins active

**Storage**: H2 in-memory (dev/test profile); MySQL and PostgreSQL (production profiles, profile-activated). No schema or seed change introduced by this feature.

**Testing**: JUnit 5 via `@WebMvcTest`; Mockito for repository mocking; Maven Surefire for report generation. Target: `VisitControllerTests` reports 5 tests, 0 failures, 0 errors.

**Target Platform**: JVM (Linux server in CI via GitHub Actions; local dev on any OS with JVM default time zone determining "today").

**Project Type**: Web application — modular monolith with Spring MVC + Thymeleaf server-side rendering.

**Performance Goals**: No new performance requirement. The added check is a single `LocalDate` comparison; negligible overhead.

**Constraints**:
- Exactly two files modified: `src/main/java/.../owner/VisitController.java` and `src/test/java/.../owner/VisitControllerTests.java`.
- `Visit.java` byte-identical before and after.
- No `messages*.properties` file edited.
- No template, schema, seed, Kubernetes manifest, CI configuration, or `pom.xml` changed.
- `@InitBinder` `setAllowedFields` body unchanged.
- `spring-javaformat:validate` and `nohttp` checkstyle must pass with no new suppressions.
- `I18nPropertiesSyncTest` must pass without modification.

**Scale/Scope**: Single controller method change + single test method replacement. No new classes, no new files outside the spec directory.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

---

### Gate 1 — Modular Monolith Architecture (Principle I)

**Rule**: Controllers MUST return model attributes consumed by Thymeleaf templates; the application MUST NOT be treated as a pure REST API. Package boundaries MUST be respected.

**Assessment**: PASS. The change is confined to `VisitController` in the `owner` package. The controller continues to return the Thymeleaf view `pets/createOrUpdateVisitForm` on error and a redirect on success. No new cross-package dependency is introduced. No REST endpoint is added.

---

### Gate 2 — Business-Rule Integrity / Bean Validation on Domain Classes (Principle II)

**Rule**: Validation MUST be enforced via Jakarta Bean Validation annotations embedded directly in domain classes. No separate standalone validator classes MUST be introduced that duplicate or contradict domain-embedded constraints.

**Assessment**: VIOLATION — justified exception recorded.

**Violation**: The past-date check is placed in `VisitController.processNewVisitForm` as an imperative `result.rejectValue(...)` call rather than as a Jakarta Bean Validation annotation on `Visit.date`.

**Justification (ADR-APP-1, ADR-APP-2, recorded in spec assumptions)**:
1. FR-007 prohibits any modification to `Visit.java`; a bean-validation annotation on `Visit.date` requires modifying that file.
2. An entity-level annotation (e.g., `@FutureOrPresent`) would fire on persistence of existing past-dated rows in seed data, violating FR-012.
3. It would also cause `ClinicServiceTests.shouldAddNewVisitForPet` to fail if the annotation were enforced at the persistence layer, because that test saves a `new Visit()` whose default date is tomorrow — a future date that passes the rule — but the broader risk of entity-level enforcement on historical data is disqualifying regardless.
4. A standalone `VisitValidator` class is prohibited by Principle II itself (no standalone validator classes that duplicate domain-embedded constraints) and would also require a third file outside the permitted change set.
5. The constitution is an unratified draft (governance section, §Ratification); the approved brief and locked spec take precedence for this scoped change.

**Mitigation**: The exception is explicitly documented in the spec's assumptions section and in research.md §13. It is scoped to this feature only and does not establish a general precedent.

---

### Gate 3 — Sensitive Data Handling (Principle III)

**Rule**: Owner sensitive fields (name, address, telephone) MUST NOT be exposed in unprotected endpoints, error pages, stack traces, or actuator outputs. Logging of Owner sensitive fields is prohibited.

**Assessment**: PASS. The change adds a date comparison and a `BindingResult` field error. No Owner sensitive field is read, logged, or exposed by the new code. The error message `"Visit date must be today or in the future."` contains no request data.

---

### Gate 4 — Profile-Aware Persistence (Principle IV)

**Rule**: Schema management MUST be handled via profile-managed mechanisms. No manual schema changes outside the profile-managed mechanism.

**Assessment**: PASS. No schema file, seed file, or database migration is introduced. Past-dated rows in H2, MySQL, and PostgreSQL seed data remain readable and writable. The check is controller-layer only.

---

### Gate 5 — Service-Layer Caching Contract (Principle V)

**Rule**: Caching for veterinarian lookups MUST be managed exclusively in `CacheConfiguration`. Controllers MUST NOT implement their own caching logic for veterinarian data.

**Assessment**: PASS. This change does not touch veterinarian data, `VetRepository`, or `CacheConfiguration`.

---

### Gate 6 — Scope Boundary Enforcement (Principle VI)

**Rule**: Billing, invoicing, payment, inventory, insurance, and multi-location capabilities MUST NOT be introduced.

**Assessment**: PASS. The change is a visit-date validation rule. None of the prohibited capability areas are touched.

---

### Gate 7 — Observability and Health (Principle VII)

**Rule**: Actuator endpoints and Micrometer metrics MUST remain active and correctly configured.

**Assessment**: PASS. No observability configuration is changed.

---

### Gate 8 — Internationalisation (Technology Stack constraint)

**Rule**: All user-facing strings displayed in Thymeleaf templates MUST be externalised to `messages*.properties` files. `I18nPropertiesSyncTest` MUST pass.

**Assessment**: PASS with noted nuance. The error message `"Visit date must be today or in the future."` is a Java default message passed directly to `BindingResult.rejectValue`; it is not a Thymeleaf `#{...}` key reference and introduces no new entry in any properties file. `I18nPropertiesSyncTest` checks template key references against properties files; a Java-only default message is outside that scan scope (confirmed by research.md §8). No `messages*.properties` file is edited.

**NC-4 residual**: If `I18nPropertiesSyncTest` also scans Java source for error codes, it might flag `visit.date.pastNotAllowed`. The implementer must read `I18nPropertiesSyncTest.java` to confirm the scan scope before finalising (see NC-4 in research.md §14).

---

### Gate 9 — Testing Requirements (Development Workflow)

**Rule**: Unit tests MUST be provided for all controller classes using `@WebMvcTest` with Mockito-based mocking of repositories. The full test suite MUST pass on the H2 profile in CI on every pull request.

**Assessment**: PASS. The replacement test in `VisitControllerTests` uses `@WebMvcTest` and Mockito. The surefire report must show 5 tests, 0 failures, 0 errors. All other test classes (`ClinicServiceTests`, `PetClinicIntegrationTests`, `OwnerControllerTests`, `PetControllerTests`, `I18nPropertiesSyncTest`) are unmodified and must continue to pass.

---

### Post-Phase-1 Re-check

All gates above remain in the same state after Phase 1 design. The data model introduces no new entity fields or annotations. The contracts section documents the existing controller endpoint contract without changing it. The quickstart confirms the two-file diff scope. No new violation is introduced by the design artifacts.

## Project Structure

### Documentation (this feature)

```text
specs/010-reject-past-visit-dates-15ab17d7/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── visit-form-post.md
└── tasks.md             # Phase 2 output (/speckit-tasks command — NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
src/
├── main/
│   └── java/
│       └── org/springframework/samples/petclinic/
│           └── owner/
│               ├── VisitController.java          ← MODIFIED (processNewVisitForm, initNewVisitForm)
│               ├── Visit.java                    ← READ ONLY; byte-identical after change
│               ├── OwnerRepository.java          ← unchanged
│               ├── Owner.java                    ← unchanged
│               ├── Pet.java                      ← unchanged
│               └── [other owner-package files]   ← unchanged
│
└── test/
    └── java/
        └── org/springframework/samples/petclinic/
            └── owner/
                ├── VisitControllerTests.java     ← MODIFIED (one test replaced)
                ├── ClinicServiceTests.java        ← unchanged; must still pass
                ├── OwnerControllerTests.java      ← unchanged; must still pass
                ├── PetControllerTests.java        ← unchanged; must still pass
                └── [other test files]             ← unchanged

src/main/resources/
├── messages.properties                            ← unchanged (no new key added)
├── messages_de.properties                         ← unchanged
└── [other messages_*.properties]                 ← unchanged

src/main/resources/templates/
└── pets/
    └── createOrUpdateVisitForm.html               ← unchanged (reads minVisitDate attribute already)

src/main/resources/db/
└── [h2|mysql|postgres]/
    └── [schema and data files]                    ← unchanged (no migration introduced)

k8s/                                               ← unchanged
.github/workflows/                                 ← unchanged
pom.xml                                            ← unchanged
```

**Structure Decision**: Single-project Maven layout (Option 1 equivalent). The repository is a standard Spring Boot modular monolith. All source under `src/main/java` and `src/test/java`. The two files modified by this feature are both in the `owner` sub-package. No new packages, modules, or top-level directories are introduced.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Principle II — past-date check in controller rather than as a Jakarta Bean Validation annotation on `Visit.date` | `Visit.java` is prohibited from modification (FR-007); entity-level annotation would fire on persistence of existing past-dated seed rows (FR-012) and would require a third changed file outside the permitted set | `@FutureOrPresent` on `Visit.date`: requires modifying `Visit.java` (prohibited) and breaks persistence of historical data. Standalone `VisitValidator`: also prohibited by Principle II and requires a third file. Spring `@Validated` method-level constraint: requires annotating `Visit.java` or a DTO wrapper, both outside the permitted change set. |

## Phase 0: Research

Research is complete. All NEEDS CLARIFICATION items from the initial Technical Context pass-through are resolved or explicitly deferred as non-blocking NC items. See `research.md` for full decision log.

**Resolved decisions**:
1. Validation placement: imperative check in `processNewVisitForm` (research.md §1)
2. `rejectValue` call signature: three-argument form with error code and default message (research.md §2)
3. Check position relative to `result.hasErrors()`: before the guard (research.md §3)
4. Null guard on `visit.getDate()`: explicit null check retained (research.md §4)
5. `minVisitDate` value: `LocalDate.now()` (research.md §5)
6. Time-zone handling: `LocalDate.now()` no-arg form, JVM default, code comment (research.md §6)
7. Test structure: one replacement method, two sub-assertions, `LocalDate.now()` at runtime (research.md §7)
8. `I18nPropertiesSyncTest` impact: no action required (research.md §8, NC-4 residual)
9. `ClinicServiceTests` impact: no action required (research.md §9)
10. Seed data impact: no action required (research.md §10)
11. `@InitBinder` impact: no change (research.md §11)
12. Diff scope: exactly two files (research.md §12)
13. Constitution Principle II exception: documented ADR (research.md §13)

**Non-blocking NC items** (do not block implementation; implementer resolves by reading live files):
- NC-1: Exact current source of `VisitController.java` (method signatures, current `minVisitDate` expression, `hasErrors` guard structure)
- NC-2: Exact current source of the replaced test (method name confirmation, mock setup, surrounding test configuration)
- NC-3: CI pipeline surefire output path verification
- NC-4: `I18nPropertiesSyncTest` scan scope confirmation

## Phase 1: Design & Contracts

### Data Model (`data-model.md`)

See `data-model.md` for the full artifact. Summary:

**Entity in scope: `Visit`**

| Field | Type | Current constraint | Change |
|---|---|---|---|
| `id` | `Integer` | Auto-generated PK | None |
| `date` | `LocalDate` | No bean-validation annotation; default = `LocalDate.now().plusDays(1)` in constructor | Controller-layer check added: must not be before `LocalDate.now()` on POST submission. Entity field unchanged. |
| `description` | `String` | `@NotBlank` (existing) | None |

**State transitions relevant to this change**:

```
POST /owners/{ownerId}/pets/{petId}/visits/new
  │
  ├─ Binding layer: date field blank or unparseable
  │     → BindingResult error (existing); processNewVisitForm body not reached for null date
  │
  └─ Binding layer: date parsed successfully → processNewVisitForm entered
        │
        ├─ visit.getDate() != null && visit.getDate().isBefore(LocalDate.now())
        │     → result.rejectValue("date", "visit.date.pastNotAllowed",
        │                          "Visit date must be today or in the future.")
        │     → (fall through to hasErrors check)
        │
        └─ result.hasErrors() ?
              ├─ YES → return "pets/createOrUpdateVisitForm" (HTTP 200); OwnerRepository.save NOT called
              └─ NO  → OwnerRepository.save(owner); return "redirect:/owners/{ownerId}" (3xx)
```

**No new entity fields, annotations, relationships, schema changes, or seed changes are introduced.**

**`Visit` default constructor**: `date` remains `LocalDate.now().plusDays(1)` (tomorrow). Unchanged.

**`VisitController` model attribute change**:

| Attribute | Before | After |
|---|---|---|
| `minVisitDate` (GET) | `LocalDate.now().plusDays(1)` | `LocalDate.now()` |

---

### Contracts (`contracts/visit-form-post.md`)

See `contracts/visit-form-post.md` for the full artifact. Summary:

**Contract: New Visit Form POST**

```
Route:   POST /owners/{ownerId}/pets/{petId}/visits/new
Binder:  setDisallowedFields("id", "*.id")  [unchanged]

Request fields (form-encoded):
  date         LocalDate (parsed by Spring MVC date binder)
  description  String

Success response (all fields valid, date >= LocalDate.now()):
  HTTP 302 (or 3xx)
  Location: /owners/{ownerId}
  Side effect: OwnerRepository.save(owner) called exactly once

Rejection response — past date (date < LocalDate.now(), date non-null and parseable):
  HTTP 200
  View: pets/createOrUpdateVisitForm
  BindingResult field error on "date":
    code:           visit.date.pastNotAllowed
    defaultMessage: "Visit date must be today or in the future."
  Side effect: OwnerRepository.save NOT called

Rejection response — blank or unparseable date (existing behaviour, unchanged):
  HTTP 200
  View: pets/createOrUpdateVisitForm
  BindingResult binding/type-mismatch error on "date" (existing error code)
  Error code visit.date.pastNotAllowed is NOT present
  Side effect: OwnerRepository.save NOT called

Rejection response — description blank (existing behaviour, unchanged):
  HTTP 200
  View: pets/createOrUpdateVisitForm
  BindingResult field error on "description" (existing @NotBlank error)
  Side effect: OwnerRepository.save NOT called

Combined rejection — past date AND blank description:
  HTTP 200
  View: pets/createOrUpdateVisitForm
  BindingResult field errors on BOTH "date" (visit.date.pastNotAllowed) AND "description"
  Side effect: OwnerRepository.save NOT called

GET /owners/{ownerId}/pets/{petId}/visits/new (unchanged route, updated model attribute):
  Model attribute minVisitDate: LocalDate.now()   [was: LocalDate.now().plusDays(1)]
  All other model attributes and template bindings: unchanged
```

**Unchanged from main**:
- Route, HTTP methods, form field names (`date`, `description`)
- Success redirect target (`redirect:/owners/{ownerId}`)
- Flash message (if any; unchanged)
- `@InitBinder` `setAllowedFields` / `setDisallowedFields` body
- All other controller methods (`initNewVisitForm` GET handler signature, `showVisit`, etc.)

---

### Quickstart Validation Guide (`quickstart.md`)

See `quickstart.md` for the full artifact. Summary:

**Prerequisites**:
- Java 17+, Maven Wrapper (`./mvnw`) available
- Repository checked out at the feature branch `010-reject-past-visit-dates-15ab17d7`
- H2 profile (default; no external database required for unit/integration tests)

**Validation scenario 1 — Unit test suite (primary KPI)**:
```bash
./mvnw test -pl . -Dtest=VisitControllerTests
```
Expected: surefire report shows 5 tests, 0 failures, 0 errors. The replacement test asserts the exact string `"Visit date must be today or in the future."` from `BindingResult` for a yesterday POST, and a 3xx redirect for a today POST.

**Validation scenario 2 — Full suite regression check**:
```bash
./mvnw test
```
Expected: `ClinicServiceTests`, `PetClinicIntegrationTests`, `OwnerControllerTests`, `PetControllerTests`, and `I18nPropertiesSyncTest` all pass with no assertion edits.

**Validation scenario 3 — Format and checkstyle**:
```bash
./mvnw validate
```
Expected: `spring-javaformat:validate` and `nohttp` checkstyle pass with no new violations.

**Validation scenario 4 — Diff scope check**:
```bash
git diff --name-only origin/main
```
Expected output (exactly two lines):
```
src/main/java/org/springframework/samples/petclinic/owner/VisitController.java
src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java
```

**Validation scenario 5 — Manual smoke test (optional)**:
```bash
./mvnw spring-boot:run
```
Navigate to any owner → pet → "Add Visit". Enter a past date and submit. Expect the form to re-render with the message "Visit date must be today or in the future." Enter today's date and submit. Expect redirect to the owner detail page and the visit to appear in the visit history.

**Rollback**: `git revert <commit-sha>` followed by redeploy. No schema migration to reverse.
