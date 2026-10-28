# Feature Specification: Reject Past Visit Dates

**Feature Branch**: `010-reject-past-visit-dates-15ab17d7`

**Created**: 2026-10-26

**Status**: Draft

**Input**: User description: "On main, reject a visit whose date is before today, and show the validation error 'Visit date must be today or in the future.'"

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Clinic Staff Submits a Visit with a Past Date (Priority: P1)

A clinic receptionist opens the new-visit form for a pet and accidentally enters a date from last week. On submission, the form rejects the entry and displays the message "Visit date must be today or in the future." The visit is not saved. The receptionist corrects the date and resubmits successfully.

**Why this priority**: This is the core behaviour change. Every other story depends on the date-rejection rule being in place. Without it the feature has no value.

**Independent Test**: Can be fully tested by POSTing a past date to `/owners/{ownerId}/pets/{petId}/visits/new` and asserting that the form view is returned with HTTP 200, a field error on `date` carrying the exact message, and that no visit is saved.

**Acceptance Scenarios**:

1. **Given** a valid owner and pet exist, **When** a POST is submitted with `date` set to yesterday (the day before `LocalDate.now()`), **Then** the response is HTTP 200, the view `pets/createOrUpdateVisitForm` is returned, a field error on `date` is present with default message exactly `"Visit date must be today or in the future."`, and `OwnerRepository.save` is never called.
2. **Given** a valid owner and pet exist, **When** a POST is submitted with `date` set to any date more than one day in the past, **Then** the same rejection behaviour as scenario 1 applies.
3. **Given** a valid owner and pet exist and the `date` field carries a past date, **When** the `description` field is also blank or invalid, **Then** both the `date` error and the `description` error are returned together in the same HTTP 200 response.

---

### User Story 2 — Clinic Staff Submits a Visit with Today's Date (Priority: P1)

A clinic receptionist books a same-day visit by entering today's date. The form accepts the entry and redirects to the owner's detail page. The visit is saved.

**Why this priority**: Accepting today's date is the explicit goal of this change and is equally critical to the rejection of past dates. Both halves of the rule must be verified together.

**Independent Test**: Can be fully tested by POSTing today's date (`LocalDate.now()`) to the new-visit endpoint and asserting a 3xx redirect to `/owners/{ownerId}` and that the visit is saved.

**Acceptance Scenarios**:

1. **Given** a valid owner and pet exist, **When** a POST is submitted with `date` set to `LocalDate.now()` and a valid description, **Then** the response is a 3xx redirect to `redirect:/owners/{ownerId}` and `OwnerRepository.save` is called exactly once.
2. **Given** a valid owner and pet exist, **When** a POST is submitted with `date` set to tomorrow or any future date and a valid description, **Then** the response is a 3xx redirect and the visit is saved (existing future-date behaviour is preserved).

---

### User Story 3 — Clinic Staff Submits a Visit with a Missing or Unparseable Date (Priority: P2)

A clinic receptionist submits the new-visit form with the date field left blank or containing a value that cannot be interpreted as a date. The form rejects the entry with the existing required-field or type-mismatch error. The new past-date rule does not interfere with this existing behaviour.

**Why this priority**: Preserving existing null and type-mismatch handling is a regression-safety requirement. It is lower priority than the new rule itself but must not be broken.

**Independent Test**: Can be fully tested by POSTing a blank or non-date value and asserting that the existing binding error on `date` is returned and that the new error code `visit.date.pastNotAllowed` is absent.

**Acceptance Scenarios**:

1. **Given** a valid owner and pet exist, **When** a POST is submitted with the `date` field blank, **Then** the response is HTTP 200 with the form view and a field error on `date` from the existing required-field constraint; the error code `visit.date.pastNotAllowed` is not present.
2. **Given** a valid owner and pet exist, **When** a POST is submitted with `date` set to a non-date string, **Then** the response is HTTP 200 with the form view and a binding/type-mismatch error on `date`; the new past-date check is not reached.

---

### User Story 4 — Automated Test Coverage Confirms Both Outcomes (Priority: P2)

A developer running the test suite sees one test in `VisitControllerTests` that posts yesterday's date and asserts rejection, and posts today's date and asserts acceptance. The test uses `LocalDate.now()` with no fixed dates. The four other existing tests in the class are unchanged and still pass. The surefire report shows 5 tests, 0 failures, 0 errors.

**Why this priority**: The test is the machine-readable proof of both KPIs. It is a deliverable in its own right, not merely a quality gate.

**Independent Test**: Can be fully tested by running `mvn test -pl . -Dtest=VisitControllerTests` and reading the surefire report.

**Acceptance Scenarios**:

1. **Given** the change is applied to main, **When** the Maven test phase runs, **Then** `VisitControllerTests` reports 5 tests, 0 failures, 0 errors, and the replaced test asserts the exact string `"Visit date must be today or in the future."` from the `BindingResult`.
2. **Given** the change is applied, **When** the full suite runs, **Then** `ClinicServiceTests`, `PetClinicIntegrationTests`, `OwnerControllerTests`, `PetControllerTests`, and `I18nPropertiesSyncTest` all pass with no assertion edits.

---

### Edge Cases

- What happens when the date submitted equals `LocalDate.now()` exactly at midnight boundary? The server's default JVM time zone determines "today"; the spec uses `LocalDate.now()` without a fixed zone, so the boundary is the JVM default. No special handling is required beyond documenting this in a code comment.
- What happens when both the date is in the past and the description is missing? Both errors must be reported together in the same response; neither suppresses the other.
- What happens when a seeded or historically saved visit carries a past date and the owner is subsequently saved (e.g., via `ClinicServiceTests`)? Because the date constraint is applied only at the controller layer on new-visit POST submissions, and no entity-level annotation is added to `Visit.java`, past-dated rows already in the database load and persist without error.
- What happens when the date field is null (not submitted)? The existing required-field binding error fires before the new past-date check is reached; the new error code is not emitted.
- What happens when `Visit`'s default constructor sets the date to tomorrow? The default is not changed; `ClinicServiceTests.shouldAddNewVisitForPet` continues to save a `new Visit()` with tomorrow's date through `OwnerRepository`, which remains valid under the new rule.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001** *(SPEC-APP-1)*: The system MUST reject a POST to the new-visit form when the submitted `date` value is before `LocalDate.now()` (the server's default date), returning HTTP 200 with the form view `pets/createOrUpdateVisitForm` and a field error on `date`. `OwnerRepository.save` MUST NOT be called for a rejected submission.
- **FR-002** *(SPEC-APP-1)*: The system MUST accept a POST to the new-visit form when the submitted `date` value equals `LocalDate.now()` or is any date after `LocalDate.now()`, provided all other fields are valid, and MUST redirect to `redirect:/owners/{ownerId}`.
- **FR-003** *(SPEC-APP-2)*: The field error on `date` for a rejected past date MUST carry the error code `visit.date.pastNotAllowed` and the default message exactly `"Visit date must be today or in the future."`. This message MUST be a compile-time constant supplied from Java with no concatenation of request data. No `messages*.properties` file MUST be edited.
- **FR-004** *(SPEC-APP-2)*: The error code `typeMismatch.visitDate` MUST NOT be used for the past-date rejection. The existing type-mismatch error code MUST remain available for genuinely unparseable date input.
- **FR-005** *(SPEC-APP-3)*: The `minVisitDate` model attribute exposed to the form on GET MUST equal `LocalDate.now()` so that the form hint matches the server-side acceptance rule.
- **FR-006** *(SPEC-APP-4)*: One JUnit test in `VisitControllerTests` MUST demonstrate that a date of yesterday is rejected with the exact error message and that a date of today is accepted with a redirect. The test MUST use `LocalDate.now()` computed at test runtime and MUST NOT use fixed calendar dates. The old test that expected today to be rejected MUST be replaced by this test.
- **FR-007** *(SPEC-APP-5)*: Only `VisitController.java` and `VisitControllerTests.java` MUST be modified. `Visit.java` is permitted to be read but MUST remain byte-identical before and after the change. No template, message bundle, schema file, seed file, Kubernetes manifest, or CI configuration file MUST be changed.
- **FR-008** *(SPEC-SEC-1)*: The past-date check MUST be performed server-side in `VisitController.processNewVisitForm`, regardless of any client-side hint or form value. The check MUST execute before the `result.hasErrors()` return and MUST NOT be bypassable for a non-null, parseable date.
- **FR-009** *(SPEC-SEC-3)*: The `@InitBinder` disallowed-field rule for `id` and `*.id` on the visit form binder MUST remain exactly as it is on main. No change to `setAllowedFields` is permitted.
- **FR-010** *(SPEC-INT-1)*: The route, HTTP methods, form field names (`date`, `description`), success redirect target, flash message, and HTTP 200 re-render on error for the visit form POST MUST be identical before and after the change.
- **FR-011** *(SPEC-INT-2)*: When both the `date` and `description` fields are invalid in the same submission, both field errors MUST be returned together in the same HTTP 200 response.
- **FR-012** *(SPEC-DATA-1, SPEC-DATA-3)*: No schema file, seed file, or database migration MUST be introduced. Past-dated visit rows already stored in the database MUST remain readable and MUST NOT be rejected or modified by the change.

### Key Entities

- **Visit**: A recorded veterinary appointment associated with exactly one Pet. Relevant attributes for this change: `date` (the appointment date, validated at submission time in the controller) and `description` (free text, existing validation unchanged). The `Visit` default constructor sets `date` to tomorrow; this default MUST NOT change. No new bean-validation annotation is added to the `date` field on the entity.
- **VisitController**: The Spring MVC controller that handles GET and POST for the new-visit form. This change adds a server-side date comparison in `processNewVisitForm` and updates the `minVisitDate` model attribute in `initNewVisitForm`.
- **OwnerRepository**: The repository used to persist the owner aggregate (including the new visit). It MUST NOT be called when a visit submission is rejected.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **KPI-1**: Exactly one JUnit test in `VisitControllerTests` passes, demonstrating that a past date fails validation and today's date succeeds. The surefire report for `VisitControllerTests` shows 5 tests, 0 failures, 0 errors. Target: 1 new test passing, 0 failures across all 5 tests in the class.
- **KPI-2**: A visit submission dated before today returns the validation error with the exact text `"Visit date must be today or in the future."` The exact string match is verified by the `BindingResult` assertion in the test and by the surefire report showing that assertion passing. Target: exact text match on every past-date submission, 0 deviations.
- **SC-001**: The full automated test suite (including `ClinicServiceTests`, `PetClinicIntegrationTests`, `OwnerControllerTests`, `PetControllerTests`, and `I18nPropertiesSyncTest`) passes with no assertion edits to any file other than `VisitControllerTests.java`. Target: 0 regressions in the existing suite.
- **SC-002**: The change is delivered as a single commit touching only `VisitController.java` and `VisitControllerTests.java`, verified by `git diff` against the base commit on main. Target: 0 files changed outside the two permitted files.
- **SC-003**: The Maven validate phase (`spring-javaformat:validate` and `nohttp` checkstyle) passes on the changed files with no new suppressions. Target: 0 new checkstyle violations.

## Assumptions

- "Today" is defined as `LocalDate.now()` using the JVM's default time zone on the server. No explicit time-zone override is introduced; this is documented in a code comment in `VisitController`.
- The `Visit` default constructor's date of tomorrow is intentional and is not changed. `ClinicServiceTests.shouldAddNewVisitForPet` relies on this default remaining a future date.
- Past-dated visit rows already present in the H2, MySQL, and PostgreSQL seed data are legal at rest. The new validation applies only to new-visit POST submissions and is not enforced at the entity or persistence layer.
- The `createOrUpdateVisitForm.html` template is not changed. The updated `minVisitDate` model attribute (today instead of tomorrow) will be reflected in the form hint automatically without a template edit, because the template already reads the attribute.
- No message bundle entry for `visit.date.pastNotAllowed` is added. The Java default message is shown directly. `I18nPropertiesSyncTest` passes because no new key is introduced to any properties file.
- The constitution's preference for Jakarta Bean Validation annotations on domain classes (Principle II) is intentionally not followed for this change, in line with ADR-APP-1 and ADR-APP-2, which place the check in the controller. This is a deliberate, scoped exception recorded in the architecture decisions; the constitution is an unratified draft and the approved brief takes precedence for this change.
- Open GitHub issues #16 and #43 are not consumers of this change for the purposes of this spec. If they assert today's or past-date behaviour or the error text, they will need to be updated separately after this change merges.
- Pull requests #1 and #4 and their branches are out of scope. Any merge conflicts they introduce are outside the boundary of this feature.
- The plan for this feature is one Synapse code story with no blocking dependencies, no human tasks, and no approval tasks, as specified in the approved brief.
