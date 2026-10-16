# Feature Specification: Duplicate Visit Prevention & Visit Booking Validation

**Feature Branch**: `007-visits-petclinic`

**Created**: 2026-10-16

**Status**: Draft

**Input**: User description: "Visits for petclinic"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reject Duplicate Visit on Same Date (Priority: P1)

A clinic receptionist attempts to book a second visit for a pet on a date that already has an existing visit scheduled. The system must detect the conflict and reject the submission with a clear, field-level error on the date field, so that the pet's visit history never contains two entries for the same date.

**Why this priority**: This is the primary open defect (BR-007) in the visits module. Without this guard, duplicate records corrupt the pet's visit history and undermine the append-only integrity rule. All other stories depend on the validation layer being trustworthy.

**Independent Test**: Can be fully tested by submitting a visit form for a pet that already has a visit on the target date and verifying that the form is returned with a date field error and no new record is persisted.

**Acceptance Scenarios**:

1. **Given** a pet already has a visit booked for a future date, **When** a second visit form is submitted for the same pet with the same date, **Then** the system rejects the submission, returns the visit form view with HTTP 200, and displays a field-level validation error on the date field.
2. **Given** a pet already has a visit booked for a future date, **When** a visit form is submitted for a *different* pet belonging to the same owner with that same date, **Then** the system accepts the submission, persists the new visit, and redirects to the owner detail page.
3. **Given** a pet already has a visit booked for a future date, **When** a visit form is submitted for the same pet with a *different* future date, **Then** the system accepts the submission, persists the new visit, and redirects to the owner detail page.

---

### User Story 2 - Reject Visit Booking for Non-Future Date (Priority: P2)

A clinic receptionist attempts to book a visit using today's date or a past date. The system must reject the submission with a clear error on the date field, enforcing the rule that all visits must be scheduled for a future date.

**Why this priority**: The future-date rule (BR-001) is already partially enforced via a default value and a minimum-date hint in the UI, but the server-side rejection must be explicit and consistent. This story ensures the validation is robust regardless of how the form is submitted.

**Independent Test**: Can be fully tested by submitting a visit form with `date` set to today's date and verifying that the form is returned with a date field error and no record is persisted.

**Acceptance Scenarios**:

1. **Given** a valid pet and owner exist, **When** a visit form is submitted with `date` set to today's date, **Then** the system rejects the submission, returns the visit form view with HTTP 200, and displays a field-level validation error on the date field.
2. **Given** a valid pet and owner exist, **When** a visit form is submitted with `date` set to a past date, **Then** the system rejects the submission, returns the visit form view with HTTP 200, and displays a field-level validation error on the date field.
3. **Given** a valid pet and owner exist, **When** a visit form is submitted with `date` set to tomorrow or any later future date, **Then** the system accepts the submission (assuming no duplicate) and redirects to the owner detail page.

---

### User Story 3 - Validation Error Messages Available in All Supported Languages (Priority: P3)

When a visit booking is rejected due to a duplicate date or a non-future date, the error message displayed to the user must be available in every language supported by the application's internationalisation bundles. A build that introduces new message keys without providing translations in all bundles must fail.

**Why this priority**: Internationalisation completeness is a quality gate enforced by `I18nPropertiesSyncTest`. Introducing new validation messages without full translations would break the CI pipeline and block all merges. This story ensures the feature ships with complete i18n coverage.

**Independent Test**: Can be fully tested by running `I18nPropertiesSyncTest` after adding the new message keys and verifying that all locale-specific properties files contain the required keys with non-empty translations.

**Acceptance Scenarios**:

1. **Given** new validation message keys are added for duplicate-date and non-future-date errors, **When** `I18nPropertiesSyncTest` is executed, **Then** the test passes, confirming all supported locale bundles contain the new keys.
2. **Given** a user with a non-default locale submits a duplicate visit, **When** the form is returned with an error, **Then** the error message is displayed in the user's locale rather than falling back to a raw message key.

---

### User Story 4 - Successful Visit Booking Appended to Pet History (Priority: P2)

A clinic receptionist books a valid visit (future date, no duplicate for that pet) and the system persists the record and appends it to the pet's visit history without modifying or removing any existing visit records.

**Why this priority**: This is the core happy-path flow. It confirms that the validation additions do not break the standard booking journey and that the append-only integrity rule (Constitution Principle II) is preserved.

**Independent Test**: Can be fully tested by submitting a valid visit form and then retrieving the pet's visit history to confirm the new record appears at the correct chronological position and all prior records remain intact.

**Acceptance Scenarios**:

1. **Given** a pet has zero or more existing visits, **When** a valid visit form is submitted with a future date not already booked for that pet and a non-empty description of at most 255 characters, **Then** the system persists the visit, redirects to the owner detail page, and the pet's visit history contains the new record appended in date-ascending order.
2. **Given** a pet has an existing visit, **When** a new valid visit is successfully booked, **Then** the previously existing visit record is unchanged and still present in the pet's visit history.

---

### Edge Cases

- What happens when the owner does not exist in the system? The system must reject the request before any visit validation occurs and return an appropriate error response.
- What happens when the pet does not belong to the specified owner? The system must reject the request with an error before any visit validation occurs.
- What happens when the description is blank? The system must reject the submission with a field-level error on the description field.
- What happens when the description exceeds 255 characters? The system must reject the submission with a field-level error on the description field.
- What happens when both the date is invalid *and* the description is blank? Both field errors must be reported simultaneously so the user can correct all issues in a single round-trip.
- What happens when a pet has no prior visits and a valid booking is submitted? The system must accept the booking without triggering any duplicate-detection logic.
- What happens when the `id` field is supplied in the form submission? The system must silently discard it and not allow client-supplied IDs to influence the persisted record.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST reject a new visit booking when the submitted date is not strictly in the future (i.e., today's date or any past date is invalid), returning a field-level validation error on the date field.
- **FR-002**: System MUST reject a new visit booking when the pet already has an existing visit recorded on the same date, returning a field-level validation error on the date field.
- **FR-003**: System MUST permit a visit booking on a date already used by a *different* pet belonging to the same owner, so that duplicate-date detection is scoped strictly to the individual pet.
- **FR-004**: System MUST reject a visit booking when the description is blank, returning a field-level validation error on the description field.
- **FR-005**: System MUST reject a visit booking when the description exceeds 255 characters, returning a field-level validation error on the description field.
- **FR-006**: System MUST reject a visit booking when the specified owner does not exist, returning an error before any visit-level validation is attempted.
- **FR-007**: System MUST reject a visit booking when the specified pet does not belong to the specified owner, returning an error before any visit-level validation is attempted.
- **FR-008**: System MUST preserve all existing visit records without modification or deletion; new visit entries MUST only be appended to a pet's visit history.
- **FR-009**: System MUST expose all visit-related validation error messages through the internationalisation bundle, with complete translations present in every supported locale before the build passes.
- **FR-010**: System MUST discard any client-supplied `id` or nested `*.id` values submitted via the visit form, preventing client-side ID manipulation.
- **FR-011**: System MUST return the visit booking form (with all previously entered values and all active field errors) when any validation failure occurs, so the user can correct and resubmit without losing their input.

### Key Entities

- **Visit**: Represents a single scheduled veterinary appointment for a pet. Key attributes: date (must be a future date, unique per pet), description (non-blank, maximum 255 characters). A visit is immutable once created and belongs to exactly one pet.
- **Pet**: The animal for which visits are booked. Owns an ordered, append-only collection of visits. Belongs to exactly one owner. The duplicate-date constraint is evaluated within the scope of a single pet's visit collection.
- **Owner**: The registered guardian of one or more pets. Must exist and be the legitimate owner of the target pet before any visit can be created for that pet.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of visit booking attempts with a non-future date are rejected with a visible field-level error before any record is persisted.
- **SC-002**: 100% of visit booking attempts that would create a duplicate date entry for the same pet are rejected with a visible field-level error before any record is persisted.
- **SC-003**: Valid visit bookings (future date, no duplicate for the pet, non-blank description within 255 characters) succeed and appear in the pet's visit history on the first submission attempt.
- **SC-004**: All existing visit records for all pets remain intact and unmodified after any number of rejected or accepted booking attempts.
- **SC-005**: The `I18nPropertiesSyncTest` passes on every build after the feature is merged, confirming that all new validation message keys are present and non-empty in every supported locale bundle.
- **SC-006**: A receptionist can complete a valid visit booking in under 2 minutes from opening the visit form to seeing the confirmation on the owner detail page.
- **SC-007**: All validation errors (date, description, duplicate) are reported to the user in a single form round-trip, eliminating the need for multiple resubmissions to discover all issues.

## Assumptions

- The set of supported locales is fixed and known at build time; no dynamic locale registration is in scope for this feature.
- The duplicate-date check compares only the date portion of the visit timestamp; time-of-day is not a factor because `Visit.date` is typed as `LocalDate`.
- The visit booking form is the sole entry point for creating visits; no bulk import, API endpoint, or programmatic creation path bypasses the validation layer within the scope of this feature.
- The existing `VisitController` and `OwnerRepository` are the correct extension points for adding duplicate-date validation; no new repository interface or service layer is required.
- Visit records are never soft-deleted or archived; the append-only rule is absolute and no administrative override is in scope.
- The minimum bookable date (tomorrow) is enforced consistently between the UI hint (`minVisitDate` model attribute) and the server-side validation rule; both must agree.
- Performance requirements for the duplicate-date check are satisfied by the existing in-memory pet visit collection loaded eagerly (`FetchType.EAGER`); no additional database query optimisation is required for this feature.
- Mobile and accessibility requirements follow the existing Thymeleaf template conventions already in place for the visit form; no new UI framework or responsive design work is in scope.