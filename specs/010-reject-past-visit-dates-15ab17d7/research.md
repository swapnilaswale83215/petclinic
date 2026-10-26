# Research: Reject Past Visit Dates

**Feature**: `010-reject-past-visit-dates-15ab17d7`
**Date**: 2026-10-26
**Phase**: 0 — Research

---

## R-001: Where to enforce the past-date rule (controller vs. entity vs. validator)

**Decision**: Enforce the rule in `VisitController.processNewVisitForm` using a manual `date.isBefore(LocalDate.now())` comparison followed by `result.rejectValue(...)`. No Jakarta Bean Validation annotation is added to `Visit.java`.

**Rationale**: FR-007 and FR-012 prohibit any change to `Visit.java`. Constitution Principle II mandates Jakarta Bean Validation on domain classes, but the spec's Assumptions section explicitly records this as a deliberate, scoped exception (ADR-APP-1, ADR-APP-2), noting that the constitution is an unratified draft and the approved brief takes precedence. A standalone validator class is also ruled out by Principle II ("No separate standalone validator classes MUST be introduced"). The controller is therefore the only permitted location.

**Alternatives considered**:
- **Jakarta Bean Validation on `Visit.date`** (`@FutureOrPresent`): Preferred by Principle II but blocked by FR-007 (Visit.java must remain byte-identical). Rejected.
- **Separate `VisitValidator` class**: Blocked by Principle II. Rejected.
- **Spring `Validator` interface wired via `@InitBinder`**: Would require a new class or a change to `Visit.java`; both are prohibited. Rejected.
- **Database constraint**: Out of scope per FR-012; would also break existing seed data. Rejected.

---

## R-002: Exact method call for recording the validation error

**Decision**: Call `result.rejectValue("date", "visit.date.pastNotAllowed", "Visit date must be today or in the future.")` inside `processNewVisitForm`, before the `result.hasErrors()` guard that prevents the save.

**Rationale**: FR-003 requires the error code `visit.date.pastNotAllowed` and the exact default message `"Visit date must be today or in the future."` as a compile-time constant with no concatenation of request data. FR-004 prohibits reuse of `typeMismatch.visitDate`. `BindingResult.rejectValue(field, code, defaultMessage)` is the standard Spring MVC mechanism that satisfies all three constraints in a single call.

**Alternatives considered**:
- **`result.rejectValue("date", "visit.date.pastNotAllowed")`** (two-arg form, no default message): Would require a `messages*.properties` entry to display any text, which FR-003 and FR-007 prohibit. Rejected.
- **`result.addError(new FieldError(...))`**: More verbose; no advantage over `rejectValue` for this use case. Rejected.
- **Custom `ConstraintViolation` via programmatic validator**: Unnecessary complexity; same outcome as `rejectValue`. Rejected.

---

## R-003: Placement of the past-date check relative to the existing `result.hasErrors()` guard

**Decision**: Insert the past-date check immediately before the `if (result.hasErrors())` return. The check reads the `date` field from the bound `visit` object; if `date` is non-null and `date.isBefore(LocalDate.now())`, call `rejectValue` and then fall through to the existing `hasErrors()` guard, which will now return true and re-render the form.

**Rationale**: FR-008 requires the check to execute before the `result.hasErrors()` return and to be non-bypassable for a non-null, parseable date. Placing it before the guard ensures it runs on every valid binding. FR-011 requires that a simultaneous past-date and missing-description both produce errors in the same response; because `rejectValue` adds to the existing `BindingResult` rather than short-circuiting, the description error accumulated by Bean Validation is preserved alongside the new date error. User Story 3 and its acceptance scenarios confirm that a null or unparseable date must not reach the new check; a null `date` means binding already failed, so `date` will be null on the bound object and the `isBefore` call must be guarded by a null check.

**Alternatives considered**:
- **Check after `result.hasErrors()`**: Would mean a past date on an otherwise-valid form is silently saved. Rejected.
- **Short-circuit return immediately after `rejectValue`**: Would suppress the description error when both fields are invalid, violating FR-011. Rejected.

---

## R-004: Null-date guard before the `isBefore` comparison

**Decision**: Wrap the `isBefore` comparison in a `visit.getDate() != null` guard. If `date` is null, skip the past-date check entirely and let the existing required-field binding error stand.

**Rationale**: User Story 3 acceptance scenario 1 and the Edge Cases section both state that a null date must produce only the existing required-field error, not the new `visit.date.pastNotAllowed` code. Calling `isBefore` on a null `LocalDate` would throw a `NullPointerException`. The null guard is therefore both a correctness requirement and a safety measure.

**Alternatives considered**:
- **`Optional.ofNullable(visit.getDate()).map(...)`**: Functionally equivalent; more verbose for a single null check. Rejected in favour of a plain `if` for readability.
- **Rely on Bean Validation `@NotNull` to prevent null reaching the method**: `Visit.java` must not be changed, and the existing binding behaviour already handles null; adding an annotation is prohibited. Rejected.

---

## R-005: `minVisitDate` model attribute value

**Decision**: Change the `minVisitDate` model attribute set in `initNewVisitForm` (the GET handler) from `LocalDate.now().plusDays(1)` (tomorrow) to `LocalDate.now()` (today).

**Rationale**: FR-005 requires `minVisitDate` to equal `LocalDate.now()` so the form hint matches the server-side acceptance rule. The spec Assumptions section confirms the template already reads this attribute and will reflect the change without a template edit, satisfying FR-007.

**Alternatives considered**:
- **Leave `minVisitDate` as tomorrow**: Would create a mismatch between the hint (tomorrow) and the server rule (today), confusing users. Rejected.
- **Remove `minVisitDate` entirely**: Would remove the hint; the template would need editing to handle a missing attribute, violating FR-007. Rejected.

---

## R-006: No `messages*.properties` entry for the new error code

**Decision**: Do not add `visit.date.pastNotAllowed` to any `messages*.properties` file. The default message string passed to `rejectValue` is shown directly.

**Rationale**: FR-003 states no `messages*.properties` file must be edited. FR-007 restricts changes to `VisitController.java` and `VisitControllerTests.java` only. The Assumptions section confirms `I18nPropertiesSyncTest` passes because no new key is introduced to any properties file. The accepted deviation (Risks, DEF-5) acknowledges that non-English locales will display the English text; this is recorded as accepted debt for a follow-up.

**Alternatives considered**:
- **Add the key to all language bundles**: Would require editing `messages.properties`, `messages_de.properties`, and any other locale files, violating FR-007. Rejected.
- **Add only to `messages.properties`**: Would cause `I18nPropertiesSyncTest` to fail (missing translations in other locales). Rejected.

---

## R-007: Test structure for `VisitControllerTests`

**Decision**: Replace the existing test `processNewVisitFormHasErrorsWhenVisitDateIsNotInFuture` with a single new test method that (a) posts `LocalDate.now().minusDays(1)` (yesterday), asserts HTTP 200, the form view, a field error on `date` with the exact message `"Visit date must be today or in the future."`, and verifies `OwnerRepository.save` is never called; then (b) posts `LocalDate.now()` (today) with a valid description, asserts a 3xx redirect, and verifies `OwnerRepository.save` is called exactly once. `LocalDate.now()` is computed once at the start of the test method.

**Rationale**: FR-006 requires one test demonstrating both outcomes, using `LocalDate.now()` at runtime with no fixed dates. KPI-1 requires the surefire report to show 5 tests, 0 failures. The existing class has 5 tests; replacing one keeps the count at 5. Computing `LocalDate.now()` once per test run minimises (though does not eliminate) the midnight-boundary flake documented in Risks DEF-8.

**Alternatives considered**:
- **Two separate test methods (one for rejection, one for acceptance)**: Would raise the test count to 6, violating KPI-1. Rejected.
- **Parameterised test**: Adds complexity; the spec calls for a single named test. Rejected.
- **Fixed calendar date (e.g., `LocalDate.of(2020, 1, 1)`)**: Explicitly prohibited by FR-006. Rejected.

---

## R-008: `@WebMvcTest` mock setup for the new test

**Decision**: Reuse the existing `@WebMvcTest(VisitController.class)` setup with `@MockBean OwnerRepository`. The test stubs `ownerRepository.findById(ownerId)` to return a populated `Owner` with a `Pet`. For the rejection scenario, `verify(ownerRepository, never()).save(any())` confirms no save occurs. For the acceptance scenario, `verify(ownerRepository, times(1)).save(any())` confirms the save.

**Rationale**: The existing `VisitControllerTests` already uses this pattern. FR-001 requires `OwnerRepository.save` to not be called on rejection; Mockito `verify` is the standard mechanism in a `@WebMvcTest` context. No new test infrastructure is needed.

**Alternatives considered**:
- **`@SpringBootTest` full-context test**: Heavier; not consistent with the existing test class style. Rejected.
- **Asserting on the database directly**: Not applicable in a `@WebMvcTest` slice with a mocked repository. Rejected.

---

## R-009: Scope of files changed

**Decision**: Modify only `src/main/java/.../owner/VisitController.java` and `src/test/java/.../owner/VisitControllerTests.java`. All other files remain byte-identical.

**Rationale**: FR-007 and SC-002 are explicit. The spec Assumptions section confirms the template, message bundles, schema files, seed files, Kubernetes manifests, and CI configuration are all out of scope. The `git diff` against the base commit on main must list exactly these two files.

**Alternatives considered**:
- **Editing `createOrUpdateVisitForm.html`**: Not required because the template already reads `minVisitDate` dynamically. Editing it would violate FR-007. Rejected.
- **Editing `messages.properties`**: Prohibited by FR-003 and FR-007. Rejected.

---

## R-010: Time-zone handling for `LocalDate.now()`

**Decision**: Use `LocalDate.now()` without an explicit `ZoneId` argument in both `VisitController` and `VisitControllerTests`. Add a code comment in `VisitController` stating that "today" is defined by the JVM's default time zone on the server.

**Rationale**: The spec Assumptions section explicitly states no time-zone override is introduced and that the boundary is the JVM default. FR-008 requires the check to be server-side; using the JVM default is consistent with the rest of the application. The midnight-boundary risk (Risks DEF-8) is accepted.

**Alternatives considered**:
- **`LocalDate.now(ZoneId.of("UTC"))`**: Would diverge from the application's existing convention and could produce different results from other date operations in the codebase. Not justified by the spec. Rejected.
- **Injecting a `Clock` bean for testability**: Would require a new Spring bean and changes beyond the two permitted files. Rejected.

---

## R-011: Constitution Principle II exception (Jakarta Bean Validation on domain class)

**Decision**: Record the deliberate non-compliance with Constitution Principle II as ADR-APP-1 and ADR-APP-2 (already cited in the spec Assumptions). No remediation is required within this story.

**Rationale**: The constitution is an unratified draft (Version 1.0.0, Status: Unratified draft). The approved brief and FR-007 prohibit changes to `Visit.java`. The spec Assumptions section explicitly acknowledges the exception and states the approved brief takes precedence. The story description must state this deviation.

**Alternatives considered**:
- **Ratify the constitution and enforce Principle II**: Out of scope for this story; would require a separate governance action. Rejected for this change.
- **Add a `@FutureOrPresent` annotation to `Visit.date`**: Prohibited by FR-007. Rejected.

---

## R-012: Impact on `ClinicServiceTests.shouldAddNewVisitForPet`

**Decision**: No change. `ClinicServiceTests` calls `OwnerRepository.save` directly with a `new Visit()` whose default date is tomorrow. Because the past-date check lives only in `VisitController.processNewVisitForm` and no entity-level annotation is added, the service test is unaffected.

**Rationale**: The spec Edge Cases section and Assumptions section both confirm this explicitly. SC-001 requires the full suite to pass with no assertion edits to any file other than `VisitControllerTests.java`.

**Alternatives considered**:
- **Change `Visit`'s default constructor date**: Prohibited by FR-007 and the Assumptions section. Rejected.
- **Add a service-layer validation**: Out of scope; would require files beyond the two permitted. Rejected.

---

## R-013: `I18nPropertiesSyncTest` compatibility

**Decision**: No action required. Because no new key is added to any `messages*.properties` file, `I18nPropertiesSyncTest` continues to pass without modification.

**Rationale**: The test enforces that every key present in any properties file is present in all others. Since no key is added, the sync invariant is not disturbed. FR-007 prohibits editing properties files. The accepted deviation (DEF-5) records that non-English locales will show English text for the new error.

**Alternatives considered**:
- **Add `visit.date.pastNotAllowed` to all locale bundles**: Would require editing files outside the two permitted files, violating FR-007. Rejected.

---

## R-014: `@InitBinder` disallowed-field rule

**Decision**: Leave the `@InitBinder` method in `VisitController` exactly as it is on main. No change to `setAllowedFields` or any other binder configuration.

**Rationale**: FR-009 is explicit. The past-date check does not interact with the binder; it operates on the already-bound `visit` object.

**Alternatives considered**:
- **Add `date` to disallowed fields**: Would prevent the date from binding at all, making the feature impossible. Rejected.

---

## R-015: Regression risk from open PRs #1 and #4

**Decision**: Treat PRs #1 and #4 as out of scope. Code against live main. If merge conflicts arise, they are resolved at merge time as a normal Git operation outside this story's boundary.

**Rationale**: The spec Assumptions section and Risks section both state PRs #1 and #4 are out of scope. The story's acceptance criterion is verified against main with `git diff`.

**Alternatives considered**:
- **Rebase onto PR #1 or #4**: Out of scope; would introduce unreviewed changes. Rejected.

---

## Unresolved Items

None. All NEEDS CLARIFICATION items raised by the spec and context have been resolved above. The implementation can proceed to Phase 1.
