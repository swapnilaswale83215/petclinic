# data-model.md

**Feature**: Owner Search Trims Spaces
**Branch**: `009-owner-search-trims-spaces-petc-9985d018`
**Date**: 2026-10-18
**Phase**: 1 — Design & Contracts

---

## Overview

This feature introduces no new entity, no new field, no new relationship, and no schema change. The data model is unchanged. This document records the entities the feature touches, their relevant fields, the validation rules that govern the search path, and the precise boundary between what is in scope and what is not — so that the pull request reviewer and the G1 approver have a single reference for data-model compliance.

---

## Entities in Scope

### Owner

**Package**: `org.springframework.samples.petclinic.owner`
**Persistence**: Spring Data JPA, mapped to the `owners` table (H2 / MySQL / PostgreSQL, profile-activated)
**Status**: **Existing entity — no change**

| Field | Type | Constraints | Sensitive? | Role in this feature |
|---|---|---|---|---|
| `id` | `Integer` | Auto-generated PK; not null | No | Used to identify search results and construct the single-match redirect URL (`/owners/{id}`). Read-only in this feature. |
| `lastName` | `String` | `@NotBlank` (Jakarta Bean Validation); max length governed by the existing schema column definition (NEEDS CLARIFICATION: exact column length not stated in the spec; assumed to match the existing DDL) | Yes — name field is a designated sensitive zone (Constitution Principle III) | The raw value received by `processFindForm` from Spring MVC model binding. The controller strips leading and trailing Unicode whitespace from this value before any downstream use. The stripped value is passed to `OwnerRepository.findByLastNameStartingWith` and used in redirect URL construction. The raw (pre-strip) value must never reach the repository, appear in a log, or be placed in a model attribute or redirect parameter. |
| `firstName` | `String` | `@NotBlank` | Yes | Not read or written by this feature. Present in search results rendered by `ownersList.html` but not touched by the controller change. |
| `address` | `String` | `@NotBlank` | Yes | Not read or written by this feature. |
| `city` | `String` | `@NotBlank` | No | Not read or written by this feature. |
| `telephone` | `String` | `@NotBlank`; digits only (existing validation) | Yes | Not read or written by this feature. |
| `pets` | `List<Pet>` | One-to-many; cascade managed by existing mapping | No | Not read or written by this feature. |

**Sensitive-zone note**: `firstName`, `lastName`, `address`, and `telephone` are designated sensitive fields under Constitution Principle III. FR-008 and SPEC-SEC-1 prohibit any new log statement, model attribute, redirect parameter, or error message that carries any of these fields. The reviewer must confirm at pull request time that the diff contains no reference to the raw padded `lastName` value in any output path.

---

## Entities Explicitly Out of Scope

The following entities exist in the domain model and are not touched by this feature. They are listed here to make the boundary unambiguous.

| Entity | Reason out of scope |
|---|---|
| `Pet` | Not involved in owner search. FR-007 and FR-009 prohibit any change outside the owner search path. |
| `Visit` | Not involved in owner search. |
| `Veterinarian` / `Vet` | Not involved in owner search. Caching contract (Constitution Principle V) is unaffected. |
| `PetType` | Not involved in owner search. |
| `Specialty` | Not involved in owner search. |
| `Person` (superclass of `Owner`, if present) | Not modified. No field added or removed. |

---

## Relationships

No relationship is added, removed, or modified. The existing `Owner OWNS Pet` (one-to-many) relationship is unaffected. The search path reads `Owner` records only; it does not traverse to `Pet` or any other associated entity.

---

## Validation Rules

### Existing rules (unchanged)

| Rule | Location | Behaviour |
|---|---|---|
| `lastName` must not be blank | `@NotBlank` on `Owner.lastName` (Jakarta Bean Validation) | Enforced at registration and edit. Not directly involved in the search path; the search accepts a blank `lastName` and returns all owners. |
| Blank `lastName` search returns all owners | `processFindForm` branch logic | When `lastName` is blank (or becomes blank after trimming), the controller passes the empty string to `findByLastNameStartingWith`, which returns all owners. Paginated at 5 per page. This behaviour is unchanged. |
| Single-match redirect | `processFindForm` branch logic | When the result set contains exactly one owner, the controller redirects to `/owners/{id}`. Unchanged. |
| Out-of-range page redirect | `processFindForm` branch logic | When the requested page number exceeds the available pages, the controller redirects to `/owners?page=1&lastName={trimmedLastName}`. The redirect must use the trimmed value (FR-003). |
| No-match field error | `processFindForm` branch logic | When the result set is empty, the controller adds a `notFound` field error on `lastName` and re-renders `owners/findOwners`. Unchanged. |

### New rule introduced by this feature

| Rule | Location | Behaviour |
|---|---|---|
| `lastName` search term must be stripped of leading and trailing Unicode whitespace before use | `OwnerController.processFindForm` — applied exactly once, at the top of the method, before any branch | `String.strip()` is applied to the value of `owner.getLastName()` (or the equivalent raw parameter). The stripped value replaces the raw value for all downstream uses: repository lookup, redirect URL construction, and error path. The raw padded value must not reach any downstream component. Applies to all Unicode whitespace including U+00A0 (non-breaking space). Inner whitespace (e.g., spaces within "De La Cruz") is preserved. |

**Null-safety note**: NEEDS CLARIFICATION — whether `owner.getLastName()` can be `null` at the point `processFindForm` is entered. The existing code handles the blank case (evidenced by `processFindFormWithWhitespaceOnlyLastNameReturnsAllOwners`), which implies a null-or-empty guard is already present. If `getLastName()` can return `null`, the strip call must be null-safe (e.g., `lastName == null ? "" : lastName.strip()`). This is a minor implementation detail; the design decision (strip before any branch) is not affected.

---

## State Transitions

The `Owner` entity has no lifecycle state machine relevant to this feature. The search path is read-only: it queries `Owner` records but does not create, update, or delete them. No state transition is added or modified.

The controller's internal decision tree (list view → single-match redirect → out-of-range redirect → no-match error) is not a state transition on the entity; it is a routing decision within a single HTTP request. It is documented here for completeness because FR-001 and FR-003 require the strip to occur before all branches.

```
processFindForm entry
        │
        ▼
  strip(lastName)          ← NEW: applied exactly once here, before any branch
        │
        ├─ blank ──────────────────────────────────► findAll (paginated) → ownersList view
        │
        ├─ non-blank, result count = 0 ────────────► notFound field error → findOwners view
        │
        ├─ non-blank, result count = 1 ────────────► redirect /owners/{id}
        │
        ├─ non-blank, result count > 1, page in range ► ownersList view
        │
        └─ non-blank, result count > 1, page out of range ► redirect /owners?page=1&lastName={stripped}
```

All branches receive the stripped value. No branch sees the raw padded input.

---

## Repository Interface

### OwnerRepository.findByLastNameStartingWith

**Status**: **Unchanged — explicitly out of scope (FR-007)**

| Aspect | Detail |
|---|---|
| Signature | `Page<Owner> findByLastNameStartingWith(String lastName, Pageable pageable)` (Spring Data JPA derived query) |
| Semantics | Prefix match on `Owner.lastName`. Case sensitivity is database-collation-dependent (existing behaviour, not modified). |
| Callers | `OwnerController.processFindForm` (passes the already-stripped term); `ClinicServiceTests`; `PetClinicConcurrencyTests` |
| Change | None. The repository receives a pre-stripped value from the controller. The repository's own logic, signature, and `@Query` annotation (if any) are not modified. |

The controller is the sole normalisation point. The repository is a passive recipient of an already-clean value.

---

## Seed Data (H2 — dev/test profile)

No seed data change. The feature relies on the existing H2 seed for manual and smoke-check validation.

| Owner id | Last name | First name | Relevance |
|---|---|---|---|
| 2 | Davis | Betty | Expected in results for `lastName=Davis`, `lastName=Davis%20`, `lastName=%20Davis`, `lastName=%20Davis%20` |
| 4 | Davis | Harold | Expected in results for the same variants |

**Sensitive-data note**: The names above are synthetic seed values already present in the public PetClinic repository. They are recorded here as ids and last names only, consistent with FR-008 and SPEC-SEC-1. Address and telephone fields are not recorded in this document.

The new test method uses a mocked `OwnerRepository` and does not depend on the H2 seed at runtime. The seed-backed equality check (SPEC-DATA-3, E2-S2) is a separate manual verification step.

---

## Schema

No schema change. No migration script. No DDL modification. The `owners` table definition (H2 / MySQL / PostgreSQL) is identical before and after the pull request.

---

## Changes Against the Current Model

| Dimension | Before | After | Delta |
|---|---|---|---|
| Entities | Owner, Pet, Visit, Veterinarian, PetType, Specialty | Same | None |
| Fields | As defined in existing `Owner` class | Same | None |
| Relationships | As defined in existing mappings | Same | None |
| Schema (DDL) | Existing `owners` table | Same | None |
| Seed data | Existing `data.sql` | Same | None |
| Repository interface | `findByLastNameStartingWith(String, Pageable)` | Same | None |
| Validation rules (entity) | `@NotBlank` on `Owner.lastName` | Same | None |
| Validation rules (controller) | Raw `lastName` passed to repository without normalisation | Stripped `lastName` passed to repository and used in redirects | **One new rule: strip leading/trailing Unicode whitespace at controller entry, before all branches** |
| Sensitive data exposure | Raw padded term could theoretically appear in redirect URL (FR-003 violation) | Trimmed term used in all output paths | **Exposure eliminated by the strip placement** |

The only change to the data model — broadly construed to include the controller's handling of the `Owner.lastName` field — is the addition of the strip rule in `processFindForm`. Everything else is unchanged.

---

## Open NEEDS CLARIFICATION Items

| ID | Question | Impact on data model |
|---|---|---|
| R-001 | Is Case A confirmed? Does current main already call `strip()`? | If Case B: `OwnerController.java` enters the diff. The data-model change (strip rule) is the same; only the file count changes. If Case C: the root cause is unknown and this document may need revision. |
| Null-safety | Can `owner.getLastName()` return `null` at `processFindForm` entry? | Minor implementation detail. Does not change the entity model or the strip rule. Requires a null guard in the implementation if null is possible. |
| Column length | What is the exact `lastName` column length in the DDL? | Informational only. No change to the column. Relevant only if a future length-limit requirement (THR-7) is addressed. |
