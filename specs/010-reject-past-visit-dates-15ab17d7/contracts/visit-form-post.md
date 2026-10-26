# Contract: New Visit Form POST

**Contract ID**: `visit-form-post`
**Feature**: `010-reject-past-visit-dates-15ab17d7`
**Date**: 2026-10-26
**Status**: Active

---

## Overview

This contract describes the HTTP interface for creating a new veterinary visit in the Spring PetClinic application. It covers both the GET (form initialisation) and POST (form submission) interactions on the new-visit route. The POST contract is the primary subject of this feature; the GET contract is included because one model attribute changes.

This document records both **what must not break** (existing behaviour that stays unchanged) and **what changes** (the new past-date rejection rule and the updated `minVisitDate` attribute).

---

## Route

```
GET  /owners/{ownerId}/pets/{petId}/visits/new
POST /owners/{ownerId}/pets/{petId}/visits/new
```

**Path parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `ownerId` | Integer | Primary key of the owner who owns the pet |
| `petId` | Integer | Primary key of the pet for which the visit is being created |

Both parameters are resolved by Spring MVC from the URL path. The controller loads the owner via `OwnerRepository.findById(ownerId)` and the pet from the owner's pet collection. If the owner or pet does not exist, behaviour is unchanged from main (NEEDS CLARIFICATION: exact 404 vs. exception behaviour is not specified by this feature and must not be altered).

---

## GET — Form Initialisation

### Request

```
GET /owners/{ownerId}/pets/{petId}/visits/new
```

No request body. No required query parameters.

### Response

| Field | Before this change | After this change |
|-------|--------------------|-------------------|
| HTTP status | 200 | 200 (unchanged) |
| View | `pets/createOrUpdateVisitForm` | `pets/createOrUpdateVisitForm` (unchanged) |
| Model attribute: `visit` | New `Visit` instance; `date` defaults to `LocalDate.now().plusDays(1)` (tomorrow) | Unchanged — the `Visit` default constructor is not modified |
| Model attribute: `minVisitDate` | `LocalDate.now().plusDays(1)` (tomorrow) | `LocalDate.now()` (today) |
| All other model attributes | Unchanged | Unchanged |

**Change note**: `minVisitDate` moves from tomorrow to today so that the form's minimum-date hint matches the server-side acceptance rule (FR-005). The Thymeleaf template `pets/createOrUpdateVisitForm.html` is not modified; it already reads this attribute by name.

---

## POST — Form Submission

### Request

```
POST /owners/{ownerId}/pets/{petId}/visits/new
Content-Type: application/x-www-form-urlencoded
```

**Form fields**:

| Field | Type after binding | Notes |
|-------|--------------------|-------|
| `date` | `LocalDate` | Parsed by Spring MVC's date binder. Blank or unparseable values produce a binding error before the controller method body is entered. |
| `description` | `String` | Free text. Existing `@NotBlank` constraint on `Visit.description` applies. |

**Disallowed fields** (enforced by `@InitBinder`, unchanged):

```
id
*.id
```

Any attempt to submit `id` or a nested `*.id` field is silently discarded by the binder. This behaviour is identical before and after the change (FR-009).

---

### Response: Success

**Condition**: `date` is non-null, parseable, and `>= LocalDate.now()` (today or any future date); `description` is non-blank; all other existing validations pass.

```
HTTP 302 (or other 3xx redirect)
Location: /owners/{ownerId}
```

**Side effects**:
- `OwnerRepository.save(owner)` is called exactly once.
- The new `Visit` is appended to the pet's visit history.

This behaviour is **unchanged from main** for future dates (FR-002). The only change is that today's date (`LocalDate.now()`) is now also accepted, where previously it was rejected by the old test expectation.

---

### Response: Rejection — Past Date *(new behaviour)*

**Condition**: `date` is non-null, parseable, and `< LocalDate.now()` (strictly before today on the server's JVM default time zone).

```
HTTP 200
View: pets/createOrUpdateVisitForm
```

**`BindingResult` field error on `"date"`**:

| Property | Value |
|----------|-------|
| Field | `date` |
| Error code | `visit.date.pastNotAllowed` |
| Default message | `Visit date must be today or in the future.` |

The default message is a compile-time string constant in `VisitController`. It is not resolved from any `messages*.properties` file. No `messages*.properties` file is modified by this feature (FR-003).

**Side effects**:
- `OwnerRepository.save` is **not** called.
- No visit is persisted.

**"Today" definition**: The server evaluates `LocalDate.now()` using the JVM's default time zone at the moment the request is processed. No explicit `ZoneId` is specified. This is documented in a code comment in `VisitController`. The boundary behaviour at midnight is therefore determined by the server's JVM time zone.

---

### Response: Rejection — Blank or Unparseable Date *(existing behaviour, unchanged)*

**Condition**: The `date` field is blank, absent, or contains a value that cannot be parsed as a `LocalDate` by Spring MVC's date binder.

```
HTTP 200
View: pets/createOrUpdateVisitForm
```

**`BindingResult` error on `"date"`**: Existing binding or type-mismatch error (error code is **not** `visit.date.pastNotAllowed`).

The new past-date check is **not reached** in this path. The binding layer fires before the controller method body is entered; `visit.getDate()` is null (or retains the `Visit` constructor default), and the null guard in the controller prevents the past-date check from executing (FR-004, User Story 3).

**Side effects**:
- `OwnerRepository.save` is **not** called.

---

### Response: Rejection — Blank Description *(existing behaviour, unchanged)*

**Condition**: `date` is valid (today or future); `description` is blank or null.

```
HTTP 200
View: pets/createOrUpdateVisitForm
```

**`BindingResult` field error on `"description"`**: Existing `@NotBlank` constraint error.

**Side effects**:
- `OwnerRepository.save` is **not** called.

---

### Response: Combined Rejection — Past Date AND Blank Description *(clarified behaviour)*

**Condition**: `date` is non-null, parseable, and `< LocalDate.now()`; `description` is also blank or null.

```
HTTP 200
View: pets/createOrUpdateVisitForm
```

**`BindingResult` field errors** (both present in the same response):

| Field | Error code | Default message |
|-------|------------|-----------------|
| `date` | `visit.date.pastNotAllowed` | `Visit date must be today or in the future.` |
| `description` | (existing `@NotBlank` code) | (existing message) |

Neither error suppresses the other (FR-011). The past-date check runs before `result.hasErrors()` so that it adds its error regardless of whether a description error is already present. The `result.hasErrors()` guard then catches both errors together and returns the form view.

**Side effects**:
- `OwnerRepository.save` is **not** called.

---

## Error Code Registry

| Error code | Introduced by | Applies to field | Condition |
|------------|---------------|------------------|-----------|
| `visit.date.pastNotAllowed` | This feature | `date` | `date` is non-null, parseable, and before `LocalDate.now()` |
| `typeMismatch.visitDate` (or equivalent) | Pre-existing | `date` | `date` field value cannot be parsed as `LocalDate` |
| (existing `@NotBlank` code) | Pre-existing | `description` | `description` is blank or null |

The error code `typeMismatch.visitDate` MUST NOT be used for the past-date rejection (FR-004). It remains available exclusively for genuine type-mismatch failures.

---

## Unchanged Behaviours (Must Not Break)

The following behaviours are identical before and after this change. Any implementation that alters them is non-conforming.

| Behaviour | Requirement |
|-----------|-------------|
| Route (`/owners/{ownerId}/pets/{petId}/visits/new`) | FR-010 |
| HTTP methods accepted (GET, POST) | FR-010 |
| Form field names (`date`, `description`) | FR-010 |
| Success redirect target (`redirect:/owners/{ownerId}`) | FR-010, FR-002 |
| Flash message on success (if any; unchanged) | FR-010 |
| HTTP 200 re-render of form view on any validation error | FR-001, FR-010 |
| `@InitBinder` `setDisallowedFields("id", "*.id")` body | FR-009 |
| Acceptance of future dates (any date after today) | FR-002 |
| `Visit.java` entity class (byte-identical) | FR-007 |
| `messages*.properties` files (no new key added) | FR-003, FR-007 |
| `createOrUpdateVisitForm.html` template (not modified) | FR-007 |
| Schema, seed data, and database migration files | FR-012 |
| Past-dated visit rows already stored in the database | FR-012 |
| All other controller methods on `VisitController` | FR-007 |

---

## Out-of-Scope Interfaces

The following interfaces exist in the application but are not affected by this feature and are not governed by this contract:

- `GET /owners/{ownerId}` (owner detail page — success redirect target only)
- `GET /owners/{ownerId}/pets/{petId}` (pet detail)
- All veterinarian, owner search, and pet registration endpoints
- Spring Boot Actuator endpoints (`/actuator/*`)

---

## Implementation Notes

- The past-date check is inserted in `VisitController.processNewVisitForm` **before** the `result.hasErrors()` guard, with an explicit null guard: `if (visit.getDate() != null && visit.getDate().isBefore(LocalDate.now()))`.
- The check is server-side and non-bypassable for a non-null, parseable date (FR-008).
- The `minVisitDate` change is in `initNewVisitForm` (the GET handler's `@ModelAttribute` setup), not in `processNewVisitForm`.
- NEEDS CLARIFICATION (NC-1): The exact current method signatures and structure of `processNewVisitForm` and `initNewVisitForm` in the live `VisitController.java` on main must be confirmed by the implementer before coding. The contract above describes the required post-change behaviour; the insertion point depends on the live source.
- NEEDS CLARIFICATION (NC-4): The implementer must confirm that `I18nPropertiesSyncTest` does not scan Java source for error code strings. If it does, the error code `visit.date.pastNotAllowed` appearing in Java source may need to be handled. The expected outcome is that no action is required, but this must be verified against the live test source.
