# Data Model: Reject Past Visit Dates

**Feature**: `010-reject-past-visit-dates-15ab17d7`
**Date**: 2026-10-26
**Phase**: 1 — Design

---

## Overview

This feature adds a server-side past-date rejection rule to the visit submission flow. It touches no entity class, no schema, and no seed data. The only structural change is a new validation behaviour in `VisitController` that gates whether a bound `Visit` object is persisted. The data model itself is unchanged; this document records the existing model as it applies to the feature and calls out precisely what changes and what does not.

---

## Entities in Scope

### Visit

**Source file**: `src/main/java/org/springframework/samples/petclinic/owner/Visit.java`
**Change status**: READ ONLY — byte-identical before and after this feature (FR-007, FR-012)

| Field | Type | Constraints (existing, on entity) | Notes |
|---|---|---|---|
| `id` | `Integer` | Auto-generated primary key | Disallowed in visit form binder via `@InitBinder` (`id`, `*.id`) |
| `date` | `LocalDate` | No Jakarta Bean Validation annotation on the entity | Default constructor sets this to `LocalDate.now().plusDays(1)` (tomorrow); this default MUST NOT change |
| `description` | `String` | Existing `@NotBlank` or equivalent constraint on entity | Existing validation unchanged |

**No new field, annotation, or relationship is added to `Visit`.**

The past-date rule is enforced exclusively at the controller layer; it is not expressed as a bean-validation annotation on this entity. This is a deliberate, recorded exception to Constitution Principle II (see ADR-APP-1, ADR-APP-2 and the Complexity Tracking table in `plan.md`).

---

### Owner

**Source file**: `src/main/java/org/springframework/samples/petclinic/owner/Owner.java`
**Change status**: READ ONLY — no change

Relevant only as the aggregate root persisted via `OwnerRepository.save`. The feature's rejection rule prevents `OwnerRepository.save` from being called when a submitted visit date is in the past. No field on `Owner` changes.

---

### Pet

**Source file**: `src/main/java/org/springframework/samples/petclinic/owner/Pet.java`
**Change status**: READ ONLY — no change

Relevant only as the association target of a new `Visit`. No field on `Pet` changes.

---

## Validation Rules

### New rule introduced by this feature

| Rule ID | Entity / Layer | Field | Condition | Error code | Default message | Enforcement point |
|---|---|---|---|---|---|---|
| VR-NEW-001 | Controller (`VisitController`) | `date` | `visit.getDate() != null && visit.getDate().isBefore(LocalDate.now())` | `visit.date.pastNotAllowed` | `"Visit date must be today or in the future."` | `processNewVisitForm`, before `result.hasErrors()` guard |

**Null guard**: The `isBefore` comparison is only reached when `visit.getDate()` is non-null. A null `date` is handled by the existing required-field binding error; the new error code is never emitted for a null date (R-004, User Story 3).

**Compile-time constant**: The default message string is a Java string literal passed directly to `result.rejectValue`; it contains no concatenation of request data (FR-003, FR-008).

**No `messages*.properties` entry**: The error code `visit.date.pastNotAllowed` is not added to any locale bundle. The default message is shown directly. Non-English locales display the English text (accepted deviation DEF-5, R-006).

---

### Existing rules preserved unchanged

| Rule ID | Entity / Layer | Field | Condition | Error code / mechanism | Notes |
|---|---|---|---|---|---|
| VR-EX-001 | Entity (`Visit`) | `description` | Blank or null | Existing bean-validation constraint | Unchanged; accumulates alongside VR-NEW-001 when both fields are invalid (FR-011) |
| VR-EX-002 | Binder (`VisitController @InitBinder`) | `id`, `*.id` | Any submission | `setAllowedFields` disallows these fields | Unchanged (FR-009) |
| VR-EX-003 | Spring MVC binding | `date` | Null or unparseable string | `typeMismatch` / required-field binding error | Fires before VR-NEW-001 is reached; `visit.date.pastNotAllowed` is never emitted for these inputs (FR-004, User Story 3) |

---

## Model Attribute Changes

The following model attribute is set in `VisitController.initNewVisitForm` (the GET handler) and consumed by `createOrUpdateVisitForm.html`. It is not a persisted field; it is a view hint only.

| Attribute | Previous value | New value | Reason |
|---|---|---|---|
| `minVisitDate` | `LocalDate.now().plusDays(1)` (tomorrow) | `LocalDate.now()` (today) | FR-005: the form hint must match the server-side acceptance rule (R-005) |

The template `createOrUpdateVisitForm.html` is not edited; it already reads this attribute dynamically (FR-007, spec Assumptions).

---

## State Transitions

The `Visit` entity has no explicit state machine. The relevant transition is whether a submitted visit is persisted or rejected:

```
POST /owners/{ownerId}/pets/{petId}/visits/new
        │
        ▼
  Spring MVC binds form fields to Visit object
        │
        ├─ date is null or unparseable ──► binding error (VR-EX-003)
        │                                  result.hasErrors() == true
        │                                  → re-render form (HTTP 200)
        │                                  OwnerRepository.save NOT called
        │
        ├─ date is non-null AND date.isBefore(LocalDate.now()) ──► rejectValue (VR-NEW-001)
        │                                  result.hasErrors() == true
        │                                  → re-render form (HTTP 200)
        │                                  OwnerRepository.save NOT called
        │
        ├─ date is non-null AND date >= LocalDate.now()
        │  AND other fields invalid ──────► existing bean-validation errors (VR-EX-001)
        │                                  result.hasErrors() == true
        │                                  → re-render form (HTTP 200)
        │                                  OwnerRepository.save NOT called
        │
        └─ date >= LocalDate.now() AND all fields valid
                                           result.hasErrors() == false
                                           → OwnerRepository.save called (once)
                                           → redirect:/owners/{ownerId}
```

**Combined-error path**: When `date` is in the past AND `description` is blank, VR-NEW-001 adds to the `BindingResult` and then falls through to the `hasErrors()` guard. Both errors are present in the same HTTP 200 response (FR-011, User Story 1 scenario 3, R-003).

**Existing past-dated rows at rest**: Because the rule is applied only in `processNewVisitForm` and no entity-level annotation is added, `Visit` rows already stored in the database with past dates load and persist without error (FR-012, spec Edge Cases, R-012).

---

## Relationships (unchanged)

| Relationship | Cardinality | Change |
|---|---|---|
| Owner OWNS Pet | One-to-many | None |
| Pet HAS Visit | One-to-many, append-only | None — new visits are appended; no visit is deleted or overwritten |
| Visit ASSIGNED_TO Veterinarian | Many-to-one | None |

---

## Schema and Persistence (unchanged)

No schema file, seed file, or database migration is introduced (FR-012). The H2, MySQL, and PostgreSQL schemas are byte-identical before and after this change. `ClinicServiceTests.shouldAddNewVisitForPet` saves a `new Visit()` with a default date of tomorrow directly via `OwnerRepository`; because the past-date check lives only in the controller, this test is unaffected (R-012).

---

## What Changes vs. the Current Model

| Dimension | Before | After |
|---|---|---|
| `Visit.java` fields | `id`, `date`, `description` | Identical — no change |
| `Visit.java` annotations | Existing constraints only | Identical — no new annotation |
| `Visit` default constructor date | `LocalDate.now().plusDays(1)` | Identical — no change |
| Past-date validation | Not enforced; past dates accepted | Rejected in `processNewVisitForm` via `result.rejectValue` when `date.isBefore(LocalDate.now())` |
| `minVisitDate` model attribute | `LocalDate.now().plusDays(1)` | `LocalDate.now()` |
| Error code for past date | None | `visit.date.pastNotAllowed` |
| Default error message | None | `"Visit date must be today or in the future."` |
| `messages*.properties` | No entry for past-date rule | No entry added (accepted deviation DEF-5) |
| Database schema | Unchanged | Unchanged |
| Seed data | Unchanged | Unchanged |
