# Data Model: Clinic Read API

**Feature**: 010-clinic-read-api-ba9d61a9
**Date**: 2026-10-27
**Status**: Complete — all items resolved or marked NEEDS CLARIFICATION

---

## 1. Overview

This document describes every entity and record the Clinic Read API feature touches. It covers:

- Existing domain entities that are read (but never written) by the new API
- New Java records introduced as API response types
- The new `PetRepository` interface
- Field-level specifications, validation rules, and serialisation behaviour
- Ordering rules and pagination mechanics
- What changes relative to the current model

No existing entity is modified. All changes are additive.

---

## 2. Existing Entities (Read-Only)

The following entities are defined in the `org.springframework.samples.petclinic.owner` package. The API reads from them but must not modify their declarations, annotations, relationships, or persistence mappings.

### 2.1 Owner

**Package**: `org.springframework.samples.petclinic.owner`
**Status**: Existing — must not be modified

| Field | Java type | Nullable | Read by API | Notes |
|---|---|---|---|---|
| `id` | `Integer` | No | No | Used internally to look up the owner; never exposed in any response |
| `firstName` | `String` | No | Yes — `OwnerResponse` | Mapped directly |
| `lastName` | `String` | No | Yes — `OwnerResponse` | Mapped directly; also used as search prefix |
| `address` | `String` | No | Yes — `OwnerResponse` | Mapped directly |
| `city` | `String` | No | Yes — `OwnerResponse` | Mapped directly |
| `telephone` | `String` | No | Yes — `OwnerResponse` | Mapped directly |
| `pets` | `Collection<Pet>` | No (may be empty) | Yes — `PetResponse` list | Traversed in Story 3; never exposed as a nested object |

**Constraints carried forward**:
- `id` must never appear in any API response (FR-002, Story 1 acceptance scenario 1).
- `firstName`, `lastName`, `address`, `city`, `telephone` are designated sensitive fields (Principle III). They appear in responses only as explicitly accepted in ADR-SEC-1 and the G1 decision record.
- No Owner field may appear in log output or error responses (FR-013).

---

### 2.2 Pet

**Package**: `org.springframework.samples.petclinic.owner`
**Status**: Existing — must not be modified

| Field | Java type | Nullable | Read by API | Notes |
|---|---|---|---|---|
| `id` | `Integer` | No | Yes — sort tiebreak in Story 3; exposed in `PetResponse` | Used as tiebreak comparator key and as a response field |
| `name` | `String` | Yes | Yes — `PetResponse` | May be null; null names sort last (case-insensitive ordering) |
| `birthDate` | `LocalDate` | Yes | Yes — `PetResponse` | Converted to ISO yyyy-MM-dd string via `LocalDate.toString()`; null serialises as JSON `null` |
| `type` | `PetType` | Yes | Yes — `PetResponse` | Only `PetType.getName()` is exposed; null type serialises `type` field as JSON `null` |
| `owner` | `Owner` | No | No | Must not appear in any response (FR-006, Story 3 acceptance scenario 3) |
| `visits` | `Collection<Visit>` | No (may be empty) | Yes — `VisitResponse` list | Traversed in Story 4; never exposed as a nested object |

**Constraints carried forward**:
- `owner` must never appear in `PetResponse` (FR-006).
- `visits` must never appear in `PetResponse` (FR-006, Story 3 acceptance scenario 3).
- Null `birthDate` must serialise as JSON `null`, not cause a 500 (SPEC-DATA-3).
- Null `type` must serialise `type` field as JSON `null`, not cause a 500 (SPEC-DATA-3, DEF-9).

---

### 2.3 PetType

**Package**: `org.springframework.samples.petclinic.owner`
**Status**: Existing — must not be modified

| Field | Java type | Nullable | Read by API | Notes |
|---|---|---|---|---|
| `id` | `Integer` | No | No | Never exposed |
| `name` | `String` | No | Yes — `PetResponse.type` | Exposed as a plain string, not as a nested object |

**Constraints carried forward**:
- `PetType` must never appear as a nested JSON object in any response. Only its `name` string is used (FR-006, Story 3 acceptance scenario 3).

---

### 2.4 Visit

**Package**: `org.springframework.samples.petclinic.owner`
**Status**: Existing — must not be modified

| Field | Java type | Nullable | Read by API | Notes |
|---|---|---|---|---|
| `id` | `Integer` | Yes | Sort tiebreak only — never in response | Used as tiebreak key before mapping to `VisitResponse`; must not appear in the response (Story 4 acceptance scenario 3) |
| `date` | `LocalDate` | Yes | Yes — `VisitResponse` | Converted to ISO yyyy-MM-dd string; null serialises as JSON `null`; null dates sort last |
| `description` | `String` | Yes | Yes — `VisitResponse` | Mapped directly |
| `pet` | `Pet` | No | No | Must not appear in any response (Story 4 acceptance scenario 3) |

**Constraints carried forward**:
- `id` must never appear in `VisitResponse` (FR-007, Story 4 acceptance scenario 3).
- `pet` must never appear in `VisitResponse` (FR-007, Story 4 acceptance scenario 3).
- Null `date` must serialise as JSON `null`, not cause a 500 (SPEC-DATA-3).
- Visit records are append-only; the API never creates, updates, or deletes visits (Principle II).

---

## 3. New Response Records

All new records are placed in `org.springframework.samples.petclinic.owner.api`. They are Java records (Java 17+). Jackson serialises each record component as a JSON field using the component name. No `@JsonIgnore`, `@JsonInclude`, or `@JsonProperty` annotations are required because the record components are exactly the agreed fields and nothing else.

### 3.1 OwnerResponse

**Declaration**: `record OwnerResponse(String firstName, String lastName, String address, String city, String telephone)`
**Used by**: Stories 1 and 2
**Introduced in**: Story 1

| Component | JSON field | Java type | Nullable | Source |
|---|---|---|---|---|
| `firstName` | `"firstName"` | `String` | No | `Owner.firstName` |
| `lastName` | `"lastName"` | `String` | No | `Owner.lastName` |
| `address` | `"address"` | `String` | No | `Owner.address` |
| `city` | `"city"` | `String` | No | `Owner.city` |
| `telephone` | `"telephone"` | `String` | No | `Owner.telephone` |

**Validation rules**:
- Exactly these five fields must appear in the JSON response; no additional field (`id`, `pets`, or any other) may be present (FR-002, Story 1 acceptance scenario 1).
- The record is immutable once constructed; no setter or builder is needed.

**Serialisation example**:
```
{"firstName":"George","lastName":"Franklin","address":"110 W. Liberty St.","city":"Madison","telephone":"6085551023"}
```

**Change from current model**: New record. No existing class is modified.

---

### 3.2 OwnerPage

**Declaration**: `record OwnerPage(List<OwnerResponse> content, int page, int size, long total)`
**Used by**: Story 2
**Introduced in**: Story 2

| Component | JSON field | Java type | Nullable | Source |
|---|---|---|---|---|
| `content` | `"content"` | `List<OwnerResponse>` | No (may be empty list) | Mapped from `Page<Owner>.getContent()` |
| `page` | `"page"` | `int` | No | `safePage` (1-based, clamped to ≥ 1) |
| `size` | `"size"` | `int` | No | Always `5` (fixed; never taken from request) |
| `total` | `"total"` | `long` | No | `Page<Owner>.getTotalElements()` |

**Validation rules**:
- `page` is always the 1-based page number supplied by the caller (after clamping), not the zero-based index passed to `PageRequest` (FR-004).
- `size` is always `5` regardless of any `size` query parameter supplied by the caller (FR-004, SPEC-SEC-3, Story 2 acceptance scenario 8).
- `total` reflects the true total element count from the repository, even when the requested page is beyond the last page (Story 2 acceptance scenario 5).
- `content` is an empty list (not null) when no results are found or the page is beyond the last page.

**Serialisation example**:
```
{"content":[...],"page":1,"size":5,"total":7}
```

**Change from current model**: New record. No existing class is modified.

---

### 3.3 PetResponse

**Declaration**: `record PetResponse(Integer id, String name, String birthDate, String type)`
**Used by**: Story 3
**Introduced in**: Story 3

| Component | JSON field | Java type | Nullable | Source |
|---|---|---|---|---|
| `id` | `"id"` | `Integer` | No (per domain invariant) | `Pet.id` |
| `name` | `"name"` | `String` | Yes | `Pet.name` |
| `birthDate` | `"birthDate"` | `String` | Yes | `Pet.birthDate != null ? Pet.birthDate.toString() : null` |
| `type` | `"type"` | `String` | Yes | `Pet.type != null ? Pet.type.getName() : null` |

**Validation rules**:
- Exactly these four fields must appear in the JSON response; no `owner`, `visits`, or other field may be present (FR-006, Story 3 acceptance scenario 3).
- `birthDate` is an ISO yyyy-MM-dd string when non-null, or JSON `null` when the domain value is null (SPEC-DATA-3).
- `type` is the `PetType.name` string when non-null, or JSON `null` when `Pet.type` is null (SPEC-DATA-3, DEF-9).
- `name` may be null; null names are valid and sort last in the ordering comparator.

**Serialisation example (non-null fields)**:
```
{"id":3,"name":"Rosy","birthDate":"2011-04-17","type":"dog"}
```

**Serialisation example (null fields)**:
```
{"id":7,"name":null,"birthDate":null,"type":null}
```

**Change from current model**: New record. No existing class is modified.

---

### 3.4 VisitResponse

**Declaration**: `record VisitResponse(String date, String description)`
**Used by**: Story 4
**Introduced in**: Story 4

| Component | JSON field | Java type | Nullable | Source |
|---|---|---|---|---|
| `date` | `"date"` | `String` | Yes | `Visit.date != null ? Visit.date.toString() : null` |
| `description` | `"description"` | `String` | Yes | `Visit.description` |

**Validation rules**:
- Exactly these two fields must appear in the JSON response; no `id`, `pet`, or other field may be present (FR-007, Story 4 acceptance scenario 3).
- `date` is an ISO yyyy-MM-dd string when non-null, or JSON `null` when the domain value is null (SPEC-DATA-3).
- `id` is intentionally absent from this record. The visit ID is used only as a sort tiebreak on the `Visit` entity stream before mapping to `VisitResponse` (R-006).

**Serialisation example (non-null fields)**:
```
{"date":"2013-01-04","description":"rabies shot"}
```

**Serialisation example (null date)**:
```
{"date":null,"description":"annual checkup"}
```

**Change from current model**: New record. No existing class is modified.

---

### 3.5 ApiMessage

**Declaration**: `record ApiMessage(String message)`
**Used by**: All stories (error responses)
**Introduced in**: Story 1

| Component | JSON field | Java type | Nullable | Source |
|---|---|---|---|---|
| `message` | `"message"` | `String` | No | Fixed string literal in controller |

**Validation rules**:
- Exactly one field must appear in the JSON error response; no `status`, `timestamp`, `path`, `exception`, or other field may be present (FR-013, SPEC-SEC-4).
- The `message` value is always a fixed string literal, never derived from request input, exception messages, or entity data (FR-013).
- Agreed message values:
  - 404 responses: `"Not found"`
  - 400 responses (missing/blank lastName): `"lastName is required"`

**Serialisation examples**:
```
{"message":"Not found"}
{"message":"lastName is required"}
```

**Change from current model**: New record. No existing class is modified.

---

## 4. New Repository Interface

### 4.1 PetRepository

**Package**: `org.springframework.samples.petclinic.owner.api` (preferred; fallback to `org.springframework.samples.petclinic.owner` if Spring Data scanning does not cover the sub-package — NC-1)
**Status**: New
**Introduced in**: Story 4

**Declaration**:
```
interface PetRepository extends Repository<Pet, Integer> {
    Optional<Pet> findById(Integer id);
}
```

| Aspect | Value |
|---|---|
| Extends | `org.springframework.data.repository.Repository<Pet, Integer>` only |
| Declared methods | `Optional<Pet> findById(Integer id)` — exactly one |
| Inherited methods | None (Repository is a marker interface with no methods) |
| Write methods | None — must not be present |
| Assignable to CrudRepository | No |
| Assignable to JpaRepository | No |

**Validation rules**:
- Must not extend `CrudRepository`, `JpaRepository`, `ListCrudRepository`, or any other Spring Data interface that exposes write methods (FR-008).
- Must declare exactly one method: `Optional<Pet> findById(Integer id)` (FR-008, Story 4 acceptance scenario 6).
- A reflection test must confirm that only `findById(Integer)` is present among declared and inherited methods, and that `PetRepository` is not assignable to `CrudRepository` or `JpaRepository` (Story 4 acceptance scenario 6, SPEC-DATA-2).
- Spring Data will generate a JPA-backed implementation automatically because `Repository<T,ID>` is the root of the Spring Data hierarchy.

**Change from current model**: New interface. If a `PetRepository` already exists in the `owner` package (NC-1 note in project structure), its relationship to this new interface must be clarified before Story 4 begins. NEEDS CLARIFICATION — see NC-1.

---

## 5. Ordering Rules

Ordering is implemented as in-code Java comparators, not as database ORDER BY clauses (ADR-APP-9). This section specifies the comparator chains precisely.

### 5.1 Pet Ordering (Story 3)

Applied to the `List<PetResponse>` after mapping from `Owner.getPets()`.

**Primary key**: `name`, case-insensitive ascending, null names last
**Secondary key**: `id`, natural order ascending, null IDs last

**Comparator chain**:
```
Comparator.comparing(
        PetResponse::name,
        Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER))
    .thenComparing(
        PetResponse::id,
        Comparator.nullsLast(Comparator.naturalOrder()))
```

**Ordering examples**:

| Input names (unsorted) | Sorted output |
|---|---|
| "bella", "Alpha", "Zed", null | Alpha, bella, Zed, null |
| "alpha", "Alpha" (same name, IDs 5 and 2) | Alpha (id=2), alpha (id=5) |
| null (id=3), null (id=1) | null (id=1), null (id=3) |

**Rationale**: `String.CASE_INSENSITIVE_ORDER` provides case-insensitive lexicographic ordering. `Comparator.nullsLast` places null values after all non-null values. The `id` tiebreak is applied on `PetResponse` because `id` is a component of that record (Story 3 acceptance scenario 2).

---

### 5.2 Visit Ordering (Story 4)

Applied to the `Collection<Visit>` from `Pet.getVisits()` **before** mapping to `VisitResponse`, because `VisitResponse` does not carry an `id` field.

**Primary key**: `Visit.date`, natural order ascending (oldest first), null dates last
**Secondary key**: `Visit.id`, natural order ascending, null IDs last

**Comparator chain (on Visit entities)**:
```
Comparator.comparing(
        Visit::getDate,
        Comparator.nullsLast(Comparator.naturalOrder()))
    .thenComparing(
        Visit::getId,
        Comparator.nullsLast(Comparator.naturalOrder()))
```

After sorting, the `Visit` stream is mapped to `VisitResponse(visit.getDate() != null ? visit.getDate().toString() : null, visit.getDescription())`.

**Ordering examples**:

| Input dates (unsorted) | Sorted output |
|---|---|
| 2015-01-04, 2013-01-04, null | 2013-01-04, 2015-01-04, null |
| 2013-01-04 (id=5), 2013-01-04 (id=2) | 2013-01-04 (id=2), 2013-01-04 (id=5) |
| null (id=3), null (id=1) | null (id=1), null (id=3) |

**Rationale**: `VisitResponse` intentionally omits `id` (Story 4 acceptance scenario 3). The tiebreak by `Visit.id` must therefore be applied before the projection step. Sorting on `Visit` entities and then mapping preserves the correct order in the final response (R-006).

---

## 6. Pagination Model

Applies to Story 2 only (`GET /api/owners?lastName=X`).

| Aspect | Rule | Source |
|---|---|---|
| Page numbering | 1-based in request and response | FR-004 |
| Minimum page | 1 (values below 1 clamped to 1) | FR-004, Story 2 acceptance scenario 4 |
| Page size | Fixed at 5; `size` query parameter ignored | FR-004, SPEC-SEC-3 |
| Repository call | `PageRequest.of(safePage - 1, 5, sort)` where `safePage = Math.max(1, page)` | FR-004 |
| Sort order | `Sort.by("lastName").and(Sort.by("firstName")).and(Sort.by("id"))` | FR-004, Story 2 acceptance scenario 3 |
| Response `page` field | `safePage` (1-based) | FR-004 |
| Response `size` field | Always `5` | FR-004 |
| Response `total` field | `Page<Owner>.getTotalElements()` | Spec assumption |
| Beyond-last-page | Returns 200 with empty `content` and real `total` | Story 2 acceptance scenario 5 |
| `lastName` trimming | `lastName.trim()` applied before repository call | FR-003, Story 2 acceptance scenario 2 |
| Blank/missing `lastName` | Returns 400 before any repository call | FR-003, Story 2 acceptance scenarios 6 and 7 |

---

## 7. Mapping Rules

This section specifies how each existing entity field maps to each new response record component.

### 7.1 Owner → OwnerResponse

| Source field | Target component | Transformation |
|---|---|---|
| `Owner.firstName` | `OwnerResponse.firstName` | Direct assignment |
| `Owner.lastName` | `OwnerResponse.lastName` | Direct assignment |
| `Owner.address` | `OwnerResponse.address` | Direct assignment |
| `Owner.city` | `OwnerResponse.city` | Direct assignment |
| `Owner.telephone` | `OwnerResponse.telephone` | Direct assignment |
| `Owner.id` | — | Not mapped; must not appear in response |
| `Owner.pets` | — | Not mapped in this record |

### 7.2 Owner.pets → List\<PetResponse\>

| Source field | Target component | Transformation |
|---|---|---|
| `Pet.id` | `PetResponse.id` | Direct assignment |
| `Pet.name` | `PetResponse.name` | Direct assignment (may be null) |
| `Pet.birthDate` | `PetResponse.birthDate` | `birthDate != null ? birthDate.toString() : null` |
| `Pet.type` | `PetResponse.type` | `type != null ? type.getName() : null` |
| `Pet.owner` | — | Not mapped; must not appear in response |
| `Pet.visits` | — | Not mapped in this record |

### 7.3 Pet.visits → List\<VisitResponse\>

| Source field | Target component | Transformation |
|---|---|---|
| `Visit.date` | `VisitResponse.date` | `date != null ? date.toString() : null` |
| `Visit.description` | `VisitResponse.description` | Direct assignment (may be null) |
| `Visit.id` | — | Used for sort tiebreak on `Visit` entities before mapping; must not appear in response |
| `Visit.pet` | — | Not mapped; must not appear in response |

---

## 8. State Transitions

The API is read-only. No entity undergoes a state transition as a result of any API call. The following invariants hold for all four endpoints:

- No `Owner`, `Pet`, `Visit`, or `PetType` record is created, updated, or deleted.
- No `@Transactional` write operation is initiated.
- Visit records remain append-only (Principle II).
- Pet-to-Owner and Visit-to-Pet associations are not modified.

---

## 9. Changes Against the Current Model

| Change type | Item | Story | Notes |
|---|---|---|---|
| New record | `OwnerResponse` | 1 | Five-field owner projection; no ID |
| New record | `ApiMessage` | 1 | Single-field error envelope |
| New record | `OwnerPage` | 2 | Pagination envelope wrapping `List<OwnerResponse>` |
| New record | `PetResponse` | 3 | Four-field pet projection; type as string |
| New record | `VisitResponse` | 4 | Two-field visit projection; no ID |
| New interface | `PetRepository` | 4 | Read-only; extends `Repository<Pet,Integer>` only |
| No change | `Owner` | — | Read only; fields, annotations, relationships unchanged |
| No change | `Pet` | — | Read only; fields, annotations, relationships unchanged |
| No change | `PetType` | — | Read only; fields, annotations, relationships unchanged |
| No change | `Visit` | — | Read only; fields, annotations, relationships unchanged |
| No change | `OwnerRepository` | — | Existing `findByLastNameStartingWith(String, Pageable)` used as-is |
| No change | Database schema | — | No migration; no new table, column, index, or constraint |
| No change | `application*.properties` | — | No new configuration entries |

---

## 10. NEEDS CLARIFICATION

| ID | Item | Blocking story |
|---|---|---|
| NC-1 | Whether `@EnableJpaRepositories` scanning covers `owner.api`; if not, `PetRepository` moves to `owner` | Story 4 |
| NC-4 | Whether `OwnerResponse` should include an `id` field for search-result chainability (DEF-1); must be decided before Story 1 merges, as adding `id` after Story 1 is merged is prohibited by FR-014 | Story 1 |

All other NEEDS CLARIFICATION items from `research.md` (NC-2, NC-3, NC-5, NC-6, NC-7, NC-8) have no impact on the data model and are not repeated here.
