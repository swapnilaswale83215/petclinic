# research.md

**Feature**: Clinic Read API (010-clinic-read-api-ba9d61a9)
**Date**: 2026-10-27
**Status**: Complete — all items resolved or explicitly marked NEEDS CLARIFICATION

---

## R-001 — Package location for new classes

**Question**: Where exactly do the new controllers, response records, and PetRepository live?

**Decision**: All new production classes (`OwnerApiController`, `PetApiController`, `OwnerResponse`, `OwnerPage`, `PetResponse`, `VisitResponse`, `ApiMessage`, `PetRepository`) are placed in the `org.springframework.samples.petclinic.owner.api` sub-package.

**Rationale**: The spec assumption states "the `owner.api` sub-package within the `owner` package is the correct location … keeping the modular monolith package boundary intact." The constitution (Principle I) requires that the `owner` package owns Owner, Pet, PetType, Visit, and related controllers/repositories. A dedicated `owner.api` child package keeps the new REST surface inside that boundary without polluting the existing `owner` package namespace. The constitution also prohibits cross-package dependencies unless explicitly justified; placing everything in `owner.api` avoids any such dependency.

**Alternatives considered**:
- `owner` package directly: rejected — would mix new REST classes with existing MVC classes and make the boundary harder to enforce.
- A top-level `api` package: rejected — would cross the `owner` package boundary and violate Principle I.
- `owner.api` for controllers/records, `owner` for PetRepository: the spec notes PetRepository "lives in the `owner.api` package or the `owner` package." Either is acceptable; `owner.api` is preferred for consistency, but `owner` is a valid fallback if the Spring Data scanning configuration requires it.

---

## R-002 — PetRepository placement and Spring Data scanning

**Question**: Will Spring Data's component scan pick up `PetRepository` if it is placed in `owner.api` rather than `owner`?

**Decision**: Place `PetRepository` in `owner.api` and verify that the existing `@EnableJpaRepositories` (or equivalent auto-configuration) scans that sub-package. If scanning is restricted to `owner` only, move `PetRepository` to `owner`.

**Rationale**: Spring Boot's auto-configuration scans from the application root package downward by default. Because `owner.api` is a sub-package of `owner`, it falls within the default scan path of `PetClinicApplication`. No explicit `@EnableJpaRepositories(basePackages = …)` override is expected to be present that would exclude it. The spec assumption confirms no new Maven/Gradle dependency is required, implying the existing Spring Data infrastructure is sufficient.

**Alternatives considered**:
- Placing PetRepository in `owner`: safe fallback; the spec explicitly allows it.
- Adding a `@EnableJpaRepositories` annotation scoped to `owner.api`: unnecessary complexity; default scanning should suffice.

**Residual uncertainty**: The actual `@EnableJpaRepositories` configuration in the repository is not provided. If it restricts scanning, PetRepository must move to `owner`. NEEDS CLARIFICATION if the build fails on Story 4.

---

## R-003 — PetRepository interface declaration

**Question**: How must PetRepository be declared to satisfy FR-008 and the Story 4 reflection test?

**Decision**: Declare as:

```java
interface PetRepository extends Repository<Pet, Integer> {
    Optional<Pet> findById(Integer id);
}
```

It must not extend `CrudRepository`, `JpaRepository`, `ListCrudRepository`, or any other Spring Data interface that exposes write methods. The interface must be package-private (no `public` modifier) unless the controller in the same package requires it to be public, in which case `public` is acceptable.

**Rationale**: FR-008 is explicit: "interface PetRepository extends Repository<Pet,Integer> declaring only Optional<Pet> findById(Integer)." The Story 4 acceptance scenario requires a reflection test that "only `findById(Integer)` is present, and PetRepository is not assignable to CrudRepository or JpaRepository." `Repository<T,ID>` is the Spring Data marker interface that provides no methods of its own, so the only method visible via reflection will be the declared `findById`. Spring Data will still generate a JPA-backed implementation because `Repository` is the root of the Spring Data hierarchy.

**Alternatives considered**:
- Extending `CrudRepository`: rejected — exposes `save`, `delete`, and other write methods, violating FR-008 and the reflection test.
- Extending `JpaRepository`: rejected — same reason, plus adds flush and batch methods.
- Not extending any Spring Data interface and using `EntityManager` directly: rejected — would require an explicit implementation class, contradicting the constitution's rule that repository interfaces must use auto-generated implementations.

---

## R-004 — Response record design and Jackson serialisation

**Question**: How should the response records be declared so that Jackson serialises only the agreed fields with no extras?

**Decision**: Declare each as a Java record. Jackson serialises records by mapping each record component to a JSON field using the component name. Because records have no additional fields beyond their components, no `@JsonIgnore` or `@JsonInclude` annotations are needed to suppress extras. The agreed declarations are:

- `record OwnerResponse(String firstName, String lastName, String address, String city, String telephone)`
- `record OwnerPage(List<OwnerResponse> content, int page, int size, long total)`
- `record PetResponse(Integer id, String name, String birthDate, String type)`
- `record VisitResponse(String date, String description)`
- `record ApiMessage(String message)`

`birthDate` and `date` are stored as `String` (pre-formatted ISO yyyy-MM-dd) rather than `LocalDate` to avoid any dependency on Jackson's JavaTimeModule configuration.

**Rationale**: The spec assumption states "Dates serialise as ISO yyyy-MM-dd strings by default under the existing Jackson configuration; no new Jackson module or date-format setting is required." Using `String` for date fields makes this assumption concrete and removes any risk of Jackson serialising a `LocalDate` as an array `[2010,9,7]` if the JavaTimeModule is absent. The spec requires `birthDate` and `date` to be "ISO yyyy-MM-dd or null"; a `String` field serialises as JSON `null` when the Java value is `null`, satisfying SPEC-DATA-3.

**Alternatives considered**:
- Using `LocalDate` fields with `@JsonSerialize(using = LocalDateSerializer.class)`: would work if JavaTimeModule is registered, but introduces a dependency on the existing Jackson configuration that is not confirmed.
- Using `java.util.Date`: deprecated and not ISO-friendly without a custom serialiser.
- Using `@JsonProperty` on entity fields: rejected — FR-002 prohibits returning entities directly.

**Residual uncertainty**: Whether the existing Jackson configuration registers `jackson-datatype-jsr310` is not confirmed by the provided inputs. Using `String` eliminates this risk entirely. NEEDS CLARIFICATION only if a future story requires `LocalDate` arithmetic on the response side.

---

## R-005 — Date formatting: LocalDate to ISO string conversion

**Question**: How should `LocalDate` (or `java.util.Date`) values from the domain entities be converted to ISO yyyy-MM-dd strings in the response records?

**Decision**: In the controller mapping logic, call `date.toString()` on a non-null `LocalDate` (which produces ISO yyyy-MM-dd by contract in Java 8+), or `null` if the field is null. Assign the result to the `String` field of the response record.

**Rationale**: `LocalDate.toString()` is specified by the Java SE API to return the date in ISO-8601 format `yyyy-MM-dd`. This requires no formatter object, no configuration, and no additional dependency. The spec assumption confirms no new Jackson module is required, and using a pre-formatted string in the record means Jackson never needs to interpret the date type.

**Alternatives considered**:
- `DateTimeFormatter.ISO_LOCAL_DATE.format(date)`: equivalent result, slightly more verbose.
- Relying on Jackson's `LocalDateSerializer`: depends on JavaTimeModule being registered; not confirmed.
- `String.format("%tF", date)`: works for `java.util.Date` but not `LocalDate`; not applicable here.

---

## R-006 — In-code ordering comparators (ADR-APP-9)

**Question**: How should the in-code comparators for pet name ordering and visit date ordering be implemented?

**Decision**:

**Pet ordering** (FR-006, ADR-APP-9):
```
Comparator.comparing(PetResponse::name,
    Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER))
  .thenComparing(PetResponse::id,
    Comparator.nullsLast(Comparator.naturalOrder()))
```

**Visit ordering** (FR-007, ADR-APP-9):
```
Comparator.comparing(VisitResponse::date,
    Comparator.nullsLast(Comparator.naturalOrder()))
  .thenComparing(VisitResponse::id, ...)
```

However, `VisitResponse` does not carry an `id` field (FR-007 and Story 4 acceptance scenario 3 require exactly `date` and `description` with no `id`). The tiebreak by ID must therefore be applied before mapping to `VisitResponse`, i.e., on the `Visit` entity stream before projection.

**Rationale**: The spec is explicit that ordering is in-code, not via ORDER BY (ADR-APP-9). `String.CASE_INSENSITIVE_ORDER` implements case-insensitive lexicographic ordering as required. `Comparator.nullsLast` places null values after non-null values. For visits, because `VisitResponse` has no `id`, the ID tiebreak must be applied on the `Visit` entity list before converting to `VisitResponse`; the comparator chain operates on `Visit` objects, then the sorted stream is mapped to `VisitResponse`.

**Alternatives considered**:
- Database ORDER BY: rejected per ADR-APP-9; also not possible without modifying repository queries.
- `Collator.getInstance()` for locale-aware case-insensitive ordering: more correct for non-ASCII names but introduces locale dependency; `String.CASE_INSENSITIVE_ORDER` is sufficient for the test cases specified.
- Carrying `id` in `VisitResponse` and sorting after mapping: rejected — Story 4 acceptance scenario 3 explicitly prohibits an `id` field in the visit response.

---

## R-007 — 1-based pagination and page-size enforcement

**Question**: How should the controller translate the incoming `page` query parameter into a Spring Data `Pageable`, and how should it enforce the fixed page size of 5?

**Decision**:

1. Bind `page` as an `int` (or `Integer`) query parameter with a default value of `1`.
2. Clamp: `int safePage = Math.max(1, page)` (FR-004: "a page value below 1 MUST be treated as 1").
3. Construct: `PageRequest.of(safePage - 1, 5, Sort.by("lastName").and(Sort.by("firstName")).and(Sort.by("id")))`.
4. Never read a `size` parameter from the request; the size is always 5 (FR-004, SPEC-SEC-3).
5. The `page` field in the response envelope is always `safePage` (1-based), not the zero-based index passed to `PageRequest`.

**Rationale**: FR-004 is explicit about the `PageRequest.of(page-1, 5)` construction and the Sort order. Ignoring the `size` parameter satisfies SPEC-SEC-3 (Story 2 acceptance scenario 8). Clamping to 1 satisfies Story 2 acceptance scenario 4. Returning `Page.getTotalElements()` as `total` satisfies the spec assumption about the `total` field.

**Alternatives considered**:
- Binding `page` as `String` and parsing after the `lastName` check: the spec risk note (DEF-5) raises this for the case where a non-numeric `page` would fail type conversion before the `lastName` blank check. The spec mitigates this by suggesting String binding. However, the spec also states "Non-numeric values stay outside the contract," and the framework returning 400 for a non-numeric path variable is already documented as acceptable behaviour. For the `page` query parameter, binding as `String` and parsing manually after the `lastName` check is the safer approach if the ordering of validation matters; binding as `int` is simpler. **Decision deferred to Story 2 implementation**: either approach passes the specified acceptance scenarios. NEEDS CLARIFICATION on whether the ordering of the 400 response (lastName blank vs. non-numeric page) is tested.
- Using `Pageable` as a method parameter with Spring MVC's `PageableHandlerMethodArgumentResolver`: would allow Spring to parse `page` and `size` automatically, but would also allow `size` to be overridden by the caller unless `PageableHandlerMethodArgumentResolver.setMaxPageSize(5)` is configured. Constructing `PageRequest` manually is simpler and more explicit.

---

## R-008 — lastName blank/missing validation and ordering relative to other checks

**Question**: How should the controller validate the `lastName` parameter, and must this check precede all other processing?

**Decision**:

1. Declare `lastName` as `@RequestParam(required = false) String lastName`.
2. After receiving the parameter, check: `if (lastName == null || lastName.trim().isEmpty())` → return `ResponseEntity.badRequest().body(new ApiMessage("lastName is required"))` immediately, without calling the repository.
3. Otherwise, trim: `String trimmed = lastName.trim()`.
4. Proceed to construct `PageRequest` and call the repository.

**Rationale**: FR-003 requires "a missing, empty, or blank lastName MUST return 400 … before any repository call is made." Story 2 acceptance scenarios 6 and 7 confirm this for absent, empty, and whitespace-only values. Declaring `required = false` allows the controller to receive `null` when the parameter is absent and handle it explicitly, rather than letting Spring throw a `MissingServletRequestParameterException` (which would produce a 400 but not with the agreed body `{"message":"lastName is required"}`).

**Alternatives considered**:
- `@RequestParam(required = true)`: Spring would return 400 automatically for a missing parameter, but the body would not be `{"message":"lastName is required"}` — it would be Spring's default error body. Rejected.
- Bean Validation (`@NotBlank`): would require a `@ControllerAdvice` to produce the agreed error body. FR-010 prohibits `@ControllerAdvice`. Rejected.
- Checking blank before checking page validity: consistent with FR-003's "before any repository call" requirement. The `page` parameter is only used after `lastName` passes validation, so the ordering is naturally correct.

---

## R-009 — Error response construction without ControllerAdvice

**Question**: How should 404 and 400 responses be built given that FR-010 prohibits `@ControllerAdvice`?

**Decision**: Each controller method returns `ResponseEntity<?>`. On the happy path it returns `ResponseEntity.ok(responseRecord)`. On error it returns:
- 404: `ResponseEntity.status(HttpStatus.NOT_FOUND).body(new ApiMessage("Not found"))`
- 400: `ResponseEntity.badRequest().body(new ApiMessage("lastName is required"))`

The `ApiMessage` record carries only `message`, so the serialised body is exactly `{"message":"Not found"}` or `{"message":"lastName is required"}`.

**Rationale**: FR-010 is explicit: "No `@ControllerAdvice` or `@RestControllerAdvice` MAY be added. Error responses MUST be built directly in the controller." Using `ResponseEntity<?>` with a wildcard type allows the same method to return either the success record or `ApiMessage`. FR-013 requires that error responses contain only the agreed message key and must not echo request input, exception messages, or stack traces; building the response directly in the controller with a fixed string literal satisfies this.

**Alternatives considered**:
- `@ExceptionHandler` within the controller class (not a `@ControllerAdvice`): technically permitted by FR-010, but adds indirection for a simple case. Direct construction is clearer.
- Throwing a custom exception and relying on Spring's default error handling: would produce Spring's default error body (with `timestamp`, `status`, `error`, `path`), not `{"message":"Not found"}`. Rejected.

---

## R-010 — CORS: ensuring no CORS headers are emitted

**Question**: What is required to ensure no `Access-Control-Allow-Origin` header is present on any `/api` response?

**Decision**: Take no action. Do not add `@CrossOrigin`, `CorsRegistry`, or `CorsConfigurationSource`. The absence of any CORS configuration means Spring MVC will not add CORS headers to any response.

**Rationale**: FR-012 states "The API MUST set no CORS headers. No `@CrossOrigin`, `CorsRegistry`, or `CorsConfigurationSource` MAY be introduced." Story 1 acceptance scenario 3 and the edge cases section confirm that no `Access-Control-Allow-Origin` header should be present even when an `Origin` header is sent or a preflight OPTIONS request is made. Spring MVC only adds CORS headers when explicitly configured to do so; without configuration, no headers are added.

**Alternatives considered**:
- Adding `@CrossOrigin` with an empty `origins` array: would still register a CORS configuration and might produce unexpected behaviour. Rejected.
- Configuring a `CorsConfigurationSource` that returns an empty configuration: unnecessary and prohibited by FR-012.

**Residual uncertainty**: If the existing application already has a global `WebMvcConfigurer` that adds CORS headers for all paths, the new `/api` routes would inherit that configuration. The constitution and spec do not mention any existing CORS configuration. NEEDS CLARIFICATION if Story 1's CORS test fails despite no new CORS configuration being added.

---

## R-011 — Preventing non-GET methods on /api paths

**Question**: How should the API ensure that POST, PUT, PATCH, and DELETE return 405 without adding any mapping for those methods?

**Decision**: Take no action beyond using `@GetMapping`. Spring MVC automatically returns 405 Method Not Allowed when a request method is not mapped for a path that has at least one mapping. Because only `@GetMapping` annotations are added under `/api`, any other HTTP method to those paths will receive 405.

**Rationale**: FR-010 states "Only GET mappings MAY be added under /api." The edge cases section confirms "POST, PUT, PATCH, or DELETE is sent to any /api path → the response is 405 Method Not Allowed." This is Spring MVC's default behaviour when a path is known but the method is not mapped.

**Alternatives considered**:
- Explicitly mapping other methods to return 405: unnecessary; Spring handles this automatically.
- Using `@RequestMapping(method = RequestMethod.GET)` instead of `@GetMapping`: equivalent; `@GetMapping` is preferred for clarity.

---

## R-012 — Handling non-integer path variables (e.g., /api/owners/abc)

**Question**: What happens when a non-integer value is supplied for `{id}` in `/api/owners/{id}` or `/api/pets/{id}`?

**Decision**: No special handling is required. Spring MVC's type conversion will fail before the controller method is invoked, and the framework will return 400 Bad Request automatically.

**Rationale**: The edge cases section states "The framework returns 400 before the controller is reached; no repository call is made." This is Spring MVC's default behaviour for a path variable that cannot be converted to the declared type (`Integer` or `int`). No controller code or `@ControllerAdvice` is needed.

**Alternatives considered**:
- Declaring the path variable as `String` and parsing manually: unnecessary complexity; the framework handles this correctly.
- Adding a `@ControllerAdvice` for `MethodArgumentTypeMismatchException`: prohibited by FR-010.

---

## R-013 — Null-safe handling of Pet.type and Pet.birthDate

**Question**: How should the controller handle a `Pet` whose `type` (PetType) or `birthDate` is null?

**Decision**:

- `birthDate`: `pet.getBirthDate() != null ? pet.getBirthDate().toString() : null` → serialises as JSON `null`.
- `type`: `pet.getType() != null ? pet.getType().getName() : null` → serialises as JSON `null`.

Both are assigned to `String` fields in `PetResponse`, so Jackson serialises `null` Java strings as JSON `null`.

**Rationale**: SPEC-DATA-3 requires "a pet's `birthDate` or a visit's `date` is null in the database → the field serialises as JSON `null`; no 500 is thrown." The spec risk note (DEF-9) flags that a null `type` is untested in the original spec but should be handled. Using a ternary null-check in the mapping logic is the simplest approach and requires no Jackson configuration.

**Alternatives considered**:
- `Optional.ofNullable(pet.getType()).map(PetType::getName).orElse(null)`: equivalent; either style is acceptable.
- `@JsonInclude(NON_NULL)` on the record: would omit the field entirely when null, rather than serialising it as `null`. The spec requires the field to be present as `null`, not absent. Rejected.

---

## R-014 — Test class structure and MockMvc slice annotations

**Question**: What annotations and structure should the new `@WebMvcTest` test classes use?

**Decision**: Follow the pattern of `VisitControllerTests` exactly:
- Annotate with `@WebMvcTest(OwnerApiController.class)` (or `PetApiController.class`).
- Include `@DisabledInNativeImage` and `@DisabledInAotMode` as used in `VisitControllerTests`.
- Mock the repository with `@MockBean`.
- Use `MockMvc` injected via `@Autowired`.
- Each test class lives in the same package as its controller (`owner.api`) under `src/test/java`.

**Rationale**: The spec assumption states "`@WebMvcTest` slice annotations (`@DisabledInNativeImage`, `@DisabledInAotMode`) used in VisitControllerTests are the correct pattern for the new test classes." FR-009 requires tests "in the style of VisitControllerTests." The constitution requires `@WebMvcTest` with Mockito-based mocking for all controller classes.

**Alternatives considered**:
- Full `@SpringBootTest` integration tests: heavier, slower, and not the required pattern.
- `@ExtendWith(MockitoExtension.class)` without `@WebMvcTest`: would not provide MockMvc or the Spring MVC dispatch pipeline needed to test status codes, content types, and response bodies.

---

## R-015 — spring-javaformat and nohttp compliance

**Question**: What formatting rules must new files follow to pass the `spring-javaformat` validate and `nohttp` checkstyle checks?

**Decision**:
- Use tabs (not spaces) for indentation, as required by spring-javaformat.
- Do not use `http://` URLs in any source file, Javadoc, or comment (nohttp check).
- Follow the import ordering enforced by spring-javaformat (static imports last, alphabetical within groups).
- Do not add trailing whitespace.
- Ensure all files end with a newline.

**Rationale**: FR-015 states "The spring-javaformat validate and nohttp checkstyle checks MUST pass on all new files." The spec risk note (DEF-7) flags this as a potential failure point. The spring-javaformat plugin enforces a specific style (tabs, import order, blank lines) that differs from standard IDE defaults. The nohttp plugin rejects any `http://` literal in source files.

**Alternatives considered**:
- Running the formatter locally before committing: the correct approach; the `mvnw spring-javaformat:apply` goal applies the format automatically.
- Disabling the checks for new files: not possible without modifying build files, which is prohibited by FR-011 and KPI-5.

**Residual uncertainty**: The exact version of spring-javaformat in use and any project-specific overrides to the checkstyle configuration are not provided. NEEDS CLARIFICATION if the CI pipeline fails on a formatting rule not covered above.

---

## R-016 — Existing OwnerRepository.findByLastNameStartingWith signature

**Question**: Does `OwnerRepository.findByLastNameStartingWith` already accept a `Pageable` argument and return `Page<Owner>`?

**Decision**: Treat this as confirmed per the spec assumption: "The existing `OwnerRepository.findByLastNameStartingWith(String, Pageable)` method already accepts a `Pageable` argument and returns a `Page<Owner>`; no change to its signature or implementation is needed."

**Rationale**: FR-005 requires using this method unchanged. The spec assumption explicitly confirms the signature. The existing owner search screen already uses pagination (the spec notes "out-of-range page redirects" as existing behaviour), which implies the repository already supports `Pageable`.

**Alternatives considered**:
- Introducing a new overload: prohibited by FR-005 and FR-011.
- Using a custom `@Query`: unnecessary and would alter the repository, violating FR-011.

**Residual uncertainty**: The actual source of `OwnerRepository` is not provided. NEEDS CLARIFICATION only if the build fails because the method signature differs. In that case, Story 2 must not alter the repository; an alternative query method would need to be discussed with the approver.

---

## R-017 — No new Maven/Gradle dependency required

**Question**: Are any new dependencies needed for the four stories?

**Decision**: No new dependencies are required. Spring MVC's `@RestController`, `ResponseEntity`, Spring Data's `Repository<T,ID>`, and Java records are all available in the existing dependency set.

**Rationale**: The spec assumption is explicit: "No new Maven or Gradle dependency is required; Spring MVC's built-in support for `@RestController` and `ResponseEntity` is sufficient." Java records require Java 16+ (or Java 14+ as a preview feature); Spring Boot 3.x requires Java 17+, so records are available. FR-015 prohibits changes to build files.

**Alternatives considered**:
- Adding `jackson-datatype-jsr310` for `LocalDate` serialisation: avoided by using `String` for date fields (R-004, R-005).
- Adding `springdoc-openapi` for API documentation: out of scope; not mentioned in the spec.

---

## R-018 — Scope boundary: no changes to existing files

**Question**: Which existing files must not be touched?

**Decision**: The following are explicitly frozen:
- `src/main/resources/templates/**` (HTML templates)
- `src/main/resources/db/**` (database scripts)
- `k8s/**` (Kubernetes manifests)
- `.github/workflows/**` (CI workflow files)
- `OwnerController.java` and its tests
- `OwnerRepository.java`
- `Owner.java`, `Pet.java`, `Visit.java`, `PetType.java` (domain entities)
- `pom.xml` / `build.gradle` / `build.gradle.kts` (build files)
- Any `application*.properties` or `application*.yml` configuration files

**Rationale**: FR-011 lists these explicitly. KPI-5 measures zero changed files in templates, db, k8s, and CI directories. The spec assumption confirms "The H2 local startup profile and the existing `application*.properties` files require no modification."

**Alternatives considered**: None; this is a hard constraint.

---

## R-019 — OwnerResponse reuse across Story 1 and Story 2

**Question**: Should `OwnerResponse` be defined once in Story 1 and reused in Story 2, or defined separately?

**Decision**: Define `OwnerResponse` once in Story 1 as part of the `owner.api` package. Story 2's `OwnerPage` record references `List<OwnerResponse>` from the same package. No duplication.

**Rationale**: FR-014 states "Story 2 MAY reuse the OwnerResponse record from Story 1. A later story MUST NOT alter a response shape fixed by an earlier story." Reusing the record is the correct approach; it avoids duplication and ensures the field set is identical between the single-owner and search-results responses.

**Alternatives considered**:
- Defining a separate `OwnerSummaryResponse` for search results: unnecessary; the field sets are identical per the spec.
- Altering `OwnerResponse` in Story 2: prohibited by FR-014.

---

## R-020 — Search result chainability (DEF-1 risk)

**Question**: Should `OwnerResponse` include an `id` field to allow clients to chain from search results to `/api/owners/{id}`?

**Decision**: NEEDS CLARIFICATION. The spec risk note (DEF-1) flags this explicitly: "The G2 or G1 approver decides whether to add id to the story 2 record and its key-set tests." The current spec and acceptance scenarios for Story 1 explicitly require that no `id` field is present in `OwnerResponse` (Story 1 acceptance scenario 1: "no `id`, `pets`, or other field present"). Until the approver decides otherwise, `OwnerResponse` has no `id` field.

**Rationale**: The spec is explicit that the absence of `id` is tested. Adding `id` would change the Story 1 response shape, which FR-014 prohibits once Story 1 is merged. This decision must be made before Story 1 is merged if `id` is desired.

**Alternatives considered**:
- Adding `id` to `OwnerResponse` in Story 1: possible before merge; requires approver sign-off and updating Story 1 acceptance scenario 1.
- Adding a separate `OwnerSearchResponse` with `id` for Story 2: would require a separate record and a different response shape for search vs. single-owner lookup.

---

## R-021 — CI/CD pipeline and deployment mechanism (DEF-7 risk)

**Question**: How does the main branch reach a deployed environment after merge?

**Decision**: NEEDS CLARIFICATION. The spec risk note (DEF-7) states "The CI workflow and the redeploy mechanism are unconfirmed." The plan notes "The release owner says at G1 how main reaches an environment." This is outside the scope of the four code stories; the stories only require that the CI pipeline passes (FR-015, KPI-6).

**Rationale**: The four stories do not introduce infrastructure changes. The existing CI pipeline (GitHub Actions) runs the full Maven/Gradle build and test suite. No new workflow steps are needed. Deployment is a G1 concern.

---

## R-022 — Pre-existing test failures as baseline (DEF-2 risk)

**Question**: How should KPI-6 ("0 existing test failures") be interpreted if a test is already failing on main before Story 1 begins?

**Decision**: Story 1's pull request must document any pre-existing failures found on the base branch. KPI-6 is interpreted as "0 failures introduced by the story's changes," not "0 failures in the entire suite." Any failure present on main before Story 1 is noted as a pre-existing defect and excluded from KPI-6 measurement for that story.

**Rationale**: The spec risk note (DEF-2) states "Story 1's pull request must name any pre-existing failure and serve as the baseline." This is a process decision, not a code decision.

---

## Summary of NEEDS CLARIFICATION items

| ID | Item | Blocking story |
|----|------|---------------|
| NC-1 | Whether `@EnableJpaRepositories` scanning covers `owner.api`; if not, PetRepository moves to `owner` | Story 4 |
| NC-2 | Whether binding `page` as `int` vs. `String` matters for the ordering of 400 responses (lastName blank vs. non-numeric page) | Story 2 |
| NC-3 | Whether any existing global `WebMvcConfigurer` adds CORS headers that would affect `/api` routes | Story 1 |
| NC-4 | Whether `OwnerResponse` should include `id` for search-result chainability (DEF-1); must be decided before Story 1 merges | Story 1 |
| NC-5 | Exact spring-javaformat version and any project-specific checkstyle overrides | All stories |
| NC-6 | Actual `OwnerRepository.findByLastNameStartingWith` signature (assumed confirmed by spec; verify at build time) | Story 2 |
| NC-7 | Deployment/redeploy mechanism post-merge (G1 concern; does not block code stories) | None |
| NC-8 | Pre-existing test failures on main branch (baseline for KPI-6; document in Story 1 PR) | Story 1 |
