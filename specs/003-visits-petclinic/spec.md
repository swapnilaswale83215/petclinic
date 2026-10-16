# Feature Specification: Visits for PetClinic

**Feature Branch**: `003-visits-petclinic`

**Created**: 2025-01-31

**Status**: Draft

**Input**: User description: "Visits for petclinic"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reject Duplicate Visit on Same Date for Same Pet (Priority: P1)

A clinic receptionist attempts to book a second visit for a pet on a date that already has an existing visit recorded for that same pet. The system must detect the conflict and prevent the duplicate booking, returning the form with a clear error message so the receptionist can choose a different date.

**Why this priority**: This closes a known gap (BR-008 / GitHub Issue #2) where the system currently allows duplicate same-pet same-date bookings, which would corrupt visit history and cause scheduling confusion. Fixing this is the highest-value, most urgent correctness improvement.

**Independent Test**: Can be fully tested by submitting a new visit form for a pet that already has a visit on the chosen future date, and verifying the form is returned with a field error on `date` — no persistence occurs and no redirect is issued.

**Acceptance Scenarios**:

1. **Given** a pet already has a visit booked for a specific future date, **When** a second visit form is submitted for the same pet with that same date, **Then** the form view is returned with HTTP 200, a field error is present on the `date` field, and no new visit record is persisted.
2. **Given** a pet already has a visit booked for a specific future date, **When** the duplicate submission is rejected, **Then** the error message is rendered in the active locale using a key present in all supported i18n message bundles.
3. **Given** a pet already has a visit booked for a specific future date, **When** a visit form is submitted for the same pet with a *different* future date, **Then** the submission is accepted, a redirect to the owner detail page is issued, and the new visit is persisted.

---

### User Story 2 - Reject Visit Booking for Today or a Past Date (Priority: P2)

A clinic receptionist attempts to schedule a visit using today's date or any date in the past. The system must reject the submission and return the form with a validation error on the date field, preventing any visit from being recorded for a non-future date.

**Why this priority**: This enforces the existing business rule (BR-001) that all visits must be in the future. While the UI constrains the minimum selectable date, server-side enforcement is required to guard against bypassed client-side controls.

**Independent Test**: Can be fully tested by submitting a visit form with `date` set to today's date or a past date and verifying the form is returned with HTTP 200 and a field error on `date`, with no visit persisted.

**Acceptance Scenarios**:

1. **Given** a valid pet and owner exist, **When** a visit form is submitted with `date` set to today's date, **Then** the response is HTTP 200, the form view is returned, a field error is present on `date`, and no visit is persisted.
2. **Given** a valid pet and owner exist, **When** a visit form is submitted with `date` set to a date in the past, **Then** the response is HTTP 200, the form view is returned, a field error is present on `date`, and no visit is persisted.
3. **Given** a valid pet and owner exist, **When** a visit form is submitted with `date` set to tomorrow or any future date, **Then** the submission proceeds to further validation (description, duplicate check) without a date-related error.

---

### User Story 3 - Successfully Book a Valid Future Visit (Priority: P2)

A clinic receptionist books a new visit for a pet by providing a future date and a non-empty description of at most 255 characters. The system accepts the submission, persists the visit against the correct pet, and redirects to the owner's detail page so the receptionist can confirm the booking.

**Why this priority**: This is the core happy-path scenario for visit scheduling. It must work correctly and remain unbroken after the duplicate-date and past-date validation changes are introduced.

**Independent Test**: Can be fully tested by submitting a valid visit form (future date, valid description, no existing visit on that date for the pet) and verifying a redirect to the owner detail page and the visit appearing in the pet's visit history.

**Acceptance Scenarios**:

1. **Given** a pet has no existing visit on a chosen future date, **When** a visit form is submitted with a future date and a description between 1 and 255 characters, **Then** the system redirects to the owner detail page and the new visit appears in the pet's visit list.
2. **Given** a pet has an existing visit on date X, **When** a visit form is submitted for a *different* pet belonging to the same owner on date X, **Then** the submission is accepted and the visit is persisted — duplicate-date validation is scoped to the individual pet, not the owner.
3. **Given** a visit form is submitted with a description of exactly 255 characters and a valid future date, **Then** the submission is accepted and the visit is persisted.

---

### User Story 4 - Reject Visit with Missing or Oversized Description (Priority: P3)

A clinic receptionist submits a visit form with either a blank description or a description exceeding 255 characters. The system must reject the submission and return the form with a validation error on the `description` field.

**Why this priority**: This enforces existing constraints (BR-002, BR-003) that are already declared on the domain model. The priority is lower because the constraints are already partially in place; this story ensures they are consistently surfaced to the user.

**Independent Test**: Can be fully tested by submitting a visit form with a blank description or a 256-character description and verifying the form is returned with HTTP 200 and a field error on `description`.

**Acceptance Scenarios**:

1. **Given** a valid pet and owner exist, **When** a visit form is submitted with an empty `description`, **Then** the response is HTTP 200, the form view is returned, and a field error is present on `description`.
2. **Given** a valid pet and owner exist, **When** a visit form is submitted with a `description` of 256 or more characters, **Then** the response is HTTP 200, the form view is returned, and a field error is present on `description`.
3. **Given** a valid pet and owner exist, **When** a visit form is submitted with a `description` of exactly 1 character and a valid future date, **Then** the submission is accepted (assuming no other validation failures).

---

### User Story 5 - Reject Visit for Invalid Owner or Pet (Priority: P3)

A request to create a visit references an owner ID or pet ID that does not exist in the system, or references a pet that does not belong to the specified owner. The system must reject the request and surface an appropriate error rather than silently failing or persisting an orphaned record.

**Why this priority**: This enforces BR-004 and BR-005. The guard already exists in the controller; this story ensures the behaviour is specified, tested, and does not regress.

**Independent Test**: Can be fully tested by submitting a visit creation request with a non-existent owner ID or a pet ID that does not belong to the given owner, and verifying the system returns an error response without persisting any visit.

**Acceptance Scenarios**:

1. **Given** no owner exists for a given owner ID, **When** a visit creation request is submitted for that owner ID, **Then** the system returns an error response and no visit is persisted.
2. **Given** a valid owner exists but the specified pet ID does not belong to that owner, **When** a visit creation request is submitted, **Then** the system returns an error response and no visit is persisted.

---

### Edge Cases

- What happens when a pet has no prior visits and a future date is submitted — does the duplicate check handle an empty visit collection without error?
- What happens when two concurrent requests attempt to book the same pet on the same date simultaneously — does the system prevent both from persisting?
- What happens when the `date` field is submitted in a format other than `yyyy-MM-dd` — does the system return a type-mismatch error on `date` rather than a null-pointer failure?
- What happens when the `description` field contains only whitespace characters — does `@NotBlank` correctly reject it as blank?
- What happens when a visit form is submitted without a `date` field at all — does the system return a field error rather than a server fault?
- What happens when the owner has multiple pets and each has a visit on the same date — does the duplicate check correctly scope to the individual pet and not block the other pets' bookings?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST reject a new visit booking when the submitted date is today or in the past, returning a field error on `date` and the visit form view without persisting any record.
- **FR-002**: System MUST reject a new visit booking when the same pet already has a visit recorded on the submitted date, returning a field error on `date` and the visit form view without persisting any record.
- **FR-003**: System MUST accept a new visit booking when the submitted date is in the future, the description is between 1 and 255 non-blank characters, and no existing visit for the same pet exists on that date, persisting the visit and redirecting to the owner detail page.
- **FR-004**: System MUST scope duplicate-date validation strictly to the individual pet — a different pet belonging to the same owner MUST be permitted to have a visit on a date already used by another pet under that owner.
- **FR-005**: System MUST reject a visit booking when the description is blank or contains only whitespace, returning a field error on `description`.
- **FR-006**: System MUST reject a visit booking when the description exceeds 255 characters, returning a field error on `description`.
- **FR-007**: System MUST reject a visit creation request that references a non-existent owner, returning an error response without persisting any visit.
- **FR-008**: System MUST reject a visit creation request that references a pet not belonging to the specified owner, returning an error response without persisting any visit.
- **FR-009**: System MUST NOT permit the `id` field or any nested `*.id` field to be submitted via the visit form.
- **FR-010**: System MUST surface all visit-related validation error messages — including the duplicate-date rejection message — in every supported i18n message bundle, ensuring consistent localisation across all supported languages.
- **FR-011**: Visit records MUST NOT be deleted once created; the visit history for a pet MUST be append-only.

### Key Entities

- **Visit**: Represents a scheduled veterinary appointment for a pet — identified by a system-assigned ID, associated with a specific pet, carrying a future date and a non-blank description of at most 255 characters.
- **Pet**: The animal for which visits are scheduled — owns an ordered, append-only collection of visits; duplicate-date validation is enforced at the individual pet level.
- **Owner**: The registered guardian of one or more pets — a visit creation request must reference a valid, existing owner; the owner is the aggregate root through which visits are persisted.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of visit submissions with a today or past date are rejected with a user-visible field error on the date field and zero visits persisted for those submissions.
- **SC-002**: 100% of visit submissions that duplicate an existing same-pet same-date booking are rejected with a user-visible field error on the date field and zero duplicate visits persisted.
- **SC-003**: 100% of valid visit submissions (future date, valid description, no duplicate) result in the visit being persisted and the user being redirected to the owner detail page within the same request cycle.
- **SC-004**: All validation error messages introduced or modified by this feature are present and non-empty in every supported locale message bundle, verified by the existing i18n properties sync test passing without modification to its scope.
- **SC-005**: Duplicate-date validation does not block valid bookings — a pet with N existing visits on distinct future dates can successfully book a visit on any date not already in its visit history, with a 0% false-positive rejection rate.
- **SC-006**: A different pet belonging to the same owner can book a visit on a date already used by another pet under that owner, with a 0% false-positive rejection rate for cross-pet date conflicts.
- **SC-007**: All new and modified code paths are covered by unit tests (domain logic, validators), controller slice tests (`@WebMvcTest`), and integration tests, with the full CI pipeline passing across H2, MySQL, and PostgreSQL profiles.

## Assumptions

- The visit scheduling feature is accessed exclusively through the existing server-side rendered web UI (Thymeleaf forms); no REST API endpoint for visit creation is in scope for this feature.
- The duplicate-date check compares only the `date` field (calendar day) of existing visits for the same pet — time-of-day is not a factor, as `Visit.date` is typed as `LocalDate`.
- Concurrent duplicate booking prevention (two simultaneous requests for the same pet on the same date) is a known edge case; optimistic locking or database-level unique constraints may be required but are flagged for review rather than mandated by this specification.
- The i18n message key for the duplicate-date error will follow the existing naming convention used by other visit-related validation messages in the project's message bundles.
- Visit history is append-only per the project constitution; no delete or edit capability for existing visits is in scope for this feature.
- The minimum bookable date enforced server-side is `today + 1 day` (tomorrow), consistent with the existing `minVisitDate` model attribute and the `Visit` constructor default.
- All supported locale message bundles are those already present in the repository at the time this feature is implemented; no new locales are added as part of this feature.
- Schema changes required to support a unique constraint on `(pet_id, date)` — if pursued — must be validated against H2, MySQL, and PostgreSQL profiles before merge, per the project constitution.
- The `OwnerRepository` remains the sole persistence entry point for visit creation; no new repository interface is introduced by this feature.