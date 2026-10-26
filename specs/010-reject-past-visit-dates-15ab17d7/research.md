# Research: Reject Past Visit Dates

**Feature**: `010-reject-past-visit-dates-15ab17d7`
**Phase**: 0 — Research
**Date**: 2026-10-26

---

## 1. Where to place the past-date validation check

**Decision**: In `VisitController.processNewVisitForm`, as an explicit imperative check using `result.rejectValue(...)`, executed before the `result.hasErrors()` guard that short-circuits the save.

**Rationale**: FR-007 and FR-008 together prohibit any change to `Visit.java` and require the check to live in the controller. The constitution's Principle II preference for Jakarta Bean Validation annotations on domain classes is explicitly overridden by ADR-APP-1 and ADR-APP-2, which the spec records as a deliberate, scoped exception. An entity-level annotation (e.g., `@FutureOrPresent`) would also break `ClinicServiceTests.shouldAddNewVisitForPet`, which saves a `new Visit()` whose default date is tomorrow — a future date that passes the rule — but more importantly it would reject any historically stored past-dated row on re-save, violating FR-012. A `Validator` implementation separate from the controller would be a new standalone validator class, which the constitution's Principle II also prohibits. The controller imperative check is therefore the only compliant location.

**Alternatives considered**:
- **Jakarta Bean Validation on `Visit.date`** (`@FutureOrPresent`): Rejected. Requires modifying `Visit.java` (prohibited by FR-007). Would also fire on persistence of existing past-dated rows (violates FR-012) and on `ClinicServiceTests` saves.
- **Separate `VisitValidator` class**: Rejected. Constitution Principle II prohibits standalone validator classes that duplicate or contradict domain-embedded constraints. Also requires a file outside the two permitted files.
- **Spring `@Validated` + method-level constraint on the controller**: Rejected. Requires adding an annotation to `Visit.java` or a wrapper DTO, both outside the permitted change set.

---

## 2. Exact API for registering the field error

**Decision**: `result.rejectValue("date", "visit.date.pastNotAllowed", "Visit date must be today or in the future.");`

**Rationale**: FR-003 mandates the error code `visit.date.pastNotAllowed` and the exact default message `"Visit date must be today or in the future."` as a compile-time string constant with no concatenation of request data. FR-004 prohibits reuse of `typeMismatch.visitDate`. The three-argument `BindingResult.rejectValue(field, code, defaultMessage)` overload satisfies all three constraints in a single call. No `MessageSource` lookup is needed; the default message is used directly, which also satisfies the requirement that no `messages*.properties` file be edited (FR-003) and that `I18nPropertiesSyncTest` continues to pass (the test checks for keys present in properties files against keys referenced in templates; a Java-only default message introduces no new template key).

**Alternatives considered**:
- **`result.rejectValue("date", "visit.date.pastNotAllowed")`** (two-argument form, message resolved from bundle): Rejected. Would require adding a key to every `messages*.properties` file, violating FR-003 and risking `I18nPropertiesSyncTest` failure if any bundle is missed.
- **`result.addError(new FieldError(...))`**: Rejected. More verbose with no benefit; `rejectValue` is the idiomatic Spring MVC form.
- **Throwing a custom exception and mapping it to a model error**: Rejected. Incompatible with the requirement to return HTTP 200 with the form view and a `BindingResult` field error.

---

## 3. Position of the check relative to the existing `result.hasErrors()` guard

**Decision**: The past-date check is inserted **before** the `result.hasErrors()` return, so that it runs on every non-null, parseable date submission. The null/type-mismatch path is handled by Spring's binding layer before `processNewVisitForm` is entered, so the check never sees a null `visit.getDate()`.

**Rationale**: FR-008 requires the check to execute before `result.hasErrors()` and to be non-bypassable for a non-null, parseable date. User Story 3 and its acceptance scenarios confirm that a null or unparseable date produces a binding error before the method body runs; the new check is therefore unreachable in those cases, which is the correct behaviour (FR-004, edge case in spec). Placing the check after `result.hasErrors()` would mean a submission with both a past date and a blank description would skip the date check if the description error was already present, violating FR-011 (both errors must be returned together).

**Alternatives considered**:
- **Check after `result.hasErrors()`**: Rejected. Would suppress the date error when another field error is already present, violating FR-011.
- **Check inside a separate `@InitBinder` or `Validator`**: Rejected. See decision 1 above.

---

## 4. Null-safety of `visit.getDate()` at the check site

**Decision**: No explicit null guard is needed around `visit.getDate()` at the check site. The check is written as `if (visit.getDate() != null && visit.getDate().isBefore(LocalDate.now()))`.

**Rationale**: Spring MVC's data binding fires before the controller method body. A blank or unparseable date field produces a `BindingResult` error at binding time; `visit.getDate()` is left null (or retains the default from the `Visit` constructor, which is tomorrow). The spec's edge-case section confirms that a null date triggers the existing required-field binding error and that the new error code is not emitted. Adding a null guard makes the intent explicit and prevents a `NullPointerException` if the binding layer ever leaves the field null without adding a binding error (a defensive posture). The guard does not change observable behaviour for any scenario described in the spec.

**Alternatives considered**:
- **No null guard, rely on binding layer**: Acceptable in practice given the current binding configuration, but fragile. The null guard costs nothing and is the safer choice.
- **`Objects.requireNonNull` / throw**: Rejected. Would produce a 500 error rather than a form validation error for a null date, breaking User Story 3.

---

## 5. `minVisitDate` model attribute value

**Decision**: Change the `minVisitDate` model attribute in `initNewVisitForm` from `LocalDate.now().plusDays(1)` (tomorrow) to `LocalDate.now()` (today).

**Rationale**: FR-005 requires `minVisitDate` to equal `LocalDate.now()` so that the form hint matches the server-side acceptance rule. The spec's assumptions section confirms the template already reads this attribute and will reflect the change without a template edit, satisfying FR-007. The plan's risk register acknowledges that this changes the rendered minimum-date hint on the form and records it as an accepted risk (the G1 approver accepted it).

**Alternatives considered**:
- **Leave `minVisitDate` as tomorrow**: Rejected. Would create a mismatch between the form hint (tomorrow) and the server rule (today), confusing users who try to book a same-day visit. Violates FR-005.
- **Remove `minVisitDate` entirely**: Rejected. The template reads it; removing it would break the hint rendering without a template change, which is prohibited.

---

## 6. Definition of "today" and time-zone handling

**Decision**: Use `LocalDate.now()` with no explicit `ZoneId` argument. Document the JVM-default-time-zone dependency in a code comment in `VisitController`.

**Rationale**: The spec's assumptions section explicitly states that "today" is `LocalDate.now()` using the JVM's default time zone, that no explicit time-zone override is introduced, and that this is documented in a code comment. Introducing a `Clock` or `ZoneId` parameter would require changes beyond the two permitted files (e.g., a Spring bean definition or constructor injection) and is explicitly noted as out of scope in the plan's risk register.

**Alternatives considered**:
- **`LocalDate.now(ZoneId.of("UTC"))`**: Rejected. Hardcodes a zone that may differ from the server's operational zone; not requested by the spec.
- **Injectable `Clock` bean**: Rejected. Out of scope per the plan's risk register. Would require changes beyond `VisitController.java` and `VisitControllerTests.java`.
- **`LocalDate.now(ZoneId.systemDefault())`**: Functionally identical to `LocalDate.now()` (the no-arg form calls `systemDefault()` internally). Either form is acceptable; the no-arg form is more idiomatic and matches the spec's wording.

---

## 7. Test structure in `VisitControllerTests`

**Decision**: Replace the single existing test `processNewVisitFormHasErrorsWhenVisitDateIsNotInFuture` with one new test method that (a) POSTs yesterday's date and asserts HTTP 200, the form view, a `date` field error with the exact message, and `verify(owners, never()).save(any())`, then (b) POSTs today's date with a valid description and asserts a 3xx redirect and `verify(owners, times(1)).save(any())`.

**Rationale**: FR-006 requires one test demonstrating both outcomes. KPI-1 requires the surefire report to show exactly 5 tests, 0 failures. The plan's acceptance criterion names the replaced test explicitly. Using `LocalDate.now()` computed at test runtime (not a fixed date) satisfies FR-006's prohibition on fixed calendar dates and mitigates the midnight-boundary flake risk noted in the plan's risk register (the risk register's mitigation is to compute today once and use it for both sub-assertions). The `never()` assertion on `owners.save` after the yesterday POST and before the today POST ensures the mock state is clean for the second assertion.

**Alternatives considered**:
- **Two separate test methods (one for rejection, one for acceptance)**: Would produce 6 tests in the class, violating KPI-1's requirement of exactly 5.
- **Parameterised test**: Would change the test count depending on the number of parameters and complicates the `never()` / `times(1)` mock verification sequence. Not required by the spec.
- **Fixed dates (e.g., `LocalDate.of(2020, 1, 1)`)**: Rejected by FR-006.

---

## 8. Impact on `I18nPropertiesSyncTest`

**Decision**: No action required. The test will continue to pass without modification.

**Rationale**: `I18nPropertiesSyncTest` verifies that every key referenced in Thymeleaf templates exists in all `messages*.properties` files (and vice versa, depending on implementation). The new error message is a Java default message passed directly to `rejectValue`; it is not a Thymeleaf `#{...}` key reference and introduces no new entry in any properties file. FR-003 explicitly prohibits editing any `messages*.properties` file. The spec's assumptions section confirms this analysis.

**Alternatives considered**:
- **Add `visit.date.pastNotAllowed` to all `messages*.properties` files**: Rejected by FR-003. Would also require editing files outside the two permitted files (FR-007).

---

## 9. Impact on existing `ClinicServiceTests.shouldAddNewVisitForPet`

**Decision**: No action required. The test will continue to pass without modification.

**Rationale**: `shouldAddNewVisitForPet` creates a `new Visit()` and saves it via `OwnerRepository`. The `Visit` default constructor sets `date` to tomorrow. The new past-date check lives exclusively in `VisitController.processNewVisitForm` and is not applied at the entity or persistence layer (FR-012, spec assumptions). `ClinicServiceTests` does not go through the controller; it calls the repository directly. Tomorrow is a future date and would pass the check even if it were applied, but it is not applied in this path.

**Alternatives considered**:
- **Add a bean-validation annotation to `Visit.date`**: Rejected. See decision 1. Would cause `shouldAddNewVisitForPet` to fail if the annotation fired on persistence.

---

## 10. Impact on existing past-dated rows in seed data

**Decision**: No action required. Past-dated rows in H2, MySQL, and PostgreSQL seed data remain readable and writable without modification.

**Rationale**: FR-012 explicitly prohibits any schema, seed, or migration change and requires past-dated rows to remain readable. The controller check fires only on new-visit POST submissions. No entity-level annotation is added. `OwnerRepository.save` called from paths other than `processNewVisitForm` (e.g., `ClinicServiceTests`, `PetClinicIntegrationTests`) is unaffected.

**Alternatives considered**:
- **Data migration to remove or update past-dated rows**: Rejected by FR-012.

---

## 11. `@InitBinder` and allowed-fields configuration

**Decision**: No change. The `@InitBinder` method's `setAllowedFields` call for `id` and `*.id` on the visit form binder remains exactly as it is on main.

**Rationale**: FR-009 prohibits any change to `setAllowedFields`. The past-date check does not interact with the binder configuration; it operates on the already-bound `Visit` object.

**Alternatives considered**: None applicable.

---

## 12. Diff scope enforcement

**Decision**: The commit touches exactly `VisitController.java` and `VisitControllerTests.java`. No other file is modified.

**Rationale**: FR-007 and SC-002 together require this. The research above confirms that no template, properties file, schema file, seed file, entity class, or configuration file needs to change to deliver the feature. The `minVisitDate` change in `initNewVisitForm` is within `VisitController.java`. The test replacement is within `VisitControllerTests.java`.

**Alternatives considered**: None; the constraint is absolute per the spec.

---

## 13. Constitution Principle II exception (bean validation on domain class)

**Decision**: The constitution's Principle II requirement to use Jakarta Bean Validation annotations on domain classes is not followed for this change. This is a deliberate, scoped exception recorded as ADR-APP-1 and ADR-APP-2 in the spec.

**Rationale**: The constitution is an unratified draft (its own governance section states this). The approved brief and the locked spec take precedence for this change. The exception is justified by: (a) the prohibition on modifying `Visit.java`, (b) the requirement not to affect persistence-layer saves of existing past-dated data, and (c) the `ClinicServiceTests` dependency on the `Visit` default constructor's tomorrow date. The exception is explicitly documented in the spec's assumptions section.

**Alternatives considered**:
- **Ratify the constitution and enforce Principle II**: Out of scope for this feature. Would require a separate amendment PR.
- **Add a conditional bean-validation annotation that is profile-aware**: Rejected. No such standard mechanism exists in Jakarta Bean Validation; would require a custom `ConstraintValidator` and modifications to `Visit.java`.

---

## 14. NEEDS CLARIFICATION items

The following items are not fully settled by the inputs provided. They do not block implementation of the two-file change but are recorded for completeness.

**NC-1 — Exact current implementation of `processNewVisitForm` and `initNewVisitForm`**
The spec describes the intended post-change behaviour but does not reproduce the current source of `VisitController.java`. The implementer must read the live file on main to confirm: the exact method signatures, the current `minVisitDate` expression (assumed to be `LocalDate.now().plusDays(1)`), the current `result.hasErrors()` guard structure, and the current `@InitBinder` body. The research above assumes the standard Spring PetClinic structure; if the live file differs materially, the insertion point for the check must be adjusted accordingly.

**NC-2 — Exact current implementation of the replaced test**
The spec names the test `processNewVisitFormHasErrorsWhenVisitDateIsNotInFuture` and states it expected today to be rejected. The implementer must read the live `VisitControllerTests.java` to confirm the method name, the mock setup, and the assertions, so that the replacement test preserves the surrounding mock configuration (e.g., `given(owners.findById(...)).willReturn(...)`) and does not inadvertently break the other four tests.

**NC-3 — CI pipeline and surefire output path**
The plan's risk register notes that the pipeline and k8s files were not read and that the assumption "existing pipeline builds, tests and keeps surefire output" is unverified. The implementer should confirm that the GitHub Actions workflow runs `mvn test` (or equivalent) and retains the surefire XML report, so that KPI-1's surefire-report assertion can be verified in CI.

**NC-4 — Behaviour of `I18nPropertiesSyncTest` with respect to Java-only default messages**
The research above concludes the test will pass because the new message is not a template key. This conclusion depends on the test's implementation checking only template `#{...}` references against properties files. If the test also scans Java source for string literals or error codes, it might flag `visit.date.pastNotAllowed`. The implementer should read `I18nPropertiesSyncTest.java` to confirm the scan scope before finalising the approach.
