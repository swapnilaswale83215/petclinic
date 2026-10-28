# Quickstart Validation Guide: Clinic Read API

**Feature**: Clinic Read API (`010-clinic-read-api-ba9d61a9`)
**Branch**: `010-clinic-read-api-ba9d61a9`
**Date**: 2026-10-27
**Spec**: `specs/010-clinic-read-api-ba9d61a9/spec.md`

---

## Purpose

This guide describes how to verify each story end-to-end after it is implemented. Every scenario is mapped to the success criterion it proves. Scenarios are grouped by story and must be run in story order (1 → 2 → 3 → 4) because each story depends on the previous one being merged.

This guide covers validation only. Implementation details, migration steps, and full test suites belong in `tasks.md`. For field definitions and record shapes see `data-model.md`. For the full endpoint contract including all headers and error bodies see `contracts/owner-api.md` and `contracts/pet-api.md`.

---

## Prerequisites

These prerequisites apply to all four stories.

### Build environment

- Java 17 or later on `PATH`.
- Maven Wrapper present at repository root (`./mvnw`). No external Maven installation required.
- The branch `010-clinic-read-api-ba9d61a9` checked out locally.

### Database

The H2 in-memory profile is used for all validation below. No database setup is required; H2 starts automatically with the application and is seeded by the existing `data.sql` / `import.sql` scripts bundled in the project.

> **NC-8**: If any test in the existing suite is already failing on the base branch before Story 1 is implemented, record those failures in the Story 1 pull request as pre-existing defects. KPI-6 is measured as zero *new* failures introduced by each story's changes, not zero failures in the entire suite.

### Seed data assumptions

The scenarios below reference owner ID 1 (George Franklin), owner ID 9999 (does not exist), pet ID 1 (belongs to owner 1), and pet ID 9999 (does not exist). These IDs are drawn from the standard PetClinic seed data. If the seed data in the repository differs, substitute the correct IDs.

The last-name prefix "Davis" is used for search scenarios; substitute a prefix that matches at least one owner in the actual seed data if "Davis" returns zero results.

---

## Running the unit tests (all stories)

The primary validation mechanism for all four stories is the MockMvc test suite. Run it with:

```
./mvnw test
```

All new tests live in `src/test/java/.../owner/api/`. The existing tests in `src/test/java/.../owner/` must continue to pass unchanged.

To run only the new API tests:

```
./mvnw test -pl . -Dtest="OwnerApiControllerTests,PetApiControllerTests"
```

To run only the existing tests as a regression check:

```
./mvnw test -pl . -Dtest="OwnerControllerTests,PetControllerTests,VisitControllerTests,ClinicServiceTests,PetClinicConcurrencyTests"
```

Expected outcome for all stories: `BUILD SUCCESS`, zero test failures, zero errors.

---

## Running the application for manual spot-checks

Start the application on the H2 profile:

```
./mvnw spring-boot:run
```

The application starts on `http://localhost:8080` by default. All `/api` routes are available immediately; no additional configuration is required.

Use `curl`, `httpie`, or any HTTP client. Examples below use `curl`.

---

## Story 1 — GET /api/owners/{id}

**Depends on**: nothing (first story)
**Acceptance criteria**: KPI-1

### Scenario 1.1 — Known owner returns five agreed fields (KPI-1, SPEC-APP-1, SPEC-APP-2, SPEC-INT-1)

```
curl -i http://localhost:8080/api/owners/1
```

**Expected**:
- Status: `200 OK`
- `Content-Type: application/json`
- Body contains exactly and only: `firstName`, `lastName`, `address`, `city`, `telephone`
- Body does **not** contain: `id`, `pets`, or any other field

Example expected body:
```
{"firstName":"George","lastName":"Franklin","address":"110 W. Liberty St.","city":"Madison","telephone":"6085551023"}
```

**Proves**: The five agreed owner fields are returned. No entity is returned directly (FR-002). No extra field leaks (SPEC-APP-2).

---

### Scenario 1.2 — Unknown owner returns 404 with agreed error body (KPI-1, SPEC-APP-1, SPEC-INT-2)

```
curl -i http://localhost:8080/api/owners/9999
```

**Expected**:
- Status: `404 Not Found`
- `Content-Type: application/json`
- Body is exactly: `{"message":"Not found"}`
- Body does **not** contain: stack trace, exception class name, the value `9999`, or any owner field

**Proves**: Unknown ID returns 404. Error body is the agreed shape. No PII or request input is echoed (FR-013, SPEC-SEC-4).

---

### Scenario 1.3 — Non-GET method returns 405 (SPEC-INT-4, SPEC-SEC-2)

```
curl -i -X POST http://localhost:8080/api/owners/1
```

**Expected**:
- Status: `405 Method Not Allowed`
- No repository call is made (verified by the MockMvc test, not by manual inspection)

**Proves**: No non-GET mapping exists under `/api` (FR-010).

---

### Scenario 1.4 — No CORS header on a cross-origin request (SPEC-SEC-5, FR-012)

```
curl -i -H "Origin: https://example.com" http://localhost:8080/api/owners/1
```

**Expected**:
- Response headers do **not** include `Access-Control-Allow-Origin`

> **NC-3**: If this scenario fails despite no CORS configuration being added, an existing global `WebMvcConfigurer` may be adding CORS headers. Investigate before Story 1 merges.

**Proves**: No CORS headers are set (FR-012).

---

### Scenario 1.5 — Non-integer path variable returns 400 (edge case)

```
curl -i http://localhost:8080/api/owners/abc
```

**Expected**:
- Status: `400 Bad Request`
- No repository call is made (framework rejects before controller is reached)

**Proves**: Type conversion failure is handled by the framework without a 500.

---

### Story 1 unit test checklist (KPI-1)

Run `./mvnw test -Dtest="OwnerApiControllerTests"` and confirm:

| Test | Proves |
|------|--------|
| Known ID → 200 with exactly five fields, no `id`, no `pets` | SPEC-APP-1, SPEC-APP-2 |
| Unknown ID → 404 with body `{"message":"Not found"}` | SPEC-APP-1, SPEC-INT-2 |

Minimum passing count: 2. Target: 0 failures.

---

### Story 1 regression check (KPI-5, KPI-6)

```
./mvnw test -Dtest="OwnerControllerTests,PetControllerTests,VisitControllerTests,ClinicServiceTests,PetClinicConcurrencyTests"
```

Expected: 0 failures.

Scope diff check: confirm the git diff for Story 1 touches **no** file under `src/main/resources/templates/`, `src/main/resources/db/`, `k8s/`, or `.github/workflows/`, and introduces **no** non-GET mapping under `/api` and **no** `@ControllerAdvice`.

> **NC-4**: Before Story 1 merges, the approver must confirm whether `OwnerResponse` should include an `id` field for search-result chainability (DEF-1 risk). The current spec requires `id` to be absent. Changing this after Story 1 merges is prohibited by FR-014.

---

## Story 2 — GET /api/owners?lastName=

**Depends on**: Story 1 merged
**Acceptance criteria**: KPI-2

### Scenario 2.1 — Search by last name returns paginated envelope (KPI-2, SPEC-APP-3, SPEC-INT-3)

```
curl -i "http://localhost:8080/api/owners?lastName=Davis"
```

**Expected**:
- Status: `200 OK`
- `Content-Type: application/json`
- Body shape: `{"content":[...],"page":1,"size":5,"total":N}` where N ≥ 0
- Each item in `content` has exactly and only: `firstName`, `lastName`, `address`, `city`, `telephone`
- `size` is always `5`

**Proves**: Paginated envelope is returned. Field set per item matches `OwnerResponse`. Fixed page size enforced (FR-003, FR-004).

---

### Scenario 2.2 — Whitespace in lastName is trimmed before repository call (KPI-2, SPEC-APP-3, SPEC-INT-3)

```
curl -i "http://localhost:8080/api/owners?lastName=%20%20Davis%20%20"
```

**Expected**:
- Status: `200 OK`
- Response body is identical to Scenario 2.1 (same results as `lastName=Davis`)

The trimming is verified precisely by the MockMvc test using `ArgumentCaptor` to assert the repository receives `"Davis"`, not `"  Davis  "`. Manual spot-check confirms the same result set.

**Proves**: Leading and trailing whitespace is stripped before the repository call (FR-003).

---

### Scenario 2.3 — Page 2 is accessible and returns correct page number (KPI-2, SPEC-APP-4, SPEC-INT-3)

```
curl -i "http://localhost:8080/api/owners?lastName=Davis&page=2"
```

**Expected**:
- Status: `200 OK`
- Body has `"page":2`
- Body has `"size":5`
- `content` may be empty if there are fewer than 6 matching owners

The MockMvc test verifies the repository receives `PageRequest.of(1, 5, Sort lastName → firstName → id)`.

**Proves**: 1-based page numbering works. Sort order is correct (FR-004).

---

### Scenario 2.4 — Page below 1 is clamped to 1 (KPI-2, SPEC-APP-4)

```
curl -i "http://localhost:8080/api/owners?lastName=Davis&page=0"
```

**Expected**:
- Status: `200 OK`
- Body has `"page":1`

**Proves**: Page values below 1 are treated as 1 (FR-004).

---

### Scenario 2.5 — Page beyond last page returns 200 with empty content and real total (KPI-2, SPEC-APP-4)

```
curl -i "http://localhost:8080/api/owners?lastName=Davis&page=999"
```

**Expected**:
- Status: `200 OK`
- Body has `"content":[]`
- `"total"` reflects the actual count of matching owners (not 0)

**Proves**: Out-of-range page returns 200 with empty content and the real total (FR-004).

---

### Scenario 2.6 — Missing lastName returns 400 (KPI-2, SPEC-APP-3, SPEC-INT-2)

```
curl -i "http://localhost:8080/api/owners"
```

**Expected**:
- Status: `400 Bad Request`
- `Content-Type: application/json`
- Body is exactly: `{"message":"lastName is required"}`
- No repository call is made (verified by MockMvc test)

**Proves**: Missing lastName is rejected before any data lookup (FR-003).

---

### Scenario 2.7 — Blank lastName returns 400 (KPI-2, SPEC-APP-3, SPEC-INT-2)

```
curl -i "http://localhost:8080/api/owners?lastName="
curl -i "http://localhost:8080/api/owners?lastName=%20%20%20"
```

**Expected** for both:
- Status: `400 Bad Request`
- Body is exactly: `{"message":"lastName is required"}`
- No repository call is made (verified by MockMvc test)

**Proves**: Empty and whitespace-only lastName values are rejected (FR-003).

---

### Scenario 2.8 — size parameter is ignored; page size is always 5 (SPEC-SEC-3)

```
curl -i "http://localhost:8080/api/owners?lastName=Davis&size=100"
```

**Expected**:
- Status: `200 OK`
- Body has `"size":5`
- Repository receives page size 5 (verified by MockMvc test)

**Proves**: The `size` query parameter cannot override the fixed page size (FR-004, SPEC-SEC-3).

---

### Story 2 unit test checklist (KPI-2)

Run `./mvnw test -Dtest="OwnerApiControllerTests"` and confirm:

| Test | Proves |
|------|--------|
| lastName=Davis → 200 envelope with five-field items | SPEC-APP-3 |
| Trimmed lastName → repository called with trimmed value (ArgumentCaptor) | SPEC-APP-3 |
| page=2 → repository receives PageRequest(1, 5, Sort lastName→firstName→id) | SPEC-APP-4 |
| page=0 → repository receives PageRequest(0, 5, …), response has page=1 | SPEC-APP-4 |
| Page beyond last → 200 with empty content and real total | SPEC-APP-4 |
| Missing lastName → 400 `{"message":"lastName is required"}`, no repository call | SPEC-APP-3, SPEC-INT-2 |
| Blank lastName → 400 `{"message":"lastName is required"}`, no repository call | SPEC-APP-3, SPEC-INT-2 |
| size=100 → repository receives size 5, response has size=5 | SPEC-SEC-3 |

Minimum passing count: 6. Target: 0 failures.

> **NC-2**: If the test suite includes a scenario where a non-numeric `page` value is supplied alongside a blank `lastName`, the ordering of the 400 response (which check fires first) must be confirmed. The spec does not mandate a specific ordering for this combination; document the actual behaviour in the Story 2 pull request.

---

### Story 2 regression check (KPI-5, KPI-6)

Same commands as Story 1. Confirm 0 failures in the existing suite and 0 changes to frozen files.

---

## Story 3 — GET /api/owners/{id}/pets

**Depends on**: Story 2 merged
**Acceptance criteria**: KPI-3

### Scenario 3.1 — Pets are returned with agreed fields in case-insensitive name order (KPI-3, SPEC-APP-5, SPEC-INT-1)

```
curl -i http://localhost:8080/api/owners/1/pets
```

**Expected**:
- Status: `200 OK`
- `Content-Type: application/json`
- Body is a JSON array
- Each item has exactly and only: `id`, `name`, `birthDate`, `type`
- `birthDate` is ISO yyyy-MM-dd string or JSON `null`
- `type` is a string (the PetType name), not an object; may be JSON `null`
- Items are ordered by `name` case-insensitively ascending, with null names last
- Items with the same name are ordered by `id` ascending, with null IDs last
- No `owner` field, no `visits` field in any item

The ordering is verified precisely by the MockMvc test using a controlled set of pets with mixed-case names and a null name.

**Proves**: Field set is correct. In-code ordering is applied (FR-006, ADR-APP-9). No sensitive owner reference leaks (SPEC-SEC-1).

---

### Scenario 3.2 — Unknown owner returns 404 (KPI-3, SPEC-APP-5, SPEC-INT-2)

```
curl -i http://localhost:8080/api/owners/9999/pets
```

**Expected**:
- Status: `404 Not Found`
- Body is exactly: `{"message":"Not found"}`

**Proves**: Unknown owner ID returns 404 with the agreed error body (FR-006).

---

### Scenario 3.3 — Owner with no pets returns empty array with 200 (KPI-3, SPEC-APP-5, SPEC-INT-1)

Use an owner ID that has no pets in the seed data, or rely on the MockMvc test which mocks an owner with an empty pet list.

```
curl -i http://localhost:8080/api/owners/{id-with-no-pets}/pets
```

**Expected**:
- Status: `200 OK`
- Body is exactly: `[]`

**Proves**: Empty pet list returns 200, not 404 (FR-006).

---

### Scenario 3.4 — Null birthDate and null type serialise as JSON null, not 500 (SPEC-DATA-3)

This scenario is verified by the MockMvc test, which mocks a pet with `birthDate = null` and `type = null`. Manual verification requires seed data with a null birthDate or type, which may not be present in the standard H2 seed.

**MockMvc test assertion**: response body contains `"birthDate":null` and `"type":null` with status 200.

**Proves**: Null date and null type fields do not cause a 500 (SPEC-DATA-3, DEF-9 risk mitigation).

---

### Story 3 unit test checklist (KPI-3)

Run `./mvnw test -Dtest="PetApiControllerTests"` and confirm:

| Test | Proves |
|------|--------|
| Pets with mixed-case names and one null name → ordered Alpha, bella, Zed, null-name | SPEC-APP-5, ADR-APP-9 |
| Two pets with same name → ordered by ID ascending, null ID last | SPEC-APP-5, ADR-APP-9 |
| Each pet item has exactly id, name, birthDate, type; no owner, no visits | SPEC-APP-5, SPEC-INT-1, SPEC-SEC-1 |
| Unknown owner → 404 `{"message":"Not found"}` | SPEC-APP-5, SPEC-INT-2 |
| Owner with no pets → 200 `[]` | SPEC-APP-5, SPEC-INT-1 |

Minimum passing count: 4. Target: 0 failures.

---

### Story 3 regression check (KPI-5, KPI-6)

Same commands as Story 1. Confirm 0 failures in the existing suite and 0 changes to frozen files.

---

## Story 4 — GET /api/pets/{id}/visits

**Depends on**: Story 3 merged
**Acceptance criteria**: KPI-4

### Scenario 4.1 — Visits are returned with agreed fields in oldest-first order (KPI-4, SPEC-APP-6, SPEC-INT-1)

```
curl -i http://localhost:8080/api/pets/1/visits
```

**Expected**:
- Status: `200 OK`
- `Content-Type: application/json`
- Body is a JSON array
- Each item has exactly and only: `date`, `description`
- `date` is ISO yyyy-MM-dd string or JSON `null`
- Items are ordered oldest date first, with null dates last
- Items with the same date are ordered by visit ID ascending, with null IDs last
- No `id` field, no `pet` field in any item

The ordering is verified precisely by the MockMvc test using a controlled set of visits including one with a null date.

**Proves**: Field set is correct. Oldest-first ordering with null dates last is applied (FR-007, ADR-APP-9). No internal ID or pet reference leaks (SPEC-SEC-1).

---

### Scenario 4.2 — Unknown pet returns 404 (KPI-4, SPEC-APP-6, SPEC-INT-2)

```
curl -i http://localhost:8080/api/pets/9999/visits
```

**Expected**:
- Status: `404 Not Found`
- Body is exactly: `{"message":"Not found"}`

**Proves**: Unknown pet ID returns 404 with the agreed error body (FR-007).

---

### Scenario 4.3 — Pet with no visits returns empty array with 200 (KPI-4, SPEC-APP-6, SPEC-INT-1)

Use a pet ID that has no visits in the seed data, or rely on the MockMvc test which mocks a pet with an empty visit list.

```
curl -i http://localhost:8080/api/pets/{id-with-no-visits}/visits
```

**Expected**:
- Status: `200 OK`
- Body is exactly: `[]`

**Proves**: Empty visit list returns 200, not 404 (FR-007).

---

### Scenario 4.4 — Non-GET method on /api/pets/{id}/visits returns 405 (SPEC-INT-4, SPEC-SEC-2)

```
curl -i -X DELETE http://localhost:8080/api/pets/1/visits
```

**Expected**:
- Status: `405 Method Not Allowed`

**Proves**: No non-GET mapping exists under `/api` (FR-010). This scenario also covers all four routes collectively; the MockMvc test for Story 4 verifies 405 on all `/api` paths.

---

### Scenario 4.5 — PetRepository exposes only findById and does not extend CrudRepository or JpaRepository (KPI-4, SPEC-APP-6, SPEC-DATA-2)

This scenario is verified by a reflection test in `PetApiControllerTests` (or a dedicated unit test). It cannot be verified manually via HTTP.

**MockMvc / reflection test assertion**:
- `PetRepository.class.getDeclaredMethods()` returns exactly one method: `findById(Integer)`.
- `CrudRepository.class.isAssignableFrom(PetRepository.class)` is `false`.
- `JpaRepository.class.isAssignableFrom(PetRepository.class)` is `false`.

**Proves**: PetRepository is a minimal read-only interface (FR-008, SPEC-DATA-2).

> **NC-1**: If the Spring Data component scan does not cover `owner.api`, the application will fail to start because `PetRepository` will not have a generated implementation. In that case, move `PetRepository` to the `owner` package. This must be resolved before Story 4 merges.

---

### Story 4 unit test checklist (KPI-4)

Run `./mvnw test -Dtest="PetApiControllerTests"` and confirm:

| Test | Proves |
|------|--------|
| Visits with mixed dates and one null date → ordered oldest first, null date last | SPEC-APP-6, ADR-APP-9 |
| Two visits with same date → ordered by ID ascending, null ID last | SPEC-APP-6, ADR-APP-9 |
| Each visit item has exactly date and description; no id, no pet | SPEC-APP-6, SPEC-INT-1, SPEC-SEC-1 |
| Unknown pet → 404 `{"message":"Not found"}` | SPEC-APP-6, SPEC-INT-2 |
| Pet with no visits → 200 `[]` | SPEC-APP-6, SPEC-INT-1 |
| Reflection: PetRepository has only findById; not assignable to CrudRepository or JpaRepository | SPEC-APP-6, SPEC-DATA-2 |

Minimum passing count: 4. Target: 0 failures.

---

### Story 4 regression check (KPI-5, KPI-6)

Same commands as Story 1. Confirm 0 failures in the existing suite and 0 changes to frozen files.

---

## Format and style check (all stories, FR-015)

Run the spring-javaformat validate and nohttp checkstyle checks before raising each pull request:

```
./mvnw spring-javaformat:validate
./mvnw checkstyle:check
```

Expected: `BUILD SUCCESS` with no violations.

Common failure causes:
- Spaces used instead of tabs for indentation.
- `http://` literal in a comment or Javadoc (use `https://` or remove the URL).
- Incorrect import ordering (static imports must be last; groups must be alphabetical).

> **NC-5**: If the CI pipeline fails on a formatting rule not covered above, check the spring-javaformat version declared in `pom.xml` or `build.gradle` and any project-specific checkstyle configuration file. Apply `./mvnw spring-javaformat:apply` to auto-correct formatting before re-running the validate goal.

---

## Full suite run (final gate before each merge)

```
./mvnw verify
```

Expected: `BUILD SUCCESS`. This runs compilation, all unit tests, spring-javaformat validation, and nohttp checkstyle in a single command. All four KPIs are satisfied when this command exits with code 0 and the scope diff is clean.

---

## Success criteria summary

| KPI | Verified by | Target |
|-----|-------------|--------|
| KPI-1: GET /api/owners/{id} returns five fields or 404 | Scenarios 1.1, 1.2; OwnerApiControllerTests ≥ 2 tests | 0 failures |
| KPI-2: GET /api/owners?lastName= returns envelope; trim, page, 400 | Scenarios 2.1–2.8; OwnerApiControllerTests ≥ 6 tests | 0 failures |
| KPI-3: GET /api/owners/{id}/pets returns ordered pet list or 404 | Scenarios 3.1–3.4; PetApiControllerTests ≥ 4 tests | 0 failures |
| KPI-4: GET /api/pets/{id}/visits returns ordered visit list or 404 | Scenarios 4.1–4.5; PetApiControllerTests ≥ 4 tests | 0 failures |
| KPI-5: No frozen file changed; no non-GET /api mapping | Scope diff check per story | 0 changed frozen files; 0 non-GET mappings |
| KPI-6: Existing suite passes after each story | Regression check per story | 0 new failures |
