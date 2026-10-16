# Feature Specification: Visits for PetClinic

**Feature Branch**: `003-visits-petclinic`

**Created**: 2025-01-31

**Status**: Draft

**Input**: User description: "Visits for petclinic"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reject Duplicate Visit on Same Date for Same Pet (Priority: P1)

A clinic receptionist attempts to book a second visit for a pet on a date that already has an existing visit booked for that same pet. The system must detect the conflict and reject the submission, keeping the form open so the receptionist can choose a different date.

**Why this priority**: Duplicate visit bookings create scheduling confusion, waste veterinarian time, and corrupt the pet's visit history. Preventing duplicates is the most critical correctness guarantee for the visit scheduling workflow.

**Independent Test**: Can be fully tested by submitting a visit form for a pet that already has a visit on the target date and verifying the form is returned with a date field error and no new visit record is created.

**Acceptance Scenarios**:

1. **Given** a pet already has a visit booked for a specific future date, **When** a second visit form is submitted for the same pet with the same date, **Then** the form is redisplayed with a validation error on the date field and no duplicate visit is persisted.
2. **Given** a pet already has a visit booked for a specific future date, **When** a visit form is submitted for a *different* pet belonging to the same owner on that same date, **Then** the submission is accepted and the visit is saved successfully.
3. **Given** a pet already has a visit booked for a specific future date, **When** a visit form is submitted for the same pet on a *different* future date, **Then** the submission is accepted and the new visit is saved successfully.

---

### User Story 2 - Reject Visit Booking for a Non-Future Date (Priority: P2)

A clinic receptionist attempts to book a visit for a pet using today's date or any past date. The system must reject the submission because only future dates are valid for new visit bookings.

**Why this priority**: Allowing past or same-day bookings would create invalid historical records and undermine the integrity of the visit schedule. This is a core data quality rule that must be enforced before any visit is persisted.

**Independent Test**: Can be fully tested by submitting a visit form with today's date or a past date and verifying the form is returned with a date field error and no visit record is created.

**Acceptance Scenarios**:

1. **Given** a valid pet and owner exist, **When** a visit form is submitted with today's date, **Then** the form is redisplayed with a validation error on the date field and no visit is persisted.
2. **Given** a valid pet and owner exist, **When** a visit form is submitted with a date in the past, **Then** the form is redisplayed with a validation error on the date field and no visit is persisted.
3. **Given** a valid pet and owner exist, **When** a visit form is submitted with a date at least one day in the future and a non-blank description of 255 characters or fewer, **Then** the submission is accepted, the visit is persisted, and the user is redirected to the owner's detail page.

---

### User Story 3 - Book a Valid Future Visit Successfully (Priority: P2)

A clinic receptionist fills in the visit booking form with a valid future date and a meaningful description, then submits it. The system saves the visit and returns the receptionist to the owner's profile page where the new visit appears in the pet's visit history.

**Why this priority**: This is the primary happy-path flow. Without it, the visit scheduling feature delivers no value. It is ranked P2 only because P1 (duplicate rejection) is the specific correctness gap identified in the open issue; the happy path is already partially functional.

**Independent Test**: Can be fully tested by submitting a valid visit form (future date, non-blank description ≤ 255 characters) for an existing pet under an existing owner and verifying a redirect to the owner page and the visit appearing in the pet's history.

**Acceptance Scenarios**:

1. **Given** an existing owner and pet, **When** the receptionist opens the new visit form, **Then** the date field is pre-populated with tomorrow's date as the default.
2. **Given** an existing owner and pet, **When** a visit form is submitted with a future date and a valid description, **Then** the visit is saved and the user is redirected to the owner's detail page.
3. **Given** an existing owner and pet, **When** a visit form is submitted with a description exceeding 255 characters, **Then** the form is redisplayed with a validation error on the description field and no visit is persisted.
4. **Given** an existing owner and pet, **When** a visit form is submitted with a blank description, **Then** the form is redisplayed with a validation error on the description field and no visit is persisted.

---

### User Story 4 - Localised Validation Error Messages (Priority: P3)

When a visit booking is rejected for any reason (duplicate date, non-future date, blank description, description too long), the error message displayed to the receptionist is shown in the language configured for their session. All validation error messages — including the duplicate-date rejection — are available in every supported language bundle.

**Why this priority**: Internationalisation is a quality and compliance concern rather than a core functional gap. The feature works correctly in the default language without this story; however, the project constitution mandates that all user-facing strings be externalised to message bundles and that the i18n sync test passes.

**Independent Test**: Can be fully tested by triggering each validation error in each supported locale and verifying the correct localised message is displayed, and by running the `I18nPropertiesSyncTest` to confirm all message keys are present in all language property files.

**Acceptance Scenarios**:

1. **Given** a supported non-default locale is active, **When** a duplicate-date visit submission is rejected, **Then** the error message displayed matches the localised string for that locale from the appropriate `messages_*.properties` file.
2. **Given** all supported language bundles, **When** the i18n sync test is executed, **Then** every visit-related validation message key is present in every language bundle and the test passes.

---

### Edge Cases

- What happens when the owner ID in the URL does not correspond to any existing owner? The system must raise an error and not attempt to create a visit.
- What happens when the pet ID in the URL does not belong to the resolved owner? The system must raise an error and not create a visit.
- What happens when the visit form is submitted without a date value at all? The system must treat this as a validation failure and redisplay the form with an appropriate error.
- What happens when the description is exactly 255 characters? The system must accept it as valid.
- What happens when the description is exactly 256 characters? The system must reject it with a validation error.
- What happens when a client attempts to supply a visit ID via the form submission? The system must silently discard the supplied ID and never allow client-controlled ID assignment.
- What happens when two concurrent requests attempt to book the same pet on the same date simultaneously? The system must ensure only one visit is persisted and the other is rejected.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST reject a new visit booking when the submitted date is today or any past date, returning a field-level validation error on the date field and redisplaying the booking form without persisting any record.
- **FR-002**: System MUST reject a new visit booking when the same pet already has an existing visit on the submitted date, returning a field-level validation error on the date field and redisplaying the booking form without persisting any record.
- **FR-003**: System MUST permit a visit booking for a pet on a date that no existing visit for that pet occupies, confirming that the duplicate-date guard does not block legitimate future bookings.
- **FR-004**: System MUST permit a visit booking for a different pet belonging to the same owner on a date already used by another of that owner's pets, confirming that duplicate-date validation is scoped strictly to the individual pet and not to the owner.
- **FR-005**: System MUST reject a visit booking when the description is blank, returning a field-level validation error on the description field.
- **FR-006**: System MUST reject a visit booking when the description exceeds 255 characters, returning a field-level validation error on the description field.
- **FR-007**: System MUST default the date field on the new visit form to tomorrow's date when the form is first rendered.
- **FR-008**: System MUST prevent the minimum selectable date in the visit booking form from being set to today or any past date.
- **FR-009**: System MUST discard any visit ID value submitted via the booking form; clients MUST NOT be able to assign or override visit IDs.
- **FR-010**: System MUST raise an error and halt processing if the owner identified by the URL parameter does not exist in the system.
- **FR-011**: System MUST raise an error and halt processing if the pet identified by the URL parameter does not belong to the resolved owner.
- **FR-012**: System MUST redirect the user to the owner's detail page upon successful visit submission.
- **FR-013**: System MUST surface all visit-related validation error messages — including the duplicate-date rejection message — in every supported i18n message bundle so that errors are localised consistently across all supported languages and the i18n sync test passes.

### Key Entities

- **Visit**: Represents a scheduled veterinary appointment for a specific pet. Key attributes: a future date (minimum tomorrow), a non-blank description of up to 255 characters, and an association to exactly one pet. Visit records are append-only and must never be deleted or overwritten once created.
- **Pet**: The animal for which a visit is being booked. A pet belongs to exactly one owner and may have zero or many visits. Duplicate-date validation is scoped to the individual pet's existing visit collection.
- **Owner**: The registered guardian of one or more pets. The owner is the top-level aggregate through which pets and their visits are accessed and persisted.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of visit booking attempts with a non-future date are rejected with a visible date field error before any record is persisted.
- **SC-002**: 100% of visit booking attempts that duplicate an existing visit date for the same pet are rejected with a visible date field error before any record is persisted.
- **SC-003**: Receptionists can complete a valid visit booking — from opening the form to receiving confirmation on the owner page — in under 60 seconds under normal operating conditions.
- **SC-004**: The i18n sync test passes with all visit-related validation message keys present in every supported language bundle, confirming zero missing translations.
- **SC-005**: The full automated test suite (unit, integration, and database tests) passes on every supported database profile (H2, MySQL, PostgreSQL) with no regressions introduced by the visit validation changes.
- **SC-006**: No visit record with a duplicate same-pet same-date combination exists in the data store after any sequence of valid and invalid booking attempts.

## Assumptions

- The visit booking form is accessed by clinic receptionists operating within the clinic's internal web interface; no public-facing or unauthenticated booking flow is in scope.
- "Future date" means any calendar date strictly after today's date in the server's local timezone; same-day bookings are not permitted.
- Duplicate-date detection compares only the calendar date (year, month, day); time-of-day is not a factor because the visit entity stores only a date, not a datetime.
- The minimum selectable date constraint is enforced at the UI level as a usability aid; server-side validation remains the authoritative enforcement mechanism.
- Visit records are immutable once created; there is no edit or delete visit capability in scope for this feature.
- The existing owner and pet resolution mechanism (URL path parameters for `ownerId` and `petId`) is the sole entry point for visit creation; no bulk or programmatic visit creation interface is in scope.
- All supported i18n locales are those already present in the project's `messages_*.properties` files; no new locales are being added as part of this feature.
- Concurrent duplicate-booking prevention relies on the persistence layer's transaction isolation; no additional distributed locking mechanism is assumed to be required for the current expected load.
- The `ClinicServiceTests` integration test suite is the authoritative integration-level test for visit persistence behaviour and must continue to pass without modification to its existing assertions.