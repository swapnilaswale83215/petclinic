# Feature Specification: Clinic Read API

**Feature Branch**: `010-clinic-read-api-ba9d61a9`

**Created**: 2026-10-27

**Status**: Draft

**Input**: User description: "Add a read-only JSON API beside the existing owner, pet, and visit screens, as the epic 'Clinic read API' with four code stories for Synapse."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Retrieve a Single Owner by ID (Priority: P1)

An API consumer sends a GET request for a specific owner by numeric ID and receives a JSON object containing that owner's first name, last name, address, city, and telephone number. If the ID does not exist, the consumer receives a 404 response with a machine-readable error body.

**Why this priority**: This is the foundation of the API. It establishes the owner response shape, the error model, and the package structure that all later stories depend on. Stories 2, 3, and 4 cannot be built until this story is merged.

**Independent Test**: Can be fully tested by issuing GET /api/owners/{id} with a known ID and an unknown ID against a MockMvc slice with a mocked OwnerRepository, and verifying the five agreed fields are present, no extra fields are present, and the 404 body is exactly `{"message":"Not found"}`.

**Acceptance Scenarios**:

1. **Given** an owner exists with ID 1 and has firstName "George", lastName "Franklin", address "110 W. Liberty St.", city "Madison", telephone "6085551023", **When** GET /api/owners/1 is requested, **Then** the response is 200 with Content-Type application/json and body `{"firstName":"George","lastName":"Franklin","address":"110 W. Liberty St.","city":"Madison","telephone":"6085551023"}`, with no `id`, `pets`, or other field present. (SPEC-APP-1, SPEC-APP-2, SPEC-INT-1)
2. **Given** no owner exists with ID 9999, **When** GET /api/owners/9999 is requested, **Then** the response is 404 with Content-Type application/json and body exactly `{"message":"Not found"}`, with no stack trace or exception name. (SPEC-APP-1, SPEC-INT-2)
3. **Given** a GET /api/owners/1 request, **When** the response is received, **Then** no `Access-Control-Allow-Origin` header is present. (SPEC-SEC-5)

---

### User Story 2 — Search Owners by Last Name with Pagination (Priority: P2)

An API consumer searches for owners whose last name starts with a given prefix. The response is a paginated envelope containing up to five owners per page, ordered by last name then first name. Leading and trailing whitespace in the search term is ignored. A missing or blank last name is rejected immediately with a 400 error before any data lookup occurs.

**Why this priority**: Depends on Story 1's OwnerResponse record and error model. It is the most behaviourally complex endpoint and must be stable before the pet and visit endpoints are built.

**Independent Test**: Can be fully tested by issuing GET /api/owners?lastName=Davis and variants (trimmed input, page=2, blank lastName, missing lastName) against a MockMvc slice with a mocked OwnerRepository, verifying the envelope shape, the trimmed value passed to the repository via ArgumentCaptor, and the 400 body for invalid input.

**Acceptance Scenarios**:

1. **Given** lastName="Davis" is supplied, **When** GET /api/owners?lastName=Davis is requested, **Then** the response is 200 with body `{"content":[...],"page":1,"size":5,"total":N}` where content items each have exactly the five owner fields and no others. (SPEC-APP-3, SPEC-INT-3)
2. **Given** lastName="  Davis  " (with surrounding spaces) is supplied, **When** GET /api/owners?lastName=%20%20Davis%20%20 is requested, **Then** the repository is called with the trimmed value "Davis" (verified by ArgumentCaptor), and the response is 200. (SPEC-APP-3, SPEC-INT-3)
3. **Given** lastName="Davis" and page=2 are supplied, **When** GET /api/owners?lastName=Davis&page=2 is requested, **Then** the repository receives a Pageable with page index 1, size 5, and Sort exactly lastName → firstName → id, and the response body has page=2. (SPEC-APP-4, SPEC-INT-3)
4. **Given** page=0 or a negative page is supplied alongside a valid lastName, **When** the request is made, **Then** the repository receives page index 0, size 5, and the same Sort, and the response body has page=1. (SPEC-APP-4, SPEC-INT-3)
5. **Given** the requested page is beyond the last page (mock returns an empty page with total 7), **When** the request is made, **Then** the response is 200 with empty content and total=7. (SPEC-APP-4, SPEC-INT-3)
6. **Given** lastName is absent from the query string, **When** GET /api/owners is requested, **Then** the response is 400 with body exactly `{"message":"lastName is required"}` and the repository is never called. (SPEC-APP-3, SPEC-INT-2)
7. **Given** lastName is blank (empty string or whitespace only), **When** GET /api/owners?lastName= or GET /api/owners?lastName=%20%20%20 is requested, **Then** the response is 400 with body exactly `{"message":"lastName is required"}` and the repository is never called, even when page=0 is also present. (SPEC-APP-3, SPEC-INT-2)
8. **Given** a consumer attempts to override the page size by supplying size=100, **When** GET /api/owners?lastName=Davis&size=100 is requested, **Then** the repository still receives page size 5 and the response body has size=5. (SPEC-SEC-3)

---

### User Story 3 — List Pets for an Owner (Priority: P3)

An API consumer retrieves all pets belonging to a specific owner. Each pet record includes the pet's ID, name, birth date, and type name. Pets are ordered by name (case-insensitive), with null names last, then by ID with null IDs last. An unknown owner ID returns 404. An owner with no pets returns an empty list with 200.

**Why this priority**: Depends on Story 2 (and therefore Story 1). Establishes the PetResponse record and the in-code ordering rule (ADR-APP-9) that Story 4 also uses.

**Independent Test**: Can be fully tested by issuing GET /api/owners/{id}/pets against a MockMvc slice with a mocked OwnerRepository, verifying field set, ordering with mixed-case and null names, the 404 body, and the empty-list 200 response.

**Acceptance Scenarios**:

1. **Given** an owner exists with pets named "bella", "Alpha", "Zed", and one pet with a null name, **When** GET /api/owners/1/pets is requested, **Then** the response is 200 with the pets ordered Alpha, bella, Zed, null-name (case-insensitive, nulls last). (SPEC-APP-5, SPEC-INT-1)
2. **Given** two pets have the same name (any case), **When** GET /api/owners/1/pets is requested, **Then** they are ordered by ID ascending, with a null ID last. (SPEC-APP-5, ADR-APP-9)
3. **Given** a pet item is returned, **When** the response body is inspected, **Then** each item has exactly `id`, `name`, `birthDate` (ISO yyyy-MM-dd or null), and `type` (a string, not an object), with no `owner` or `visits` field. (SPEC-APP-5, SPEC-INT-1, SPEC-SEC-1)
4. **Given** no owner exists with the requested ID, **When** GET /api/owners/9999/pets is requested, **Then** the response is 404 with body exactly `{"message":"Not found"}`. (SPEC-APP-5, SPEC-INT-2)
5. **Given** an owner exists but has no pets, **When** GET /api/owners/1/pets is requested, **Then** the response is 200 with body `[]`. (SPEC-APP-5, SPEC-INT-1)

---

### User Story 4 — List Visits for a Pet (Priority: P4)

An API consumer retrieves all visits recorded for a specific pet. Each visit record includes the date and description. Visits are ordered oldest first, with null dates last, then by ID with null IDs last. An unknown pet ID returns 404. A pet with no visits returns an empty list with 200. A new read-only PetRepository is introduced solely for this endpoint.

**Why this priority**: Depends on Story 3. It is the final story in the chain and introduces the only new repository interface in the epic.

**Independent Test**: Can be fully tested by issuing GET /api/pets/{id}/visits against a MockMvc slice with a mocked PetRepository, verifying field set, date ordering with a null date, the 404 body, the empty-list 200 response, and the reflection test that PetRepository exposes only `findById(Integer)`.

**Acceptance Scenarios**:

1. **Given** a pet exists with visits set up newest-first and one visit with a null date, **When** GET /api/pets/1/visits is requested, **Then** the response is 200 with visits ordered oldest first and the null-date visit last. (SPEC-APP-6, SPEC-INT-1)
2. **Given** two visits have the same date, **When** GET /api/pets/1/visits is requested, **Then** they are ordered by ID ascending, with a null ID last. (SPEC-APP-6, ADR-APP-9)
3. **Given** a visit item is returned, **When** the response body is inspected, **Then** each item has exactly `date` (ISO yyyy-MM-dd or null) and `description`, with no `id` or `pet` field. (SPEC-APP-6, SPEC-INT-1, SPEC-SEC-1)
4. **Given** no pet exists with the requested ID, **When** GET /api/pets/9999/visits is requested, **Then** the response is 404 with body exactly `{"message":"Not found"}`. (SPEC-APP-6, SPEC-INT-2)
5. **Given** a pet exists but has no visits, **When** GET /api/pets/1/visits is requested, **Then** the response is 200 with body `[]`. (SPEC-APP-6, SPEC-INT-1)
6. **Given** PetRepository is inspected at runtime, **When** its declared and inherited methods are listed, **Then** only `findById(Integer)` is present, and PetRepository is not assignable to CrudRepository or JpaRepository. (SPEC-APP-6, SPEC-DATA-2)

---

### Edge Cases

- What happens when an owner ID in the path is not a valid integer (e.g., /api/owners/abc)? The framework returns 400 before the controller is reached; no repository call is made.
- What happens when a pet's `birthDate` or a visit's `date` is null in the database? The field serialises as JSON `null`; no 500 is thrown. (SPEC-DATA-3)
- What happens when a pet's `type` is null? The `type` field serialises as JSON `null`; no 500 is thrown. (SPEC-DATA-3)
- What happens when POST, PUT, PATCH, or DELETE is sent to any /api path? The response is 405 Method Not Allowed; no repository method is called. (SPEC-INT-4, SPEC-SEC-2)
- What happens when a GET request to /api/owners/{id} includes an `Origin` header? No `Access-Control-Allow-Origin` header is returned. (SPEC-SEC-5)
- What happens when a preflight OPTIONS request is sent to an /api path? No `Access-Control-Allow-Origin` header is returned. (SPEC-SEC-5)
- What happens when lastName="Davis" and size=100 are both supplied? The page size is fixed at 5; the size parameter is ignored. (SPEC-SEC-3)
- What happens when a 404 response is returned for a distinctive ID? The response body does not echo the requested ID. (SPEC-SEC-4)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001** (SPEC-APP-1): The system MUST expose GET /api/owners/{id} returning 200 with `{firstName, lastName, address, city, telephone}` for a known owner ID, and 404 with `{"message":"Not found"}` for an unknown ID. Content-Type MUST be application/json.
- **FR-002** (SPEC-APP-2): Every API response MUST be built from dedicated response records that hold only the agreed fields. No controller method MAY return an Owner, Pet, or Visit entity directly.
- **FR-003** (SPEC-APP-3): The system MUST expose GET /api/owners?lastName=X returning 200 with `{"content":[...],"page":N,"size":5,"total":N}`. The lastName value MUST be trimmed before use. A missing, empty, or blank lastName MUST return 400 with `{"message":"lastName is required"}` before any repository call is made.
- **FR-004** (SPEC-APP-4): Owner search MUST use 1-based page numbers with a fixed page size of 5. The Pageable passed to the repository MUST be `PageRequest.of(page-1, 5)` with Sort exactly lastName → firstName → id. A page value below 1 MUST be treated as 1. A page beyond the last page MUST return 200 with empty content and the real total.
- **FR-005** (SPEC-APP-3): Owner search MUST use the existing `OwnerRepository.findByLastNameStartingWith` method unchanged, mirroring the trim-and-prefix-match behaviour of the owner search screen. The repository method and its behaviour MUST NOT be altered.
- **FR-006** (SPEC-APP-5): The system MUST expose GET /api/owners/{id}/pets returning 200 with a list of `{id, name, birthDate, type}` where `type` is the type name string only. Pets MUST be ordered by name case-insensitively with null names last, then by ID with null IDs last. An unknown owner ID MUST return 404 with `{"message":"Not found"}`. An owner with no pets MUST return `[]` with 200.
- **FR-007** (SPEC-APP-6): The system MUST expose GET /api/pets/{id}/visits returning 200 with a list of `{date, description}` ordered oldest-first with null dates last, then by ID with null IDs last. An unknown pet ID MUST return 404 with `{"message":"Not found"}`. A pet with no visits MUST return `[]` with 200.
- **FR-008** (SPEC-APP-6, SPEC-DATA-2): A new `PetRepository` interface MUST be introduced as `interface PetRepository extends Repository<Pet,Integer>` declaring only `Optional<Pet> findById(Integer)`. It MUST NOT extend CrudRepository, JpaRepository, or any interface that provides write methods.
- **FR-009** (SPEC-APP-7): Each endpoint MUST be covered by `@WebMvcTest` MockMvc tests with a mocked repository, in the style of VisitControllerTests. Test counts MUST be at least 2 for Story 1, 6 for Story 2, 4 for Story 3, and 4 for Story 4. Tests MUST include ordering and null-value cases for Stories 3 and 4.
- **FR-010** (SPEC-APP-8): Only GET mappings MAY be added under /api. No POST, PUT, PATCH, or DELETE mapping MAY be introduced. No `@ControllerAdvice` or `@RestControllerAdvice` MAY be added. Error responses MUST be built directly in the controller.
- **FR-011** (SPEC-APP-8, SPEC-INT-5): Nothing in the existing HTML templates, database scripts, Kubernetes manifests, CI workflow files, OwnerController, OwnerRepository, or domain entities MAY be changed. The existing owner search screen behaviour (blank lastName returns all owners; out-of-range page redirects; unknown ID raises IllegalArgumentException) MUST remain unchanged.
- **FR-012** (SPEC-SEC-5): The API MUST set no CORS headers. No `@CrossOrigin`, `CorsRegistry`, or `CorsConfigurationSource` MAY be introduced.
- **FR-013** (SPEC-SEC-3, SPEC-SEC-4): Error responses MUST contain only the agreed message key and MUST NOT echo request input, exception messages, stack traces, or owner PII. No owner field (name, address, telephone) MAY appear in log output.
- **FR-014** (SPEC-INT-6): Stories MUST be delivered and merged in order 1 → 2 → 3 → 4. Story 2 MAY reuse the OwnerResponse record from Story 1. A later story MUST NOT alter a response shape fixed by an earlier story.
- **FR-015** (SPEC-PLAT-1): The new test classes MUST run in the existing test task without any change to the build or pipeline files. The spring-javaformat validate and nohttp checkstyle checks MUST pass on all new files.

### Key Entities

- **OwnerResponse** (new record): Carries `firstName`, `lastName`, `address`, `city`, `telephone` — all strings. Used by Stories 1 and 2. Exposes no ID, no pet list, and no other Owner field.
- **OwnerPage** (new record): Carries `content` (list of OwnerResponse), `page` (integer, 1-based), `size` (always 5), `total` (long). Used by Story 2.
- **PetResponse** (new record): Carries `id` (integer), `name` (string), `birthDate` (ISO date string or null), `type` (string — the PetType name only). Used by Story 3. Exposes no owner reference and no visit list.
- **VisitResponse** (new record): Carries `date` (ISO date string or null), `description` (string). Used by Story 4. Exposes no ID and no pet reference.
- **ApiMessage** (new record): Carries `message` (string). Used for all error responses (404 and 400).
- **OwnerApiController** (new controller): Handles GET /api/owners/{id}, GET /api/owners, and GET /api/owners/{id}/pets. Reads from OwnerRepository only. Lives in the `owner.api` package.
- **PetApiController** (new controller): Handles GET /api/pets/{id}/visits. Reads from PetRepository only. Lives in the `owner.api` package.
- **PetRepository** (new interface): `interface PetRepository extends Repository<Pet,Integer>` with only `Optional<Pet> findById(Integer)`. No write methods. Lives in the `owner.api` package or the `owner` package.
- **Owner** (existing entity, read only): Source of firstName, lastName, address, city, telephone, and the pets collection. MUST NOT be modified.
- **Pet** (existing entity, read only): Source of id, name, birthDate, type, and the visits collection. MUST NOT be modified.
- **Visit** (existing entity, read only): Source of date and description. MUST NOT be modified.
- **PetType** (existing entity, read only): Source of the type name string. MUST NOT be modified.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **KPI-1**: GET /api/owners/{id} returns exactly the five agreed owner fields for a known ID, and returns 404 with `{"message":"Not found"}` for an unknown ID. | Metric: Story 1 MockMvc tests passing (known-ID field check, unknown-ID 404 and message body). | Target: all pass (0 failures).
- **KPI-2**: GET /api/owners?lastName= returns a page of up to 5 owners in the shape `{content, page, size, total}`, with trimmed lastName and prefix match. Page 2 is accessible via `&page=2`. A missing or blank lastName returns 400 with `{"message":"lastName is required"}`. | Metric: Story 2 MockMvc tests passing (trim, prefix match, size 5, page 2, ordering, blank and missing lastName 400). | Target: all pass (0 failures).
- **KPI-3**: GET /api/owners/{id}/pets returns `{id, name, birthDate, type}` per pet ordered by name (case-insensitive, nulls last) then ID (nulls last). Unknown owner returns 404; owner with no pets returns `[]` with 200. | Metric: Story 3 MockMvc tests passing (fields, ordering, 404, empty list). | Target: all pass (0 failures).
- **KPI-4**: GET /api/pets/{id}/visits returns `{date, description}` per visit ordered oldest-first (null dates last, then ID nulls last). Unknown pet returns 404; pet with no visits returns `[]` with 200. | Metric: Story 4 MockMvc tests passing (fields, ordering, 404, empty list). | Target: all pass (0 failures).
- **KPI-5**: Nothing outside the agreed scope changes: no HTML templates, database scripts, Kubernetes files, or CI files are modified, and no non-GET /api mapping is introduced. | Metric: Count of changed files under `src/main/resources/templates`, `src/main/resources/db`, `k8s/`, and the CI workflow directory, plus count of non-GET /api mappings in the diff. | Target: 0.
- **KPI-6**: The existing test suite passes after each story with H2 as the local database. | Metric: Count of existing tests (OwnerControllerTests, PetControllerTests, VisitControllerTests, ClinicServiceTests, PetClinicConcurrencyTests) failing after the change. | Target: 0.

## Assumptions

- The API is intentionally open (no authentication, no new security role), matching the access model of the existing HTML screens. This is an accepted deviation recorded in ADR-SEC-1 and the G1 decision record.
- The `owner.api` sub-package within the `owner` package is the correct location for all new controllers, response records, and PetRepository, keeping the modular monolith package boundary intact.
- The existing `OwnerRepository.findByLastNameStartingWith(String, Pageable)` method already accepts a `Pageable` argument and returns a `Page<Owner>`; no change to its signature or implementation is needed.
- Dates serialise as ISO yyyy-MM-dd strings by default under the existing Jackson configuration; no new Jackson module or date-format setting is required.
- The existing `@WebMvcTest` slice annotations (`@DisabledInNativeImage`, `@DisabledInAotMode`) used in VisitControllerTests are the correct pattern for the new test classes.
- The four stories are delivered as four separate pull requests merged in order 1 → 2 → 3 → 4, each gated by KPI-5 and KPI-6 before the next story begins.
- No new Maven or Gradle dependency is required; Spring MVC's built-in support for `@RestController` and `ResponseEntity` is sufficient.
- The `total` field in the owner search envelope equals `Page.getTotalElements()` from the repository result, not a separately computed count.
- Pet ordering (case-insensitive name, nulls last, then ID nulls last) and visit ordering (date oldest-first, null dates last, then ID nulls last) are implemented as in-code comparators, not as database ORDER BY clauses, per ADR-APP-9.
- The H2 local startup profile and the existing `application*.properties` files require no modification to serve the four new routes.
- No new `@ControllerAdvice` is introduced; each controller handles its own 404 and 400 responses directly, per ADR-APP-2.
- The epic "Clinic read API" is a parent item only and is not implemented by Synapse; only the four child stories are Synapse code stories.
