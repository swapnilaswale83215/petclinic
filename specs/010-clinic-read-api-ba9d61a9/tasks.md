# Tasks: Clinic Read API

**Input**: Design documents from `/specs/010-clinic-read-api-ba9d61a9/`

**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/owner-api.md ✓, contracts/pet-api.md ✓

**Tests**: Test tasks are included — FR-009 explicitly requires `@WebMvcTest` MockMvc tests with minimum counts (Story 1 ≥ 2, Story 2 ≥ 6, Story 3 ≥ 4, Story 4 ≥ 4).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. Stories must be delivered and merged in order 1 → 2 → 3 → 4 (FR-014).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US4)
- Exact file paths are given for every task
- All paths are under `src/main/java/org/springframework/samples/petclinic/owner/api/` (production) and `src/test/java/org/springframework/samples/petclinic/owner/api/` (tests)

## Path Conventions

Single-project Maven layout following the existing PetClinic convention. All new production code is additive under `src/main/java/.../owner/api/`. All new tests are additive under `src/test/java/.../owner/api/`. No existing file is modified.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the `owner.api` sub-package directory structure. No existing file is touched. This phase has a single task because the project already has a build system, dependencies, and configuration — nothing new is required (FR-015, R-017).

- [ ] T001 Create the `owner/api` sub-package directory `src/main/java/org/springframework/samples/petclinic/owner/api/` and the corresponding test directory `src/test/java/org/springframework/samples/petclinic/owner/api/` (both may be created as empty directories with a `.gitkeep` or by placing the first source file; no build file change is permitted)

**Checkpoint**: Package directories exist; the build compiles cleanly with no new source files yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Introduce the shared response records and error record that every story depends on. `ApiMessage` and `OwnerResponse` are used by Stories 1–3; creating them first avoids circular dependencies between story phases. `OwnerResponse` is defined once here and must not be altered after Story 1 merges (FR-014, R-019).

**⚠️ CRITICAL**: No user story controller or test can be compiled until this phase is complete.

- [ ] T002 [P] Create `record ApiMessage(String message)` in `src/main/java/org/springframework/samples/petclinic/owner/api/ApiMessage.java` — exactly one component `message` (String, non-null); used for all 404 and 400 error responses across all four stories; agreed literals are `"Not found"` and `"lastName is required"` (FR-010, FR-013, data-model.md §3.5)
- [ ] T003 [P] Create `record OwnerResponse(String firstName, String lastName, String address, String city, String telephone)` in `src/main/java/org/springframework/samples/petclinic/owner/api/OwnerResponse.java` — exactly five String components matching `Owner` fields; no `id`, no `pets`, no other component; used by Stories 1 and 2; must not be altered after Story 1 merges (FR-002, FR-014, data-model.md §3.1)

**Checkpoint**: `ApiMessage` and `OwnerResponse` compile cleanly. Stories 1 and 2 can now reference these records.

---

## Phase 3: User Story 1 — Retrieve a Single Owner by ID (Priority: P1) 🎯 MVP

**Goal**: Expose `GET /api/owners/{id}` returning 200 with the five agreed owner fields, or 404 with `{"message":"Not found"}`. Establish the `owner.api` package structure, the `OwnerApiController` skeleton, and the MockMvc test pattern that all later stories follow.

**Independent Test**: Issue `GET /api/owners/1` with a mocked `OwnerRepository` returning a known `Owner` — assert exactly `firstName`, `lastName`, `address`, `city`, `telephone` are present and no other field (`id`, `pets`) is present. Issue `GET /api/owners/9999` with the mock returning empty — assert 404 with body `{"message":"Not found"}`. Issue `POST /api/owners/1` — assert 405. Issue `GET /api/owners/1` with an `Origin` header — assert no `Access-Control-Allow-Origin` header in the response. All assertions run in a `@WebMvcTest` MockMvc slice with no real database.

### Tests for User Story 1

- [ ] T004 [US1] Create `OwnerApiControllerTests` in `src/test/java/org/springframework/samples/petclinic/owner/api/OwnerApiControllerTests.java` annotated with `@WebMvcTest(OwnerApiController.class)`, `@DisabledInNativeImage`, `@DisabledInAotMode`; inject `MockMvc` via `@Autowired`; declare `@MockBean OwnerRepository ownerRepository`; following the `VisitControllerTests` pattern exactly (FR-009, R-014) — file skeleton only, test methods added in T005–T008
- [ ] T005 [US1] In `OwnerApiControllerTests`: add test `getOwnerById_knownId_returns200WithExactlyFiveFields` — mock `ownerRepository.findById(1)` to return an `Owner` with firstName "George", lastName "Franklin", address "110 W. Liberty St.", city "Madison", telephone "6085551023"; perform `GET /api/owners/1`; assert status 200, `Content-Type: application/json`, and that the JSON body contains exactly `firstName`, `lastName`, `address`, `city`, `telephone` with the correct values and that `$.id` and `$.pets` do not exist (Story 1 acceptance scenario 1, KPI-1, SPEC-APP-1, SPEC-APP-2)
- [ ] T006 [US1] In `OwnerApiControllerTests`: add test `getOwnerById_unknownId_returns404WithMessageBody` — mock `ownerRepository.findById(9999)` to return empty; perform `GET /api/owners/9999`; assert status 404, `Content-Type: application/json`, body exactly `{"message":"Not found"}`, and that the body does not contain "9999" (Story 1 acceptance scenario 2, KPI-1, SPEC-INT-2, SPEC-SEC-4)
- [ ] T007 [US1] In `OwnerApiControllerTests`: add test `postToOwnerById_returns405` — perform `POST /api/owners/1`; assert status 405 (FR-010, SPEC-INT-4, edge cases)
- [ ] T008 [US1] In `OwnerApiControllerTests`: add test `getOwnerById_withOriginHeader_noCorsHeader` — perform `GET /api/owners/1` with header `Origin: https://example.com`; assert that the response does not contain header `Access-Control-Allow-Origin` (Story 1 acceptance scenario 3, FR-012, SPEC-SEC-5)

### Implementation for User Story 1

- [ ] T009 [US1] Create `OwnerApiController` skeleton in `src/main/java/org/springframework/samples/petclinic/owner/api/OwnerApiController.java` — annotate with `@RestController`; inject `OwnerRepository` via constructor; no `@CrossOrigin`, no `@ControllerAdvice`; class body initially empty (FR-010, FR-012, R-009, R-010)
- [ ] T010 [US1] In `OwnerApiController`: implement `@GetMapping("/api/owners/{id}")` method returning `ResponseEntity<?>` — call `ownerRepository.findById(id)`; if present map to `new OwnerResponse(owner.getFirstName(), owner.getLastName(), owner.getAddress(), owner.getCity(), owner.getTelephone())` and return `ResponseEntity.ok(ownerResponse)`; if absent return `ResponseEntity.status(HttpStatus.NOT_FOUND).body(new ApiMessage("Not found"))` (FR-001, FR-002, FR-010, R-009, data-model.md §7.1)

**Checkpoint**: `OwnerApiControllerTests` passes all four tests (T005–T008). `GET /api/owners/1` against a running H2 instance returns the five agreed fields. `GET /api/owners/9999` returns 404 with `{"message":"Not found"}`. `POST /api/owners/1` returns 405. No CORS header is present. Existing test suite (`OwnerControllerTests`, `PetControllerTests`, `VisitControllerTests`, `ClinicServiceTests`, `PetClinicConcurrencyTests`) passes with 0 failures (KPI-5, KPI-6).

---

## Phase 4: User Story 2 — Search Owners by Last Name with Pagination (Priority: P2)

**Goal**: Expose `GET /api/owners?lastName=X[&page=N]` returning a paginated `OwnerPage` envelope with fixed page size 5, trimmed lastName, and stable sort; return 400 for missing or blank lastName before any repository call.

**Independent Test**: Issue `GET /api/owners?lastName=Davis` — assert 200 with envelope shape `{content, page, size, total}` where `size=5`. Issue `GET /api/owners?lastName=%20%20Davis%20%20` — assert repository receives trimmed `"Davis"` via `ArgumentCaptor`. Issue `GET /api/owners?lastName=Davis&page=2` — assert `PageRequest` has page index 1, size 5, Sort `lastName→firstName→id`. Issue `GET /api/owners` — assert 400 with `{"message":"lastName is required"}` and repository never called. Issue `GET /api/owners?lastName=` — same 400. Issue `GET /api/owners?lastName=Davis&size=100` — assert response `size=5`. All in `@WebMvcTest` MockMvc slice with mocked `OwnerRepository`.

### Tests for User Story 2

- [ ] T011 [US2] In `OwnerApiControllerTests`: add test `searchOwners_validLastName_returns200WithEnvelopeShape` — mock `ownerRepository.findByLastNameStartingWith(eq("Davis"), any(Pageable.class))` to return a `Page<Owner>` with one owner and total 2; perform `GET /api/owners?lastName=Davis`; assert status 200, body has `content` array, `page=1`, `size=5`, `total=2`, and each content item has exactly `firstName`, `lastName`, `address`, `city`, `telephone` with no `id` (Story 2 acceptance scenario 1, KPI-2, SPEC-APP-3, SPEC-INT-3)
- [ ] T012 [US2] In `OwnerApiControllerTests`: add test `searchOwners_lastNameWithWhitespace_repositoryReceivesTrimmedValue` — use `ArgumentCaptor<String>` to capture the first argument to `findByLastNameStartingWith`; perform `GET /api/owners?lastName=%20%20Davis%20%20`; assert captured value is `"Davis"` and status is 200 (Story 2 acceptance scenario 2, FR-003, SPEC-APP-3)
- [ ] T013 [US2] In `OwnerApiControllerTests`: add test `searchOwners_page2_repositoryReceivesCorrectPageable` — use `ArgumentCaptor<Pageable>` to capture the `Pageable`; perform `GET /api/owners?lastName=Davis&page=2`; assert captured `Pageable` has `pageNumber=1`, `pageSize=5`, and `Sort` equal to `Sort.by("lastName").and(Sort.by("firstName")).and(Sort.by("id"))`; assert response body has `page=2` (Story 2 acceptance scenario 3, FR-004, SPEC-APP-4)
- [ ] T014 [US2] In `OwnerApiControllerTests`: add test `searchOwners_pageZeroOrNegative_treatedAsPage1` — perform `GET /api/owners?lastName=Davis&page=0`; assert captured `Pageable` has `pageNumber=0` (i.e. `safePage=1`, zero-based index 0) and response body has `page=1` (Story 2 acceptance scenario 4, FR-004)
- [ ] T015 [US2] In `OwnerApiControllerTests`: add test `searchOwners_pageBeyondLast_returns200WithEmptyContentAndRealTotal` — mock repository to return an empty `Page` with `totalElements=7`; perform `GET /api/owners?lastName=Davis&page=5`; assert status 200, `content=[]`, `total=7` (Story 2 acceptance scenario 5, FR-004)
- [ ] T016 [US2] In `OwnerApiControllerTests`: add test `searchOwners_missingLastName_returns400BeforeRepositoryCall` — perform `GET /api/owners`; assert status 400, body exactly `{"message":"lastName is required"}`; verify `ownerRepository` is never called via `Mockito.verify(ownerRepository, never())` (Story 2 acceptance scenario 6, FR-003, SPEC-INT-2)
- [ ] T017 [US2] In `OwnerApiControllerTests`: add test `searchOwners_blankLastName_returns400BeforeRepositoryCall` — perform `GET /api/owners?lastName=` and `GET /api/owners?lastName=%20%20%20`; assert status 400, body exactly `{"message":"lastName is required"}`; verify repository never called (Story 2 acceptance scenario 7, FR-003)
- [ ] T018 [US2] In `OwnerApiControllerTests`: add test `searchOwners_sizeParameterIgnored_responseSizeAlways5` — perform `GET /api/owners?lastName=Davis&size=100`; assert captured `Pageable` has `pageSize=5` and response body has `size=5` (Story 2 acceptance scenario 8, FR-004, SPEC-SEC-3)

### Implementation for User Story 2

- [ ] T019 [US2] Create `record OwnerPage(List<OwnerResponse> content, int page, int size, long total)` in `src/main/java/org/springframework/samples/petclinic/owner/api/OwnerPage.java` — four components exactly as specified; `size` is always 5 in practice; `content` is `List<OwnerResponse>` (never null, may be empty); `page` is 1-based `safePage`; `total` is `Page.getTotalElements()` (FR-003, FR-004, data-model.md §3.2)
- [ ] T020 [US2] In `OwnerApiController`: implement `@GetMapping("/api/owners")` method with `@RequestParam(required = false) String lastName` and `@RequestParam(defaultValue = "1") int page` — (1) if `lastName == null || lastName.trim().isEmpty()` return `ResponseEntity.badRequest().body(new ApiMessage("lastName is required"))` immediately without calling the repository; (2) compute `int safePage = Math.max(1, page)`; (3) trim lastName; (4) call `ownerRepository.findByLastNameStartingWith(trimmed, PageRequest.of(safePage - 1, 5, Sort.by("lastName").and(Sort.by("firstName")).and(Sort.by("id"))))`; (5) map each `Owner` to `OwnerResponse`; (6) return `ResponseEntity.ok(new OwnerPage(content, safePage, 5, result.getTotalElements()))` (FR-003, FR-004, FR-005, R-007, R-008, data-model.md §6)

**Checkpoint**: All eight Story 2 tests (T011–T018) pass. `GET /api/owners?lastName=Davis` against H2 returns the envelope. `GET /api/owners` returns 400. `GET /api/owners?lastName=Davis&size=100` returns `size=5`. Story 1 tests still pass. Existing suite passes with 0 failures (KPI-5, KPI-6).

---

## Phase 5: User Story 3 — List Pets for an Owner (Priority: P3)

**Goal**: Expose `GET /api/owners/{id}/pets` returning a JSON array of `{id, name, birthDate, type}` ordered by name case-insensitively (nulls last) then by id (nulls last). Unknown owner → 404. Owner with no pets → 200 with `[]`.

**Independent Test**: Issue `GET /api/owners/1/pets` with a mocked `OwnerRepository` returning an owner whose pets include names "bella", "Alpha", "Zed", and one null-name pet — assert ordering is Alpha, bella, Zed, null-name. Assert each item has exactly `id`, `name`, `birthDate`, `type` (string, not object) and no `owner` or `visits`. Issue `GET /api/owners/9999/pets` — assert 404 with `{"message":"Not found"}`. Issue `GET /api/owners/1/pets` with owner having no pets — assert 200 with `[]`. All in `@WebMvcTest` MockMvc slice.

### Tests for User Story 3

- [ ] T021 [US3] In `OwnerApiControllerTests`: add test `listPetsForOwner_knownOwner_returns200WithExactFieldsAndOrdering` — mock `ownerRepository.findById(1)` to return an owner with pets named "bella" (id=7), "Alpha" (id=3), "Zed" (id=1), and one pet with null name (id=9); perform `GET /api/owners/1/pets`; assert status 200, array length 4, order is Alpha(id=3), bella(id=7), Zed(id=1), null-name(id=9); assert each item has exactly `id`, `name`, `birthDate`, `type` and no `owner` or `visits` field (Story 3 acceptance scenarios 1 and 3, FR-006, SPEC-APP-5)
- [ ] T022 [US3] In `OwnerApiControllerTests`: add test `listPetsForOwner_sameName_orderedById` — mock owner with two pets both named "alpha" (ids 5 and 2); perform `GET /api/owners/1/pets`; assert they appear in order id=2 then id=5 (Story 3 acceptance scenario 2, ADR-APP-9)
- [ ] T023 [US3] In `OwnerApiControllerTests`: add test `listPetsForOwner_nullBirthDateAndNullType_serialisedAsJsonNull` — mock owner with one pet having `birthDate=null` and `type=null`; perform `GET /api/owners/1/pets`; assert `birthDate` field is JSON null and `type` field is JSON null and no 500 is thrown (SPEC-DATA-3, DEF-9, data-model.md §2.2)
- [ ] T024 [US3] In `OwnerApiControllerTests`: add test `listPetsForOwner_unknownOwner_returns404` — mock `ownerRepository.findById(9999)` to return empty; perform `GET /api/owners/9999/pets`; assert status 404, body exactly `{"message":"Not found"}` (Story 3 acceptance scenario 4, FR-006, SPEC-INT-2)
- [ ] T025 [US3] In `OwnerApiControllerTests`: add test `listPetsForOwner_ownerWithNoPets_returns200WithEmptyArray` — mock owner with empty pets collection; perform `GET /api/owners/1/pets`; assert status 200, body `[]` (Story 3 acceptance scenario 5, FR-006)

### Implementation for User Story 3

- [ ] T026 [US3] Create `record PetResponse(Integer id, String name, String birthDate, String type)` in `src/main/java/org/springframework/samples/petclinic/owner/api/PetResponse.java` — four components exactly: `id` (Integer, nullable per domain), `name` (String, nullable), `birthDate` (String, ISO yyyy-MM-dd or null), `type` (String, PetType name or null); no `owner`, no `visits` component (FR-006, FR-002, data-model.md §3.3)
- [ ] T027 [US3] In `OwnerApiController`: implement `@GetMapping("/api/owners/{id}/pets")` method returning `ResponseEntity<?>` — call `ownerRepository.findById(id)`; if absent return `ResponseEntity.status(HttpStatus.NOT_FOUND).body(new ApiMessage("Not found"))`; if present map each `Pet` in `owner.getPets()` to `new PetResponse(pet.getId(), pet.getName(), pet.getBirthDate() != null ? pet.getBirthDate().toString() : null, pet.getType() != null ? pet.getType().getName() : null)`; sort the resulting list with `Comparator.comparing(PetResponse::name, Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER)).thenComparing(PetResponse::id, Comparator.nullsLast(Comparator.naturalOrder()))`; return `ResponseEntity.ok(sortedList)` (FR-006, R-006, R-013, data-model.md §5.1, §7.2)

**Checkpoint**: All five Story 3 tests (T021–T025) pass. `GET /api/owners/1/pets` against H2 returns pets in the correct order. `GET /api/owners/9999/pets` returns 404. Owner with no pets returns `[]`. Stories 1 and 2 tests still pass. Existing suite passes with 0 failures (KPI-5, KPI-6).

---

## Phase 6: User Story 4 — List Visits for a Pet (Priority: P4)

**Goal**: Expose `GET /api/pets/{id}/visits` returning a JSON array of `{date, description}` ordered oldest-first (null dates last, then by id nulls last) via a new read-only `PetRepository` that extends only `Repository<Pet,Integer>` with a single `findById` method.

**Independent Test**: Issue `GET /api/pets/1/visits` with a mocked `PetRepository` returning a pet whose visits are set up newest-first plus one null-date visit — assert ordering is oldest first, null-date last. Assert each item has exactly `date` and `description` and no `id` or `pet`. Issue `GET /api/pets/9999/visits` — assert 404. Issue `GET /api/pets/1/visits` with no visits — assert 200 with `[]`. Assert via reflection that `PetRepository` is not assignable to `CrudRepository` or `JpaRepository` and declares only `findById(Integer)`. All in `@WebMvcTest` MockMvc slice with mocked `PetRepository`.

### Tests for User Story 4

- [ ] T028 [US4] Create `PetApiControllerTests` in `src/test/java/org/springframework/samples/petclinic/owner/api/PetApiControllerTests.java` annotated with `@WebMvcTest(PetApiController.class)`, `@DisabledInNativeImage`, `@DisabledInAotMode`; inject `MockMvc` via `@Autowired`; declare `@MockBean PetRepository petRepository`; following the `VisitControllerTests` pattern (FR-009, R-014) — file skeleton only, test methods added in T029–T034
- [ ] T029 [US4] In `PetApiControllerTests`: add test `listVisitsForPet_knownPet_returns200WithExactFieldsAndDateOrdering` — mock `petRepository.findById(1)` to return a pet with visits dated 2015-01-04 (id=3), 2013-01-04 (id=1), and one visit with null date (id=5); perform `GET /api/pets/1/visits`; assert status 200, array length 3, order is 2013-01-04, 2015-01-04, null-date; assert each item has exactly `date` and `description` and no `id` or `pet` field (Story 4 acceptance scenarios 1 and 3, FR-007, SPEC-APP-6)
- [ ] T030 [US4] In `PetApiControllerTests`: add test `listVisitsForPet_sameDateVisits_orderedById` — mock pet with two visits both dated 2013-01-04 (ids 5 and 2); perform `GET /api/pets/1/visits`; assert they appear in order id=2 then id=5 (Story 4 acceptance scenario 2, ADR-APP-9)
- [ ] T031 [US4] In `PetApiControllerTests`: add test `listVisitsForPet_unknownPet_returns404` — mock `petRepository.findById(9999)` to return empty; perform `GET /api/pets/9999/visits`; assert status 404, body exactly `{"message":"Not found"}` (Story 4 acceptance scenario 4, FR-007, SPEC-INT-2)
- [ ] T032 [US4] In `PetApiControllerTests`: add test `listVisitsForPet_petWithNoVisits_returns200WithEmptyArray` — mock pet with empty visits collection; perform `GET /api/pets/1/visits`; assert status 200, body `[]` (Story 4 acceptance scenario 5, FR-007)
- [ ] T033 [US4] In `PetApiControllerTests`: add test `petRepository_reflectionTest_onlyFindByIdDeclaredAndNotAssignableToCrudOrJpa` — assert `CrudRepository.class.isAssignableFrom(PetRepository.class)` is false; assert `JpaRepository.class.isAssignableFrom(PetRepository.class)` is false; assert that the union of `PetRepository.class.getDeclaredMethods()` and inherited methods from `Repository` contains only `findById` (Story 4 acceptance scenario 6, FR-008, SPEC-DATA-2)
- [ ] T034 [US4] In `PetApiControllerTests`: add test `deleteToVisitsEndpoint_returns405` — perform `DELETE /api/pets/1/visits`; assert status 405 (FR-010, SPEC-INT-4, SPEC-SEC-2, edge cases)

### Implementation for User Story 4

- [ ] T035 [US4] Create `PetRepository` interface in `src/main/java/org/springframework/samples/petclinic/owner/api/PetRepository.java` — declare as `interface PetRepository extends Repository<Pet, Integer>` with exactly one method `Optional<Pet> findById(Integer id)`; must not extend `CrudRepository`, `JpaRepository`, `ListCrudRepository`, or any other Spring Data interface that exposes write methods; if Spring Data scanning does not cover `owner.api` at build time, move this file to `src/main/java/org/springframework/samples/petclinic/owner/PetRepository.java` (NC-1, FR-008, R-003, data-model.md §4.1)
- [ ] T036 [US4] Create `record VisitResponse(String date, String description)` in `src/main/java/org/springframework/samples/petclinic/owner/api/VisitResponse.java` — two components exactly: `date` (String, ISO yyyy-MM-dd or null), `description` (String, nullable); no `id`, no `pet` component; `id` is intentionally absent because the sort tiebreak is applied on `Visit` entities before mapping (FR-007, R-006, data-model.md §3.4)
- [ ] T037 [US4] Create `PetApiController` in `src/main/java/org/springframework/samples/petclinic/owner/api/PetApiController.java` — annotate with `@RestController`; inject `PetRepository` via constructor; no `@CrossOrigin`, no `@ControllerAdvice` (FR-010, FR-012, R-009, R-010)
- [ ] T038 [US4] In `PetApiController`: implement `@GetMapping("/api/pets/{id}/visits")` method returning `ResponseEntity<?>` — call `petRepository.findById(id)`; if absent return `ResponseEntity.status(HttpStatus.NOT_FOUND).body(new ApiMessage("Not found"))`; if present sort `pet.getVisits()` as a stream using `Comparator.comparing(Visit::getDate, Comparator.nullsLast(Comparator.naturalOrder())).thenComparing(Visit::getId, Comparator.nullsLast(Comparator.naturalOrder()))` on `Visit` entities **before** mapping; then map each sorted `Visit` to `new VisitResponse(visit.getDate() != null ? visit.getDate().toString() : null, visit.getDescription())`; return `ResponseEntity.ok(visitResponseList)` (FR-007, R-006, data-model.md §5.2, §7.3)

**Checkpoint**: All seven Story 4 tests (T029–T034, plus T028 skeleton) pass. `GET /api/pets/1/visits` against H2 returns visits oldest-first. `GET /api/pets/9999/visits` returns 404. Pet with no visits returns `[]`. Reflection test confirms `PetRepository` contract. Stories 1, 2, and 3 tests still pass. Existing suite passes with 0 failures (KPI-5, KPI-6).

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Formatting compliance, scope verification, and final validation across all four stories.

- [ ] T039 [P] Run `./mvnw spring-javaformat:apply` (or equivalent) against all eight new files — `ApiMessage.java`, `OwnerResponse.java`, `OwnerPage.java`, `PetResponse.java`, `VisitResponse.java`, `PetRepository.java`, `OwnerApiController.java`, `PetApiController.java` — to enforce tab indentation, import ordering, and no trailing whitespace; verify no `http://` literal appears in any new file (FR-015, R-015, SPEC-PLAT-1)
- [ ] T040 [P] Run `./mvnw spring-javaformat:apply` against both new test files — `OwnerApiControllerTests.java` and `PetApiControllerTests.java` — same formatting rules (FR-015, R-015)
- [ ] T041 Verify scope diff: confirm that the git diff contains zero changes to `src/main/resources/templates/`, `src/main/resources/db/`, `k8s/`, `.github/workflows/`, `pom.xml` (or `build.gradle`), `application*.properties`, `Owner.java`, `Pet.java`, `Visit.java`, `PetType.java`, `OwnerController.java`, `OwnerRepository.java`, `PetController.java`, `VisitController.java` — count of changed files in those paths must be 0 (KPI-5, FR-011, R-018)
- [ ] T042 Verify no non-GET mapping exists under `/api`: confirm that no `@PostMapping`, `@PutMapping`, `@PatchMapping`, `@DeleteMapping`, or `@RequestMapping` with a non-GET method is present in `OwnerApiController.java` or `PetApiController.java` (FR-010, KPI-5)
- [ ] T043 Verify no `@ControllerAdvice` or `@RestControllerAdvice` annotation exists in any new file under `src/main/java/org/springframework/samples/petclinic/owner/api/` (FR-010)
- [ ] T044 Verify no `@CrossOrigin`, `CorsRegistry`, or `CorsConfigurationSource` reference exists in any new file (FR-012)
- [ ] T045 Run the full test suite (`./mvnw test`) and confirm that `OwnerControllerTests`, `PetControllerTests`, `VisitControllerTests`, `ClinicServiceTests`, and `PetClinicConcurrencyTests` all pass with 0 failures introduced by the new code (KPI-6, FR-011)
- [ ] T046 Execute the quickstart.md validation scenarios manually or via curl against a locally running H2 instance: `GET /api/owners/1` (200, five fields), `GET /api/owners/9999` (404), `GET /api/owners?lastName=Davis` (200 envelope), `GET /api/owners?lastName=` (400), `GET /api/owners?lastName=Davis&size=100` (size=5), `GET /api/owners/1/pets` (200 ordered list), `GET /api/pets/1/visits` (200 ordered list), `GET /api/pets/9999/visits` (404), `POST /api/owners/1` (405) (quickstart.md, KPI-1 through KPI-4)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user story phases
- **Story 1 (Phase 3)**: Depends on Phase 2 — no dependency on other stories
- **Story 2 (Phase 4)**: Depends on Story 1 being merged (FR-014, SPEC-INT-6) — reuses `OwnerResponse` from Phase 2
- **Story 3 (Phase 5)**: Depends on Story 2 being merged (FR-014)
- **Story 4 (Phase 6)**: Depends on Story 3 being merged (FR-014)
- **Polish (Phase 7)**: Depends on all four story phases being complete

### User Story Dependencies (per spec FR-014)

- **Story 1 (P1)**: Can start after Foundational — no story dependency
- **Story 2 (P2)**: MUST wait for Story 1 to merge — reuses `OwnerResponse`; `OwnerPage` references it
- **Story 3 (P3)**: MUST wait for Story 2 to merge — establishes `PetResponse` and ordering pattern
- **Story 4 (P4)**: MUST wait for Story 3 to merge — introduces `PetRepository` and `VisitResponse`

### Within Each Story

- Test file skeleton (T004, T028) before individual test methods
- Individual test methods [P] within a story can be written in parallel (different methods, same file — coordinate to avoid merge conflicts)
- Response records [P] before controller implementation (records must compile before controller references them)
- Controller implementation after records and tests
- Story complete and passing before next story begins

### Parallel Opportunities

- T002 (`ApiMessage`) and T003 (`OwnerResponse`) can be written in parallel (different files)
- Within Story 1: T005, T006, T007, T008 can be written in parallel (different test methods); T009 and T010 are sequential (skeleton before method)
- Within Story 2: T011–T018 can be written in parallel (different test methods); T019 (`OwnerPage`) and T020 (controller method) are sequential
- Within Story 3: T021–T025 can be written in parallel (different test methods); T026 (`PetResponse`) before T027 (controller method)
- Within Story 4: T028 skeleton before T029–T034; T035 (`PetRepository`), T036 (`VisitResponse`), T037 (`PetApiController` skeleton) can be written in parallel; T038 (controller method) after T035–T037
- T039 and T040 (formatting) can run in parallel
- T041–T044 (scope checks) can run in parallel

---

## Parallel Example: Story 1

```
# Write test methods in parallel (different methods in OwnerApiControllerTests.java):
T005: getOwnerById_knownId_returns200WithExactlyFiveFields
T006: getOwnerById_unknownId_returns404WithMessageBody
T007: postToOwnerById_returns405
T008: getOwnerById_withOriginHeader_noCorsHeader

# Then implement (sequential — skeleton before method):
T009: OwnerApiController skeleton
T010: @GetMapping("/api/owners/{id}") implementation
```

## Parallel Example: Story 4

```
# Write in parallel after Story 3 merges:
T035: PetRepository.java
T036: VisitResponse.java
T037: PetApiController.java skeleton

# Then implement (depends on T035–T037):
T038: @GetMapping("/api/pets/{id}/visits") implementation

# Test methods in parallel (after T028 skeleton):
T029: date ordering test
T030: same-date tiebreak test
T031: unknown pet 404 test
T032: no visits empty array test
T033: reflection test
T034: DELETE 405 test
```

---

## Implementation Strategy

### MVP First (Story 1 Only)

1. Complete Phase 1: Setup (T001)
2. Complete Phase 2: Foundational (T002–T003)
3. Complete Phase 3: Story 1 (T004–T010)
4. **STOP and VALIDATE**: Run `OwnerApiControllerTests`, verify KPI-1, verify existing suite passes
5. Raise Story 1 pull request; gate on KPI-5 and KPI-6 before Story 2 begins

### Incremental Delivery (one PR per story)

1. Setup + Foundational → `ApiMessage`, `OwnerResponse` ready
2. Story 1 PR → `GET /api/owners/{id}` live, 4 tests passing → merge → MVP
3. Story 2 PR → `GET /api/owners?lastName=` live, 8 tests passing → merge
4. Story 3 PR → `GET /api/owners/{id}/pets` live, 5 tests passing → merge
5. Story 4 PR → `GET /api/pets/{id}/visits` live, 7 tests passing → merge → epic complete
6. Each PR gated by KPI-5 (0 scope diff violations) and KPI-6 (0 existing test failures)

### Sequential Team Strategy (single developer, one story at a time)

Stories must be sequential per FR-014. Within each story, [P]-marked tasks can be batched:

1. Write all [P] test methods for the story → confirm they fail (no controller yet)
2. Create [P] response records
3. Implement controller method
4. Confirm all tests pass
5. Run formatting (T039/T040) and scope checks (T041–T044)
6. Merge; begin next story

---

## NEEDS CLARIFICATION

The following items from research.md and data-model.md are unresolved and may require action before or during the relevant story:

| ID | Item | Blocking story | Action if unresolved |
|----|------|---------------|----------------------|
| NC-1 | Whether `@EnableJpaRepositories` scanning covers `owner.api`; if not, `PetRepository` (T035) moves to `src/main/java/org/springframework/samples/petclinic/owner/PetRepository.java` | Story 4 build | Move file; update import in `PetApiController`; no other change |
| NC-2 | Whether binding `page` as `int` vs. `String` matters for ordering of 400 responses (blank lastName vs. non-numeric page) | Story 2 | If ordering matters, bind `page` as `@RequestParam(required = false) String page` and parse after the lastName check in T020 |
| NC-3 | Whether any existing global `WebMvcConfigurer` adds CORS headers that would affect `/api` routes | Story 1 | If T008 fails despite no new CORS config, investigate existing `WebMvcConfigurer` beans; do not add `@CrossOrigin` |
| NC-4 | Whether `OwnerResponse` should include an `id` field for search-result chainability (DEF-1); must be decided before Story 1 merges | Story 1 | If approved, add `id` component to `OwnerResponse` (T003) and update T005 to assert `id` is present; this is the only window — FR-014 prohibits changing the shape after Story 1 merges |
| NC-5 | Exact spring-javaformat version and any project-specific checkstyle overrides | All stories | Run `./mvnw spring-javaformat:validate` locally on each new file before raising a PR |
| NC-6 | Actual `OwnerRepository.findByLastNameStartingWith(String, Pageable)` signature | Story 2 build | If signature differs, do not alter `OwnerRepository`; raise with approver before Story 2 begins |

---

## Notes

- `[P]` tasks operate on different files and have no dependency on incomplete tasks in the same phase
- `[Story]` label maps each task to its user story for traceability and independent delivery
- No existing file is modified by any task in this list — all changes are additive (FR-011, KPI-5)
- spring-javaformat uses **tabs**, not spaces; IDE auto-format must be disabled or configured to match before editing any new file (R-015)
- No `http://` literal may appear in any new source file, Javadoc, or comment (nohttp check, R-015)
- The `VisitResponse` record intentionally omits `id`; the sort tiebreak in T038 operates on `Visit` entities before the mapping step (R-006)
- `OwnerResponse` is defined once in Phase 2 (T003) and reused by `OwnerPage` (T019); it must not be altered after Story 1 merges (FR-014)
- Commit after each story's checkpoint to keep the diff reviewable and to enable per-story KPI-5/KPI-6 gating
