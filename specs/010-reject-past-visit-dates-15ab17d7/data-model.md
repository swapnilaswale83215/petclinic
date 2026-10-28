# Data Model: Reject Past Visit Dates

**Feature**: `010-reject-past-visit-dates-15ab17d7`
**Phase**: 1 — Design
**Date**: 2026-10-26

---

## Scope

This document describes every entity the feature touches, the fields and constraints relevant to the change, the relationships that remain in force, the state transitions introduced by the new validation rule, and a precise diff of what changes against the current model.

The feature modifies no entity class, no schema, and no seed data. All changes are confined to the controller layer (`VisitController.java`) and the test layer (`VisitControllerTests.java`).

---

## Entities in Scope

### Visit

**Package**: `org.springframework.samples.petclinic.owner`
**File**: `src/main/java/org/springframework/samples/petclinic/owner/Visit.java`
**Change to file**: None. `Visit.java` is read-only for this feature and must be byte-identical before and after the change (FR-007).

#### Fields

| Field | Java Type | Column / Persistence | Current Constraint | Change Introduced |
|---|---|---|---|---|
| `id` | `Integer` | Auto-generated primary key (inherited from base entity) | None beyond PK generation | None |
| `date` | `LocalDate` | Mapped column; no `@Column` constraint beyond nullability | No Jakarta Bean Validation annotation on the field. Default value set in constructor: `LocalDate.now().plusDays(1)` (tomorrow). | **Controller-layer check added** (see §Validation Rules). Entity field itself is unchanged. No annotation added. |
| `description` | `String` | Mapped column | `@NotBlank` (existing Jakarta Bean Validation annotation on the entity field) | None |

#### Constructor Behaviour

The `Visit` default (no-arg) constructor sets `date` to `LocalDate.now().plusDays(1)` (tomorrow). This default is not changed. `ClinicServiceTests.shouldAddNewVisitForPet` relies on this default remaining a future date; the new controller check does not apply to that code path.

#### Relationships

| Relationship | Cardinality | Rule |
|---|---|---|
| Visit → Pet | Many-to-one | A Visit MUST be associated with exactly one Pet (constitution Principle II; unchanged) |
| Visit → Veterinarian | Many-to-one | Optional assignment; unchanged by this feature |

Visit records are append-only. No deletion path exists and none is introduced (constitution Principle II).

---

### VisitController (controller entity — not a JPA entity)

**Package**: `org.springframework.samples.petclinic.owner`
**File**: `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java`
**Change to file**: Yes — two targeted edits (see §What Changes Against the Current Model).

This is not a domain entity in the JPA sense, but it is the primary locus of the new validation rule and its model-attribute behaviour is part of the observable contract.

#### Model Attributes

| Attribute Name | Exposed On | Java Type | Current Value | New Value |
|---|---|---|---|---|
| `minVisitDate` | GET `/owners/{ownerId}/pets/{petId}/visits/new` | `LocalDate` | `LocalDate.now().plusDays(1)` (tomorrow) | `LocalDate.now()` (today) |
| `visit` | GET and POST | `Visit` | Bound from form or new instance | Unchanged |
| `owner` | GET and POST | `Owner` | Loaded via `OwnerRepository.findById` | Unchanged |

The `minVisitDate` change is the only model-attribute change. The template `pets/createOrUpdateVisitForm.html` already reads this attribute and will reflect the updated value without a template edit (spec assumptions; FR-007).

---

### Owner

**Package**: `org.springframework.samples.petclinic.owner`
**Change to file**: None.

Owner is the aggregate root persisted by `OwnerRepository.save`. Its fields and relationships are unchanged. The only relevance to this feature is the save-suppression rule: `OwnerRepository.save` MUST NOT be called when a visit submission is rejected (FR-001).

---

### Pet

**Package**: `org.springframework.samples.petclinic.owner`
**Change to file**: None.

Pet is the parent of the Visit being created. Its fields, relationships, and validation rules are unchanged.

---

### OwnerRepository (repository — not a JPA entity)

**Package**: `org.springframework.samples.petclinic.owner`
**Change to file**: None.

Relevant constraint introduced by this feature: `OwnerRepository.save` MUST NOT be called for any POST submission that fails the past-date check or any other validation (FR-001). This is enforced by the controller's existing `result.hasErrors()` guard, which the new check feeds into.

---

## Validation Rules

### New Rule: Past-Date Rejection (FR-001, FR-003, FR-008)

| Property | Value |
|---|---|
| Applies to | `Visit.date` field on POST to `/owners/{ownerId}/pets/{petId}/visits/new` |
| Enforcement layer | Controller (`VisitController.processNewVisitForm`) — not entity, not persistence |
| Trigger condition | `visit.getDate() != null && visit.getDate().isBefore(LocalDate.now())` |
| Action | `result.rejectValue("date", "visit.date.pastNotAllowed", "Visit date must be today or in the future.")` |
| Error code | `visit.date.pastNotAllowed` |
| Default message | `"Visit date must be today or in the future."` (compile-time string constant; no request-data concatenation) |
| Message source | Java default message argument to `rejectValue`; no `messages*.properties` entry added |
| Position in method | Before the `result.hasErrors()` guard |
| Null behaviour | If `visit.getDate()` is null, the null guard short-circuits; the new error code is not emitted. The existing binding-layer required-field error fires instead (User Story 3; FR-004). |
| Time-zone basis | `LocalDate.now()` using the JVM default time zone. No explicit `ZoneId` is passed. This is documented in a code comment in `VisitController`. |

### Existing Rule: Description Required (unchanged)

| Property | Value |
|---|---|
| Applies to | `Visit.description` |
| Enforcement layer | Jakarta Bean Validation annotation `@NotBlank` on `Visit.description` (entity level) |
| Change | None |

### Existing Rule: Blank or Unparseable Date (unchanged)

| Property | Value |
|---|---|
| Applies to | `Visit.date` binding |
| Enforcement layer | Spring MVC data binding layer (fires before controller method body) |
| Change | None. The new past-date check is unreachable when the date field is blank or unparseable, because binding errors are registered before `processNewVisitForm` is entered. |

### Combined Validation (FR-011)

When both `date` is a past date and `description` is blank, both field errors are returned together in the same HTTP 200 response. The past-date check runs before `result.hasErrors()`, so it adds its error to the `BindingResult` regardless of whether a description error is already present. The `result.hasErrors()` guard then catches both errors and returns the form view.

---

## State Transitions

The following diagram describes the full decision path for a POST to the new-visit form after this change. Paths that are unchanged from main are marked `[existing]`.

```
POST /owners/{ownerId}/pets/{petId}/visits/new
  │
  ├─ [existing] Spring MVC binding layer
  │     │
  │     ├─ date field blank or unparseable
  │     │     → BindingResult binding/type-mismatch error on "date" registered
  │     │     → visit.getDate() is null (or retains constructor default)
  │     │     → processNewVisitForm body entered with pre-existing binding error
  │     │
  │     └─ date field parsed successfully as LocalDate
  │           → visit.getDate() is non-null
  │           → processNewVisitForm body entered
  │
  └─ processNewVisitForm body
        │
        ├─ [NEW] Null guard + past-date check
        │     │
        │     ├─ visit.getDate() == null
        │     │     → check skipped (null guard); fall through
        │     │
        │     ├─ visit.getDate().isBefore(LocalDate.now()) == true
        │     │     → result.rejectValue("date",
        │     │                          "visit.date.pastNotAllowed",
        │     │                          "Visit date must be today or in the future.")
        │     │     → fall through to hasErrors check
        │     │
        │     └─ visit.getDate() >= LocalDate.now()
        │           → check passes silently; fall through
        │
        └─ [existing] result.hasErrors() ?
              │
              ├─ YES (any combination of errors: past date, blank description,
              │        binding error, or any combination thereof)
              │     → return "pets/createOrUpdateVisitForm"   [HTTP 200]
              │     → OwnerRepository.save NOT called
              │
              └─ NO (date >= today, description non-blank, no binding errors)
                    → OwnerRepository.save(owner) called exactly once
                    → return "redirect:/owners/{ownerId}"     [HTTP 3xx]
```

---

## What Changes Against the Current Model

### Summary Table

| Location | Element | Before | After |
|---|---|---|---|
| `VisitController.processNewVisitForm` | Past-date check | Absent | Added: null-guarded `isBefore(LocalDate.now())` check calling `result.rejectValue(...)` before `result.hasErrors()` |
| `VisitController.initNewVisitForm` | `minVisitDate` model attribute value | `LocalDate.now().plusDays(1)` | `LocalDate.now()` |
| `VisitControllerTests` | Test `processNewVisitFormHasErrorsWhenVisitDateIsNotInFuture` | Asserts today is rejected | Replaced by one time-relative test asserting yesterday is rejected (exact message, no save) and today is accepted (3xx redirect, save called once) |
| `Visit.java` | Any field, annotation, or constructor | Unchanged | Unchanged (byte-identical) |
| `messages*.properties` | Any key | Unchanged | Unchanged (no new key added) |
| `createOrUpdateVisitForm.html` | Template | Unchanged | Unchanged (reads `minVisitDate` attribute already) |
| Schema / seed / migration files | Any | Unchanged | Unchanged |

### No New Entity Fields

No field is added to or removed from any entity class.

### No New Relationships

No relationship is added to or removed from the domain model.

### No Schema Change

No DDL, migration script, or seed file is introduced or modified. Past-dated visit rows already present in H2, MySQL, and PostgreSQL databases remain readable and writable. The new validation applies only to new-visit POST submissions at the controller layer (FR-012).

### No New Bean Validation Annotations

No Jakarta Bean Validation annotation is added to any entity class. The past-date rule is enforced exclusively at the controller layer. This is a deliberate, scoped exception to constitution Principle II, justified by FR-007 (Visit.java must not be modified), FR-012 (existing past-dated rows must not be affected), and the unratified status of the constitution. The exception is recorded as ADR-APP-1 and ADR-APP-2 in the spec assumptions.

---

## Entities Not in Scope

The following entities exist in the domain model and are not touched by this feature.

| Entity | Reason Not in Scope |
|---|---|
| Veterinarian / Vet | No visit-scheduling or date-validation logic in the vet package |
| PetType | Classification entity; no interaction with visit date validation |
| Specialty | Vet sub-entity; no interaction with this feature |

---

## NEEDS CLARIFICATION

**NC-1 — Exact current source of `VisitController.java`**
The current `minVisitDate` expression is assumed to be `LocalDate.now().plusDays(1)` based on standard Spring PetClinic main-branch lineage. If the live file on main uses a different expression (e.g., a constant, a different date arithmetic), the "Before" value in the summary table above must be updated accordingly. The implementer must read the live file to confirm before coding.

**NC-2 — Exact current source of the replaced test**
The test method name `processNewVisitFormHasErrorsWhenVisitDateIsNotInFuture` and its assertion that today is rejected are stated in the spec. The implementer must read the live `VisitControllerTests.java` to confirm the method name, the mock setup (e.g., `given(owners.findById(...)).willReturn(...)`), and the surrounding test configuration, so that the replacement test preserves the mock wiring needed by the other four tests in the class.
