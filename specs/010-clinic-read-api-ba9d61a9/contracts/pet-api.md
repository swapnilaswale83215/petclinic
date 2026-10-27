# Contract: Pet API

**Controller**: `PetApiController`
**Package**: `org.springframework.samples.petclinic.owner.api`
**Base path**: `/api/pets`
**Introduced by**: Story 4 (Epic: Clinic Read API, branch `010-clinic-read-api-ba9d61a9`)

---

## Stability

This contract is **new**. No existing behaviour is preserved or constrained by this file. The single endpoint is introduced in Story 4 and must not be altered by any subsequent change without a contract amendment.

---

## Shared Constraints

The following rules apply to every endpoint in this file and are consistent with the constraints in `owner-api.md`.

| Constraint | Value |
|---|---|
| Allowed HTTP methods | GET only |
| Response `Content-Type` | `application/json` |
| CORS headers | None. `Access-Control-Allow-Origin` MUST NOT appear on any response. |
| Non-GET methods | Spring MVC returns `405 Method Not Allowed` automatically. |
| Non-integer `{id}` | Spring MVC type conversion returns `400 Bad Request` before the controller is reached; no repository call is made. |
| Error body | All error responses carry exactly `{"message":"<text>"}` with no additional fields, no stack trace, no exception class name, and no echoed request input. |
| Entity exposure | No `Pet` or `Visit` entity object is returned directly. All responses are built from the dedicated response records defined below. |

---

## Repository Contract: `PetRepository`

**Introduced by**: Story 4. This interface is the only new repository in the epic.

```java
interface PetRepository extends Repository<Pet, Integer> {
    Optional<Pet> findById(Integer id);
}
```

| Property | Value |
|---|---|
| Extends | `org.springframework.data.repository.Repository<Pet, Integer>` only |
| Declared methods | Exactly one: `Optional<Pet> findById(Integer id)` |
| Inherited write methods | None. `Repository<T,ID>` is the Spring Data marker interface and exposes no methods. |
| Assignability | MUST NOT be assignable to `CrudRepository`, `JpaRepository`, `ListCrudRepository`, or any other Spring Data interface that provides write methods. |

This constraint is verifiable at runtime by a reflection test (Story 4 acceptance scenario 6):

- The set of declared and inherited methods on `PetRepository` contains only `findById(Integer)`.
- `CrudRepository.class.isAssignableFrom(PetRepository.class)` is `false`.
- `JpaRepository.class.isAssignableFrom(PetRepository.class)` is `false`.

---

## Response Records

### `VisitResponse`

Introduced in Story 4. **Must not be altered after Story 4 merges.**

```
{
  "date":        <string "yyyy-MM-dd" or null>,
  "description": <string>
}
```

| Field | Type | Nullable | Notes |
|---|---|---|---|
| `date` | string | yes | ISO `yyyy-MM-dd` produced by `LocalDate.toString()` on `Visit.getDate()`, or `null` if the database value is null. |
| `description` | string | no | Sourced from `Visit.getDescription()`. |

**Fields that MUST NOT appear**: `id`, `pet`, or any other `Visit` field.

---

### `ApiMessage`

Defined in `owner-api.md`. Used here without modification.

```
{ "message": <string> }
```

---

## Endpoint — List Visits for a Pet

**Introduced by**: Story 4

```
GET /api/pets/{id}/visits
```

### Path Parameters

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `id` | integer | yes | Numeric pet identifier. A non-integer value causes a framework-level `400` before the controller is reached. |

### Query Parameters

None.

### Repository Interaction

The controller calls `petRepository.findById(id)`. If the result is empty, it returns `404`. If the result is present, it reads `pet.getVisits()` and applies the ordering comparator described below before mapping to `VisitResponse`.

### Ordering

Visits are ordered by an in-code comparator applied to the `Visit` entity list **before** mapping to `VisitResponse`. The comparator operates on `Visit` objects because `VisitResponse` carries no `id` field:

```
Comparator.comparing(Visit::getDate,
        Comparator.nullsLast(Comparator.naturalOrder()))
    .thenComparing(Visit::getId,
        Comparator.nullsLast(Comparator.naturalOrder()))
```

- Visits are ordered oldest date first (ascending `LocalDate` natural order).
- Null dates sort after all non-null dates.
- When two visits share the same date, they are ordered by `id` ascending.
- Null `id` values sort after all non-null `id` values.
- After sorting, the stream is mapped to `VisitResponse(date, description)`. The `id` value used for tiebreaking is not included in the response.

### Success Response

**Status**: `200 OK`

**Body**: JSON array of `VisitResponse`, ordered as above. A pet with no visits returns `[]`.

```json
[
  { "date": "2018-09-04", "description": "Annual checkup"      },
  { "date": "2021-03-17", "description": "Vaccination booster" },
  { "date": null,         "description": "Undated follow-up"   }
]
```

### Error Responses

| Status | Condition | Body |
|---|---|---|
| `404 Not Found` | No pet exists with the given `id`. | `{"message":"Not found"}` |

### Invariants

- Each item contains exactly `date` and `description`. No `id`, `pet`, or other field is present.
- `date` serialises as JSON `null` when the database value is null; no `500` is thrown.
- A pet with no visits returns `200` with body `[]`, not `404`.
- The `404` body does not echo the requested `id` value.
- The ordering tiebreak uses `Visit.getId()` internally; this value is never exposed in the response.

---

## Constraints That Must Not Break (Existing Behaviour)

The following existing behaviours are unaffected by Story 4 and must remain unchanged after it merges.

| Behaviour | Location | Verification |
|---|---|---|
| `GET /owners/{id}/pets/{petId}` (HTML) returns the pet edit form via Thymeleaf | `PetController` | `PetControllerTests` |
| `GET /owners/{id}/pets/{petId}/visits/new` (HTML) renders the new-visit form | `VisitController` | `VisitControllerTests` |
| All domain entity fields and relationships on `Pet` and `Visit` | `Pet.java`, `Visit.java` | `ClinicServiceTests` |
| The three endpoints introduced in Stories 1–3 (`owner-api.md`) | `OwnerApiController` | `OwnerApiControllerTests` |
| `OwnerRepository` signature and behaviour | `OwnerRepository` | `ClinicServiceTests` |

---

## NEEDS CLARIFICATION

| ID | Question | Blocking |
|---|---|---|
| NC-1 | Whether the existing `@EnableJpaRepositories` (or Spring Boot auto-configuration) scans the `owner.api` sub-package. If scanning is restricted to `owner`, `PetRepository` must move to the `owner` package. The interface declaration and this contract are unchanged either way. | Story 4 build |
