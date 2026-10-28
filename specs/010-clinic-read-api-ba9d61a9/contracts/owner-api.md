# Contract: Owner API

**Controller**: `OwnerApiController`
**Package**: `org.springframework.samples.petclinic.owner.api`
**Base path**: `/api/owners`
**Introduced by**: Stories 1, 2, 3 (Epic: Clinic Read API, branch `010-clinic-read-api-ba9d61a9`)

---

## Stability

This contract is **new**. No existing behaviour is preserved or constrained by this file. All three endpoints are introduced together across Stories 1–3 and must not be altered by Story 4 or any later change without a contract amendment.

---

## Shared Constraints

The following rules apply to every endpoint in this file.

| Constraint | Value |
|---|---|
| Allowed HTTP methods | GET only |
| Response `Content-Type` | `application/json` |
| CORS headers | None. `Access-Control-Allow-Origin` MUST NOT appear on any response, including responses to requests that carry an `Origin` header or a preflight `OPTIONS` request. |
| Non-GET methods | Spring MVC returns `405 Method Not Allowed` automatically; no controller mapping is added for other methods. |
| Non-integer `{id}` | Spring MVC type conversion returns `400 Bad Request` before the controller is reached; no repository call is made. |
| Error body | All error responses carry exactly `{"message":"<text>"}` with no additional fields, no stack trace, no exception class name, and no echoed request input or owner PII. |
| Entity exposure | No `Owner`, `Pet`, `PetType`, or `Visit` entity object is returned directly. All responses are built from the dedicated response records defined below. |

---

## Response Records

### `OwnerResponse`

Introduced in Story 1. Used by both the single-owner endpoint (Story 1) and the search envelope (Story 2). **Must not be altered after Story 1 merges.**

```
{
  "firstName":  <string>,
  "lastName":   <string>,
  "address":    <string>,
  "city":       <string>,
  "telephone":  <string>
}
```

| Field | Type | Nullable | Notes |
|---|---|---|---|
| `firstName` | string | no | Sourced from `Owner.getFirstName()` |
| `lastName` | string | no | Sourced from `Owner.getLastName()` |
| `address` | string | no | Sourced from `Owner.getAddress()` |
| `city` | string | no | Sourced from `Owner.getCity()` |
| `telephone` | string | no | Sourced from `Owner.getTelephone()` |

**Fields that MUST NOT appear**: `id`, `pets`, or any other `Owner` field.

---

### `OwnerPage`

Introduced in Story 2.

```
{
  "content": [ <OwnerResponse>, ... ],
  "page":    <integer, 1-based>,
  "size":    <integer, always 5>,
  "total":   <long>
}
```

| Field | Type | Notes |
|---|---|---|
| `content` | array of `OwnerResponse` | May be empty when the requested page is beyond the last page. |
| `page` | integer | 1-based. Equals the clamped `safePage` value passed to the controller, not the zero-based index given to `PageRequest`. |
| `size` | integer | Always `5`. Never reflects a caller-supplied `size` parameter. |
| `total` | long | Equals `Page.getTotalElements()` from the repository result. |

---

### `ApiMessage`

Introduced in Story 1. Used for all error responses across all endpoints in this file and in `pet-api.md`.

```
{ "message": <string> }
```

| Field | Type | Notes |
|---|---|---|
| `message` | string | Fixed literal per error case; never echoes request input. |

---

## Endpoint 1 — Retrieve a Single Owner by ID

**Introduced by**: Story 1

```
GET /api/owners/{id}
```

### Path Parameters

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `id` | integer | yes | Numeric owner identifier. A non-integer value causes a framework-level `400` before the controller is reached. |

### Query Parameters

None.

### Success Response

**Status**: `200 OK`

**Body**: `OwnerResponse`

```json
{
  "firstName": "George",
  "lastName":  "Franklin",
  "address":   "110 W. Liberty St.",
  "city":      "Madison",
  "telephone": "6085551023"
}
```

### Error Responses

| Status | Condition | Body |
|---|---|---|
| `404 Not Found` | No owner exists with the given `id`. | `{"message":"Not found"}` |

### Invariants

- The response body contains exactly the five fields listed in `OwnerResponse`. No `id`, `pets`, or other field is present.
- The `404` body does not echo the requested `id` value.
- No `Access-Control-Allow-Origin` header is present even when the request carries an `Origin` header.

---

## Endpoint 2 — Search Owners by Last Name with Pagination

**Introduced by**: Story 2

```
GET /api/owners?lastName={prefix}[&page={n}]
```

### Query Parameters

| Parameter | Type | Required | Default | Notes |
|---|---|---|---|---|
| `lastName` | string | yes (validated in controller) | — | Declared `required = false` in the controller so that a missing parameter is caught by the blank-check rather than by Spring's parameter binding. Leading and trailing whitespace is stripped before use. |
| `page` | integer | no | `1` | 1-based. Values below `1` are treated as `1`. A value beyond the last page returns `200` with empty `content`. |
| `size` | — | — | — | **Ignored.** The page size is fixed at `5` regardless of any `size` parameter supplied by the caller. |

### Validation

The `lastName` check is performed before any other processing:

1. If `lastName` is absent from the query string → `400` with `{"message":"lastName is required"}`. Repository is not called.
2. If `lastName` is present but blank (empty string or whitespace only after trimming) → `400` with `{"message":"lastName is required"}`. Repository is not called.
3. Otherwise, trim `lastName` and proceed.

### Repository Call

```
ownerRepository.findByLastNameStartingWith(
    trimmedLastName,
    PageRequest.of(safePage - 1, 5,
        Sort.by("lastName")
            .and(Sort.by("firstName"))
            .and(Sort.by("id")))
)
```

- `safePage = Math.max(1, page)`
- The `Sort` order is exactly `lastName → firstName → id`. No other sort order is used.
- The existing `OwnerRepository.findByLastNameStartingWith(String, Pageable)` method is called unchanged.

### Success Response

**Status**: `200 OK`

**Body**: `OwnerPage`

```json
{
  "content": [
    {
      "firstName": "Betty",
      "lastName":  "Davis",
      "address":   "638 Cardinal Ave.",
      "city":      "Sun Prairie",
      "telephone": "6085551749"
    }
  ],
  "page":  1,
  "size":  5,
  "total": 2
}
```

When the requested page is beyond the last page, `content` is `[]` and `total` reflects the real total element count from the repository.

### Error Responses

| Status | Condition | Body |
|---|---|---|
| `400 Bad Request` | `lastName` is absent, empty, or blank. | `{"message":"lastName is required"}` |

### Invariants

- Each item in `content` is an `OwnerResponse` with exactly the five agreed fields; no `id` or other field is present.
- `size` in the response body is always `5`, never a caller-supplied value.
- The trimmed `lastName` value (not the raw input) is passed to the repository. This is verifiable via `ArgumentCaptor` in tests.
- `page` in the response body is the 1-based `safePage`, not the zero-based index.
- `total` equals `Page.getTotalElements()`.

---

## Endpoint 3 — List Pets for an Owner

**Introduced by**: Story 3

```
GET /api/owners/{id}/pets
```

### Path Parameters

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `id` | integer | yes | Numeric owner identifier. A non-integer value causes a framework-level `400`. |

### Query Parameters

None.

### Response Record: `PetResponse`

```
{
  "id":        <integer or null>,
  "name":      <string or null>,
  "birthDate": <string "yyyy-MM-dd" or null>,
  "type":      <string or null>
}
```

| Field | Type | Nullable | Notes |
|---|---|---|---|
| `id` | integer | yes | Sourced from `Pet.getId()`. |
| `name` | string | yes | Sourced from `Pet.getName()`. |
| `birthDate` | string | yes | ISO `yyyy-MM-dd` produced by `LocalDate.toString()`, or `null` if `Pet.getBirthDate()` is null. |
| `type` | string | yes | The `PetType` name string from `Pet.getType().getName()`, or `null` if `Pet.getType()` is null. |

**Fields that MUST NOT appear**: `owner`, `visits`, or any other `Pet` field.

### Ordering

Pets are ordered by an in-code comparator applied after retrieval from the repository. The comparator is:

```
Comparator.comparing(PetResponse::name,
        Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER))
    .thenComparing(PetResponse::id,
        Comparator.nullsLast(Comparator.naturalOrder()))
```

- Names are compared case-insensitively.
- Null names sort after all non-null names.
- When two pets have the same name (any case), they are ordered by `id` ascending.
- Null `id` values sort after all non-null `id` values.

### Success Response

**Status**: `200 OK`

**Body**: JSON array of `PetResponse`, ordered as above. An owner with no pets returns `[]`.

```json
[
  { "id": 3, "name": "Alpha", "birthDate": "2019-03-15", "type": "cat" },
  { "id": 7, "name": "bella", "birthDate": "2021-06-01", "type": "dog" },
  { "id": 1, "name": "Zed",   "birthDate": null,         "type": null  },
  { "id": 9, "name": null,    "birthDate": "2020-01-10", "type": "bird"}
]
```

### Error Responses

| Status | Condition | Body |
|---|---|---|
| `404 Not Found` | No owner exists with the given `id`. | `{"message":"Not found"}` |

### Invariants

- Each item contains exactly `id`, `name`, `birthDate`, and `type`. No other field is present.
- `type` is a plain string (the `PetType` name), not a nested object.
- `birthDate` serialises as JSON `null` when the database value is null; no `500` is thrown.
- `type` serialises as JSON `null` when `Pet.getType()` is null; no `500` is thrown.
- An owner with no pets returns `200` with body `[]`, not `404`.

---

## Constraints That Must Not Break (Existing Behaviour)

The following existing behaviours are unaffected by this feature and must remain unchanged after each story merges.

| Behaviour | Location | Verification |
|---|---|---|
| `GET /owners/{id}` (HTML) returns the owner detail page via Thymeleaf | `OwnerController` | `OwnerControllerTests` |
| `GET /owners?lastName=` (HTML) returns all owners when `lastName` is blank | `OwnerController` | `OwnerControllerTests` |
| Out-of-range page on the HTML owner search redirects | `OwnerController` | `OwnerControllerTests` |
| Unknown owner ID on the HTML screen raises `IllegalArgumentException` | `OwnerController` | `OwnerControllerTests` |
| `OwnerRepository.findByLastNameStartingWith(String, Pageable)` signature and behaviour | `OwnerRepository` | `ClinicServiceTests` |
| All domain entity fields and relationships | `Owner`, `Pet`, `PetType`, `Visit` | `ClinicServiceTests`, `PetClinicConcurrencyTests` |
