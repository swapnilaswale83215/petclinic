# Implementation Plan: Clinic Read API

**Branch**: `010-clinic-read-api-ba9d61a9` | **Date**: 2026-10-27 | **Spec**: `/specs/010-clinic-read-api-ba9d61a9/spec.md`

**Input**: Feature specification from `/specs/010-clinic-read-api-ba9d61a9/spec.md`

## Summary

Add a read-only JSON API to the existing Spring Boot PetClinic modular monolith. Four chained GET endpoints are introduced under `/api`: retrieve a single owner by ID, search owners by last-name prefix with fixed-size pagination, list pets for an owner, and list visits for a pet. All new classes live in the `org.springframework.samples.petclinic.owner.api` sub-package. Controllers return dedicated Java record types; no entity is returned directly. Error responses are built inline in each controller with no `@ControllerAdvice`. A new read-only `PetRepository` extending only `Repository<Pet,Integer>` is introduced for Story 4. Pet and visit ordering is implemented as in-code comparators. No existing file is modified; no new dependency is added.

## Technical Context

**Language/Version**: Java 17+ (Spring Boot 3.x; records available as a standard feature)

**Primary Dependencies**: Spring MVC (`@RestController`, `ResponseEntity`, `@GetMapping`), Spring Data JPA (`Repository<T,ID>`, `PageRequest`, `Sort`, `Page`), Jackson (already configured; date fields serialised as pre-formatted `String` to avoid JavaTimeModule dependency), Mockito + Spring `@WebMvcTest` for tests

**Storage**: H2 (dev/test profile, in-memory, resets on restart); MySQL and PostgreSQL (production profiles, Testcontainers for integration tests). No schema changes. No new `application*.properties` entries required.

**Testing**: JUnit 5 with `@WebMvcTest` MockMvc slices, `@MockBean` for repositories, `@DisabledInNativeImage` and `@DisabledInAotMode` following the `VisitControllerTests` pattern. Minimum test counts: Story 1 ≥ 2, Story 2 ≥ 6, Story 3 ≥ 4, Story 4 ≥ 4.

**Target Platform**: JVM / Spring Boot web application; deployed via Docker Compose (local) and Kubernetes (`k8s/`); CI via GitHub Actions.

**Project Type**: Modular monolith web application (server-side rendering via Thymeleaf for existing screens; new `/api` surface is pure JSON REST, read-only).

**Performance Goals**: Not specified for this feature. The fixed page size of 5 and mandatory `lastName` parameter bound the result set size. No explicit throughput or latency target is stated. NEEDS CLARIFICATION if a latency SLA is required before Story 1 merges.

**Constraints**: Fixed page size of 5 (SPEC-SEC-3, FR-004); no CORS headers (FR-012); no `@ControllerAdvice` (FR-010); no non-GET mappings under `/api` (FR-010); no changes to any existing file (FR-011, KPI-5); no new Maven/Gradle dependency (R-017); spring-javaformat (tabs, import order) and nohttp (`http://` banned) checks must pass on all new files (FR-015).

**Scale/Scope**: Four new source files (two controllers, one repository interface, five response records — likely split across files or co-located), four new test classes. All changes are additive. No database migration. No infrastructure change.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

---

### Gate 1 — Modular Monolith Architecture (Principle I)

**Rule**: Controllers MUST return model attributes consumed by Thymeleaf templates; the application MUST NOT be treated or extended as a pure REST API. Package boundaries MUST be respected: `owner` package owns Owner, Pet, PetType, Visit, and related controllers/repositories.

**Assessment**: **VIOLATION — JUSTIFIED.**

The four new endpoints are pure JSON REST endpoints, not Thymeleaf-backed MVC handlers. This is a deliberate, scoped extension of the application surface, not a wholesale conversion. The violation is justified by the feature brief and is explicitly accepted in the spec (ADR-SEC-1, G1 decision record). Mitigation: all new classes are placed in the `owner.api` sub-package, keeping them inside the `owner` package boundary. No cross-package dependency is introduced. The existing Thymeleaf controllers and templates are untouched (FR-011, KPI-5). The constitution's package boundary rule is satisfied; only the "no REST API" sub-rule is deviated from, with explicit approval.

**Justification recorded in**: ADR-SEC-1 (referenced in spec assumptions); G1 decision record (to be produced at epic close).

---

### Gate 2 — Business-Rule Integrity (Principle II)

**Rule**: Domain operations MUST enforce entity invariants. Validation via Jakarta Bean Validation in domain classes. No standalone validator classes that duplicate domain constraints.

**Assessment**: **PASS.**

The new API is read-only. No entity is created, updated, or deleted. No new validator class is introduced. No domain invariant is touched. The existing `PetValidator` and Bean Validation annotations on domain classes are unaffected.

---

### Gate 3 — Sensitive Data Handling (Principle III)

**Rule**: Owner `name`, `address`, and `telephone` MUST NOT be exposed in unprotected endpoints, error pages, stack traces, or actuator outputs. Logging of Owner sensitive fields is prohibited.

**Assessment**: **VIOLATION — JUSTIFIED AND MITIGATED.**

The API intentionally exposes `firstName`, `lastName`, `address`, `city`, and `telephone` in the `/api/owners/{id}` and `/api/owners?lastName=` responses. This is an accepted deviation recorded in ADR-SEC-1 and the G1 decision record (spec assumption). Mitigation measures in place: (a) error responses contain only `{"message":"Not found"}` or `{"message":"lastName is required"}` — no Owner PII echoed (FR-013, SPEC-SEC-4); (b) no Owner field appears in log output (FR-013); (c) no stack trace or exception message is returned (R-009); (d) the mandatory `lastName` parameter and fixed page size of 5 limit bulk harvesting (SPEC-SEC-3); (e) no CORS headers are set, limiting cross-origin browser access (FR-012). Residual risks THR-1, 3, 9, 10, 11, 12 (sequential ID enumeration, prefix harvesting) are named in the spec risk register and accepted at G1.

**Justification recorded in**: ADR-SEC-1; G1 decision record; spec risk register (THR-1, 3, 9, 10, 11, 12).

---

### Gate 4 — Profile-Aware Persistence (Principle IV)

**Rule**: H2 for dev/test; MySQL/PostgreSQL for production. No manual schema changes outside profile-managed mechanism.

**Assessment**: **PASS.**

No schema changes are introduced. No new `application*.properties` entries are required (spec assumption). The new `PetRepository` uses Spring Data's auto-generated implementation against the existing schema. The existing H2, MySQL, and PostgreSQL profiles are unaffected.

---

### Gate 5 — Service-Layer Caching Contract (Principle V)

**Rule**: Caching for vet lookups via `VetRepository` managed in `CacheConfiguration`. Controllers MUST NOT implement their own caching.

**Assessment**: **PASS.**

The new controllers read from `OwnerRepository` and `PetRepository` only. No caching is introduced or removed. `CacheConfiguration` is untouched.

---

### Gate 6 — Scope Boundary Enforcement (Principle VI)

**Rule**: Billing, payment, inventory, insurance, multi-clinic are out of scope.

**Assessment**: **PASS.**

The feature adds read-only owner, pet, and visit lookup endpoints. None of the prohibited domains are touched.

---

### Gate 7 — Observability and Health (Principle VII)

**Rule**: Actuator endpoints MUST be configured to avoid exposing sensitive Owner data. Observability MUST NOT be removed or disabled.

**Assessment**: **PASS.**

No Actuator configuration is changed. No new Actuator endpoint is added. The existing `/actuator/health` endpoint is unaffected. The new `/api` routes are not Actuator endpoints and do not expose Owner data through Actuator.

---

### Post-Phase-1 Re-check

All gates re-evaluated after Phase 1 design artifacts are produced. Gates 1 and 3 retain their justified-violation status. Gates 2, 4, 5, 6, 7 remain passing. No new violations introduced by the data model or contract design.

## Project Structure

### Documentation (this feature)

```text
specs/010-clinic-read-api-ba9d61a9/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── owner-api.md
│   └── pet-api.md
└── tasks.md             # Phase 2 output (/speckit-tasks command — NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
src/
├── main/
│   └── java/
│       └── org/springframework/samples/petclinic/
│           ├── owner/                          # EXISTING — do not modify
│           │   ├── Owner.java
│           │   ├── OwnerController.java
│           │   ├── OwnerRepository.java
│           │   ├── Pet.java
│           │   ├── PetController.java
│           │   ├── PetRepository.java          # EXISTING (if present) — see NC-1
│           │   ├── PetType.java
│           │   ├── PetTypeFormatter.java
│           │   ├── PetValidator.java
│           │   ├── Visit.java
│           │   ├── VisitController.java
│           │   └── api/                        # NEW — all new production classes
│           │       ├── ApiMessage.java         # record ApiMessage(String message)
│           │       ├── OwnerApiController.java # @RestController; GET /api/owners/{id}, /api/owners, /api/owners/{id}/pets
│           │       ├── OwnerPage.java          # record OwnerPage(List<OwnerResponse> content, int page, int size, long total)
│           │       ├── OwnerResponse.java      # record OwnerResponse(String firstName, String lastName, String address, String city, String telephone)
│           │       ├── PetApiController.java   # @RestController; GET /api/pets/{id}/visits
│           │       ├── PetRepository.java      # interface PetRepository extends Repository<Pet,Integer>
│           │       ├── PetResponse.java        # record PetResponse(Integer id, String name, String birthDate, String type)
│           │       └── VisitResponse.java      # record VisitResponse(String date, String description)
│           ├── vet/                            # EXISTING — do not modify
│           └── system/                         # EXISTING — do not modify
└── test/
    └── java/
        └── org/springframework/samples/petclinic/
            ├── owner/                          # EXISTING — do not modify
            │   ├── OwnerControllerTests.java
            │   ├── PetControllerTests.java
            │   └── VisitControllerTests.java   # Reference pattern for new tests
            └── owner/api/                      # NEW — all new test classes
                ├── OwnerApiControllerTests.java # @WebMvcTest(OwnerApiController.class); Stories 1 and 2
                └── PetApiControllerTests.java   # @WebMvcTest(PetApiController.class); Stories 3 and 4
```

**Structure Decision**: Single-project Maven/Gradle layout following the existing PetClinic convention. All new production code is additive under `src/main/java/.../owner/api/`. All new tests are additive under `src/test/java/.../owner/api/`. No new source root, no new module, no new build file. The `owner.api` sub-package keeps all new classes inside the `owner` package boundary (Principle I, R-001). `PetRepository` is placed in `owner.api` as the primary choice; if Spring Data scanning does not cover this sub-package (NC-1), it moves to `owner`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| REST JSON endpoints in a Thymeleaf modular monolith (Principle I) | The feature brief explicitly requires a read-only JSON API alongside the existing HTML screens, as a separate consumer surface for Synapse integration | Converting the existing screens to REST would break the Thymeleaf UI; a separate microservice would require infrastructure changes and cross-package dependencies; the `owner.api` sub-package is the minimal additive approach that satisfies the brief without restructuring the application |
| Exposing Owner sensitive fields (name, address, telephone) via unauthenticated endpoints (Principle III) | The feature brief requires these fields in the owner response; the application has no authentication layer; adding authentication is out of scope | Omitting the fields would make the API non-functional for its stated purpose; adding authentication would require infrastructure and security changes beyond the four stories; residual risks are named and accepted at G1 |

## Phase 0: Research

Research is complete. See `research.md` for all decisions and rationale. All items are resolved except the eight NEEDS CLARIFICATION items (NC-1 through NC-8) documented in the research summary. None of NC-1 through NC-6 block plan completion; they are resolved at build time or by approver decision before the relevant story merges. NC-7 and NC-8 are process items with no code impact.

**Key decisions carried forward into Phase 1**:

- All new classes in `org.springframework.samples.petclinic.owner.api` (R-001)
- `PetRepository extends Repository<Pet,Integer>` with only `findById(Integer)` (R-003)
- Five Java records for responses; date fields as `String` via `LocalDate.toString()` (R-004, R-005)
- In-code comparators for pet and visit ordering; visit ID tiebreak applied before mapping to `VisitResponse` (R-006)
- `PageRequest.of(safePage-1, 5, Sort…)` with `Math.max(1, page)` clamping; `size` parameter ignored (R-007)
- `lastName` validated as `@RequestParam(required=false)`; blank/null returns 400 before repository call (R-008)
- `ResponseEntity<?>` with inline `ApiMessage` construction; no `@ControllerAdvice` (R-009)
- No CORS configuration added (R-010)
- No action needed for 405 on non-GET methods (R-011)
- Null-safe ternary for `birthDate` and `type` in `PetResponse` mapping (R-013)
- `@WebMvcTest` + `@DisabledInNativeImage` + `@DisabledInAotMode` + `@MockBean` pattern (R-014)
- Tabs, no `http://` literals, spring-javaformat import order on all new files (R-015)
- `OwnerResponse` defined once in Story 1; reused by `OwnerPage` in Story 2 (R-019)

## Phase 1: Design and Contracts

### Data Model

See `data-model.md` for the full entity and record specifications. Summary:

**New records (production)**:

| Record | Fields | Used by |
|--------|--------|---------|
| `OwnerResponse` | `firstName`, `lastName`, `address`, `city`, `telephone` (all `String`) | Stories 1, 2 |
| `OwnerPage` | `content` (`List<OwnerResponse>`), `page` (`int`, 1-based), `size` (`int`, always 5), `total` (`long`) | Story 2 |
| `PetResponse` | `id` (`Integer`), `name` (`String`), `birthDate` (`String`, ISO or null), `type` (`String`, PetType name or null) | Story 3 |
| `VisitResponse` | `date` (`String`, ISO or null), `description` (`String`) | Story 4 |
| `ApiMessage` | `message` (`String`) | All stories (error responses) |

**New interface (production)**:

| Interface | Extends | Methods | Used by |
|-----------|---------|---------|---------|
| `PetRepository` | `Repository<Pet, Integer>` | `Optional<Pet> findById(Integer id)` | Story 4 |

**Existing entities (read-only, not modified)**:

| Entity | Fields read by API | Notes |
|--------|--------------------|-------|
| `Owner` | `firstName`, `lastName`, `address`, `city`, `telephone`, `getPets()` | `id` not exposed in response |
| `Pet` | `id`, `name`, `birthDate`, `getType()`, `getVisits()` | `owner` not exposed |
| `PetType` | `getName()` | Exposed as `String` only |
| `Visit` | `id` (for sort tiebreak only), `date`, `description` | `id` not exposed in response; `pet` not exposed |

**Ordering rules**:

- Pets: `Comparator.comparing(PetResponse::name, Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER)).thenComparing(PetResponse::id, Comparator.nullsLast(Comparator.naturalOrder()))`
- Visits: sort on `Visit` entities before mapping — `Comparator.comparing(Visit::getDate, Comparator.nullsLast(Comparator.naturalOrder())).thenComparing(Visit::getId, Comparator.nullsLast(Comparator.naturalOrder()))` — then map to `VisitResponse`

**Pagination**:

- Input: `page` query param (default 1, clamped to ≥ 1); `size` param ignored
- Repository call: `PageRequest.of(safePage - 1, 5, Sort.by("lastName").and(Sort.by("firstName")).and(Sort.by("id")))`
- Response: `OwnerPage(content, safePage, 5, page.getTotalElements())`

### Contracts

See `contracts/owner-api.md` and `contracts/pet-api.md` for full endpoint contracts. Summary:

**`contracts/owner-api.md`** — `OwnerApiController`:

| Method | Path | Success | Error |
|--------|------|---------|-------|
| GET | `/api/owners/{id}` | 200 `OwnerResponse` | 404 `ApiMessage("Not found")` |
| GET | `/api/owners?lastName=X[&page=N]` | 200 `OwnerPage` | 400 `ApiMessage("lastName is required")` |
| GET | `/api/owners/{id}/pets` | 200 `List<PetResponse>` | 404 `ApiMessage("Not found")` |

**`contracts/pet-api.md`** — `PetApiController`:

| Method | Path | Success | Error |
|--------|------|---------|-------|
| GET | `/api/pets/{id}/visits` | 200 `List<VisitResponse>` | 404 `ApiMessage("Not found")` |

**Shared constraints across all endpoints**:
- Content-Type: `application/json` on all responses
- No `Access-Control-Allow-Origin` header on any response
- Non-GET methods → 405 (Spring MVC default)
- Non-integer `{id}` → 400 (Spring MVC type conversion)
- No `id` field in `OwnerResponse` (NC-4: approver must confirm before Story 1 merges)
- No `id` or `pet` field in `VisitResponse`
- No `owner` or `visits` field in `PetResponse`
- Error bodies contain only `message`; no PII, no stack trace, no echoed input

### Quickstart

See `quickstart.md` for the full validation guide. Summary of runnable scenarios per story:

**Story 1**: `GET /api/owners/1` → 200 with five fields; `GET /api/owners/9999` → 404 `{"message":"Not found"}`; `POST /api/owners/1` → 405.

**Story 2**: `GET /api/owners?lastName=Davis` → 200 envelope; `GET /api/owners?lastName=%20Davis%20` → 200 with trimmed match; `GET /api/owners?lastName=Davis&page=2` → 200 page 2; `GET /api/owners` → 400; `GET /api/owners?lastName=` → 400; `GET /api/owners?lastName=Davis&size=100` → 200 with size=5.

**Story 3**: `GET /api/owners/1/pets` → 200 ordered list; `GET /api/owners/9999/pets` → 404; owner with no pets → 200 `[]`.

**Story 4**: `GET /api/pets/1/visits` → 200 ordered list; `GET /api/pets/9999/visits` → 404; pet with no visits → 200 `[]`; reflection assertion on `PetRepository`.
