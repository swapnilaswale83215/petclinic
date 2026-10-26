# Contract: Visit Form POST — New Visit Submission

**Contract type**: HTTP endpoint (Spring MVC controller action)
**Status**: MUST NOT BREAK (existing behaviour) + EXTENDED (new past-date rejection)
**Feature**: `010-reject-past-visit-dates-15ab17d7`
**Date**: 2026-10-26

---

## Overview

This contract describes the HTTP POST endpoint that creates a new visit for a pet. The route, method, field names, success redirect, and error re-render behaviour are all pre-existing. This change extends the contract by adding one new rejection condition (past date) while leaving every other observable behaviour identical to main.

---

## Endpoint

| Property | Value |
|---|---|
| Method | `POST` |
| Path | `/owners/{ownerId}/pets/{petId}/visits/new` |
| Path variables | `ownerId` — integer owner identifier; `petId` — integer pet identifier |
| Controller | `org.springframework.samples.petclinic.owner.VisitController#processNewVisitForm` |

---

## Request

### Path Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `ownerId` | integer | yes | Identifies the owner aggregate to which the visit is appended |
| `petId` | integer | yes | Identifies the pet within the owner aggregate |

### Form Fields

| Field | Type | Required | Constraints |
|---|---|---|---|
| `date` | `LocalDate` (ISO-8601 string `yyyy-MM-dd` in the form body) | yes (existing binding) | Must be today (`LocalDate.now()` on the server) or any future date. A past date is now rejected. A blank or non-parseable value triggers the existing binding error before this rule is reached. |
| `description` | string | yes (existing `@NotBlank`) | Free text; existing validation unchanged |

No other fields are accepted. The `id` and `*.id` fields remain disallowed by the existing `@InitBinder` rule and MUST NOT be submitted.

---

## Responses

### Success — Visit Accepted

**Condition**: `date` is today or in the future, `description` is non-blank, owner and pet exist.

| Property | Value |
|---|---|
| HTTP status | 3xx (redirect) |
| `Location` header | `redirect:/owners/{ownerId}` |
| Side effect | `OwnerRepository.save(owner)` called exactly once |

This behaviour is unchanged from main.

### Rejection — Past Date (NEW)

**Condition**: `date` is non-null, parses successfully as a `LocalDate`, and is strictly before `LocalDate.now()` on the server at the moment of the request.

| Property | Value |
|---|---|
| HTTP status | 200 OK |
| View | `pets/createOrUpdateVisitForm` |
| Field error field | `date` |
| Error code | `visit.date.pastNotAllowed` |
| Default message | `Visit date must be today or in the future.` (exact string; compile-time constant; no request data concatenated) |
| Side effect | `OwnerRepository.save` is NOT called |

The error message is supplied as the `defaultMessage` argument to `result.rejectValue` and is not resolved from any `messages*.properties` file. Non-English locales display this English text (accepted deviation DEF-5; follow-up story required).

### Rejection — Validation Errors (UNCHANGED)

**Condition**: Any combination of field errors other than, or in addition to, a past date (e.g., blank `description`, type-mismatch on `date`).

| Property | Value |
|---|---|
| HTTP status | 200 OK |
| View | `pets/createOrUpdateVisitForm` |
| Field errors | All accumulated errors returned together in the same response |
| Side effect | `OwnerRepository.save` is NOT called |

When both `date` is past and `description` is blank, both field errors are present in the same 200 response. Neither suppresses the other.

### Rejection — Null or Unparseable Date (UNCHANGED)

**Condition**: `date` field is blank or contains a value that cannot be parsed as a `LocalDate`.

| Property | Value |
|---|---|
| HTTP status | 200 OK |
| View | `pets/createOrUpdateVisitForm` |
| Field error | Existing required-field or `typeMismatch` binding error on `date` |
| Error code present | `visit.date.pastNotAllowed` is NOT present |
| Side effect | `OwnerRepository.save` is NOT called |

The past-date check is guarded by a `visit.getDate() != null` condition and is not reached when binding fails.

### Rejection — Owner or Pet Not Found (UNCHANGED)

Behaviour when `ownerId` or `petId` does not resolve to a known entity is unchanged from main.

NEEDS CLARIFICATION: The exact HTTP status and view returned when `ownerId` or `petId` is not found is not specified in the feature spec. This contract does not alter that behaviour; it is documented here as unchanged.

---

## Error Code Registry

| Code | Field | Introduced by | Default message |
|---|---|---|---|
| `visit.date.pastNotAllowed` | `date` | This feature | `Visit date must be today or in the future.` |
| `typeMismatch.visitDate` | `date` | Pre-existing | (unchanged; not used for past-date rejection) |

---

## Model Attributes (GET — UNCHANGED except `minVisitDate`)

The GET handler for the same path populates the model before the form is rendered. This contract records the one attribute that changes value.

| Attribute | Previous value | New value | Template usage |
|---|---|---|---|
| `minVisitDate` | `LocalDate.now().plusDays(1)` (tomorrow) | `LocalDate.now()` (today) | Read by `createOrUpdateVisitForm.html` to set the `min` attribute on the date input; template file is not changed |

All other model attributes are unchanged.

---

## Invariants That Must Not Break

The following behaviours are present on main and MUST remain identical after this change.

1. The route `/owners/{ownerId}/pets/{petId}/visits/new` and the HTTP method `POST` are unchanged.
2. The form field names `date` and `description` are unchanged.
3. The success redirect target `redirect:/owners/{ownerId}` is unchanged.
4. The error view `pets/createOrUpdateVisitForm` is unchanged.
5. The `@InitBinder` disallowed-field rule for `id` and `*.id` on the visit form binder is unchanged; `setAllowedFields` is not modified.
6. A future date (any date after today) is accepted and saved; this existing behaviour is preserved.
7. A null or unparseable `date` produces only the existing binding error; `visit.date.pastNotAllowed` is not emitted.
8. `OwnerRepository.save` is never called when any field error is present.
9. No `messages*.properties` file is modified; no new i18n key is introduced.
10. `Visit.java` is byte-identical before and after the change; no entity-level annotation is added.
11. Past-dated visit rows already stored in the database are not affected; the validation applies only to new-visit POST submissions.

---

## Time-Zone Note

`LocalDate.now()` is evaluated without an explicit `ZoneId`. "Today" is therefore the date in the JVM's default time zone on the server at the moment of the request. This is documented in a code comment in `VisitController`. No special handling is applied at the midnight boundary; this is an accepted risk (DEF-8).
