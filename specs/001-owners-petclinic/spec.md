# Feature Specification: Owners Management

**Feature Branch**: `001-owners-petclinic`

**Created**: 2025-01-31

**Status**: Draft

**Input**: User description: "Owners for petclinic"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Register a New Owner (Priority: P1)

A clinic receptionist registers a new pet owner in the system by providing the owner's first name, last name, address, city, and a 10-digit telephone number. Once submitted, the owner record is saved and the receptionist is redirected to the owner's detail page.

**Why this priority**: Owner registration is the foundational entry point for all downstream clinic activity. No pet can be registered, no visit can be scheduled, and no veterinary history can be tracked without a valid owner record. This is the highest-value slice of the feature.

**Independent Test**: Can be fully tested by navigating to the new owner form, submitting valid data, and verifying the owner detail page displays the saved information — delivering a complete, usable owner record with no other stories required.

**Acceptance Scenarios**:

1. **Given** the receptionist is on the new owner form, **When** they submit a first name, last name, a valid address (≤255 characters), a valid city (≤80 characters), and a 10-digit telephone number, **Then** the owner record is persisted and the receptionist is redirected to the owner's detail page showing all submitted fields.
2. **Given** the receptionist submits the form with a telephone number that is not exactly 10 digits (e.g., letters, fewer or more digits), **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the telephone field and no record is saved.
3. **Given** the receptionist submits the form with a blank address or city, **When** the form is submitted, **Then** the form is re-displayed with field-level validation errors on the blank fields and no record is saved.
4. **Given** the receptionist submits the form with an address exceeding 255 characters or a city exceeding 80 characters, **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the oversized field and no record is saved.
5. **Given** the form is submitted, **When** the system processes the request, **Then** the `id` field is not accepted from the form payload, preventing client-side ID tampering.

---

### User Story 2 - Search for an Existing Owner (Priority: P1)

A clinic receptionist searches for an owner by last name to locate their record before adding a pet or scheduling a visit. The search returns a paginated list of matching owners. If only one match is found, the system navigates directly to that owner's detail page.

**Why this priority**: Owner lookup is required before any pet or visit operation can proceed. Without search, the clinic cannot service returning customers. This story is equally foundational to registration and must be delivered together with it for the feature to be usable.

**Independent Test**: Can be fully tested by entering a partial or full last name in the search form and verifying the results list or direct redirect — delivering a complete owner lookup workflow independently of registration or editing.

**Acceptance Scenarios**:

1. **Given** one or more owners exist with a last name starting with the search term, **When** the receptionist submits a last name search, **Then** a paginated list of matching owners is displayed showing each owner's name, address, city, telephone, and their registered pets.
2. **Given** exactly one owner matches the search term, **When** the receptionist submits the search, **Then** the system redirects directly to that owner's detail page.
3. **Given** no owners match the search term, **When** the receptionist submits the search, **Then** the results page displays a message indicating no owners were found.
4. **Given** the receptionist submits the search form with a blank last name, **When** the form is submitted, **Then** all owners are returned in a paginated list (broadest search).
5. **Given** the receptionist enters a last name with leading or trailing whitespace, **When** the form is submitted, **Then** the whitespace is stripped before querying and results are equivalent to the trimmed search term.
6. **Given** the results span multiple pages, **When** the receptionist navigates between pages, **Then** each page displays the correct subset of matching owners without duplicates or omissions.

---

### User Story 3 - View Owner Details (Priority: P1)

A clinic receptionist views the full detail page for a specific owner, including their contact information and a list of all registered pets with each pet's type, birth date, and visit history.

**Why this priority**: The owner detail page is the central hub from which all pet and visit management actions are initiated. It must be available as soon as an owner record exists.

**Independent Test**: Can be fully tested by navigating directly to an owner's detail page via their ID and verifying all owner fields and associated pets are displayed correctly.

**Acceptance Scenarios**:

1. **Given** an owner record exists with one or more pets, **When** the receptionist navigates to the owner's detail page, **Then** the page displays the owner's first name, last name, address, city, telephone, and a list of pets ordered by name, each showing pet type, birth date, and visit history.
2. **Given** an owner record exists with no pets, **When** the receptionist navigates to the owner's detail page, **Then** the page displays the owner's contact information and an empty pets section.
3. **Given** an owner ID that does not exist in the system, **When** the receptionist navigates to that owner's detail page, **Then** the system returns an appropriate error response and does not expose sensitive data in error messages or stack traces.

---

### User Story 4 - Update an Existing Owner (Priority: P2)

A clinic receptionist updates the contact information for an existing owner — for example, correcting a telephone number or updating an address after the owner moves.

**Why this priority**: Owner data changes over time and must be kept accurate for the clinic to contact owners. This is important but not blocking for initial registration and lookup workflows.

**Independent Test**: Can be fully tested by loading the edit form for an existing owner, submitting updated valid data, and verifying the owner detail page reflects the changes.

**Acceptance Scenarios**:

1. **Given** an existing owner record, **When** the receptionist submits the edit form with updated valid contact information, **Then** the owner record is updated and the receptionist is redirected to the owner's detail page showing the new values.
2. **Given** the receptionist submits the edit form with an invalid telephone number (not exactly 10 digits), **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the telephone field and the existing record is not modified.
3. **Given** the receptionist submits the edit form with a blank address or city, **When** the form is submitted, **Then** the form is re-displayed with field-level validation errors and the existing record is not modified.
4. **Given** the edit form is submitted, **When** the system processes the request, **Then** the `id` field is not accepted from the form payload, preventing client-side ID tampering.
5. **Given** an owner ID that does not exist, **When** an update is attempted for that ID, **Then** the system returns an appropriate error and does not create a new record.

---

### User Story 5 - Add Optional Email Address to Owner (Priority: P2)

A clinic receptionist optionally records an email address for an owner during registration or when updating an existing owner record. The email address is displayed on the owner detail page when present.

**Why this priority**: Email contact is increasingly important for appointment reminders and clinic communications. It is optional and does not block core owner management, but adds meaningful value for clinic operations.

**Independent Test**: Can be fully tested by submitting the owner form with a valid email address and verifying it is persisted and displayed on the detail page, and separately by submitting an invalid email and verifying the field-level error.

**Acceptance Scenarios**:

1. **Given** the receptionist submits the owner form with a valid email address (properly formatted, ≤255 characters), **When** the form is submitted, **Then** the email is persisted and displayed on the owner detail page.
2. **Given** the receptionist submits the owner form without an email address, **When** the form is submitted, **Then** the owner record is saved successfully with no email value and the detail page does not display an email field or displays it as empty.
3. **Given** the receptionist submits the owner form with an email address that is not a valid email format, **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the email field and no record is saved or updated.
4. **Given** the receptionist submits the owner form with an email address exceeding 255 characters, **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the email field.
5. **Given** existing sample data does not include email addresses, **When** the application starts with any supported database profile (H2, MySQL, PostgreSQL), **Then** the sample data loads without error and existing owner records display without an email value.

---

### User Story 6 - Prevent Duplicate Visit Booking for the Same Pet on the Same Date (Priority: P3)

A clinic receptionist attempts to book a second visit for a pet on a date that already has a visit scheduled. The system rejects the duplicate booking with a clear validation error while allowing the same date to be booked for a different pet belonging to the same owner.

**Why this priority**: Duplicate visit prevention protects data integrity and prevents scheduling conflicts, but it is an enhancement to the visit booking flow rather than a core owner management capability.

**Independent Test**: Can be fully tested by booking a visit for a pet on a specific future date, then attempting to book a second visit for the same pet on the same date and verifying the rejection, while confirming a different pet under the same owner can book that date successfully.

**Acceptance Scenarios**:

1. **Given** a pet already has a visit booked for a specific future date, **When** a second visit is submitted for the same pet on that same date, **Then** the form is re-displayed with a validation error on the date field and no duplicate visit is created.
2. **Given** a pet already has a visit booked for a specific future date, **When** a visit is submitted for a different pet belonging to the same owner on that same date, **Then** the visit is accepted and persisted successfully.
3. **Given** a visit is submitted for a pet with a date in the past or today, **When** the form is submitted, **Then** the form is re-displayed with a validation error indicating the date must be in the future (existing rule still applies independently of the duplicate check).
4. **Given** a validation error message is defined for the duplicate date rule, **When** the error is triggered, **Then** the error message is present in all supported message bundles and renders correctly in all supported locales.

---

### Edge Cases

- What happens when an owner search returns more than the maximum page size of results — does pagination correctly segment all results without omitting any owner?
- How does the system handle concurrent submissions of the same new owner form (e.g., double-click on submit) — is a duplicate owner record created or is the second submission rejected?
- What happens when an owner's pet list is very large — does the owner detail page remain usable and does the pets list render in the correct alphabetical order?
- How does the system handle an `addVisit` call where the `petId` is valid but the pet does not belong to the resolved owner — is `IllegalArgumentException` surfaced as a user-friendly error rather than an unhandled exception?
- What happens when the owner form is submitted with a telephone number containing spaces or dashes (e.g., `555-123-4567`) — is the format rejection message clear to the user?
- How does the system behave when the database is unavailable during an owner save operation — is the error handled gracefully without exposing internal details?
- What happens when an owner record is loaded for editing and the owner ID in the URL does not match the ID in the submitted form — is the mismatch detected and rejected?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow a clinic receptionist to register a new owner by providing first name, last name, address, city, and telephone number via a web form.
- **FR-002**: System MUST validate that the owner's address is not blank and does not exceed 255 characters, rejecting the form with a field-level error if violated.
- **FR-003**: System MUST validate that the owner's city is not blank and does not exceed 80 characters, rejecting the form with a field-level error if violated.
- **FR-004**: System MUST validate that the owner's telephone number is not blank and consists of exactly 10 digits, rejecting the form with a field-level error and the `telephone.invalid` message if violated.
- **FR-005**: System MUST prevent client-side ID tampering by disallowing the `id` field and any nested `*.id` fields in owner form data binding.
- **FR-006**: System MUST allow a clinic receptionist to search for owners by last name, returning a paginated list of owners whose last names start with the provided search term.
- **FR-007**: System MUST strip leading and trailing whitespace from the last name search term before querying; a blank search term MUST return all owners.
- **FR-008**: System MUST redirect directly to the owner detail page when a last name search returns exactly one matching owner.
- **FR-009**: System MUST display the owner detail page showing the owner's contact information and all associated pets ordered alphabetically by pet name, with each pet's type, birth date, and visit history.
- **FR-010**: System MUST allow a clinic receptionist to update an existing owner's contact information via an edit form, subject to the same validation rules as registration.
- **FR-011**: System MUST return an appropriate error when an owner lookup by ID finds no matching record, without exposing sensitive data in error messages or stack traces.
- **FR-012**: System MUST support an optional email address field on the owner registration and edit forms, validated as a properly formatted email address not exceeding 255 characters.
- **FR-013**: System MUST display a field-level validation error on the email field when a non-empty email value fails format or length validation, and MUST re-display the form at `owners/createOrUpdateOwnerForm`.
- **FR-014**: System MUST persist owner email address values across all three supported database profiles (H2, MySQL, PostgreSQL) without breaking existing sample data loads.
- **FR-015**: System MUST prevent a second visit from being booked for the same pet on a date that already has an existing visit, returning a validation error on the date field.
- **FR-016**: System MUST permit a visit to be booked for a different pet belonging to the same owner on a date already used by another pet under that owner.
- **FR-017**: System MUST enforce that all visit dates are in the future, independently of the duplicate-date check.
- **FR-018**: System MUST expose all owner-facing labels and validation error messages through every supported message bundle so that the UI renders correctly in all supported locales.
- **FR-019**: System MUST log no owner sensitive fields (name, address, telephone) in any log statement, error message, stack trace, or actuator output.

### Key Entities

- **Owner**: Represents a registered pet owner and clinic customer. Key attributes: first name, last name, address (≤255 chars, required), city (≤80 chars, required), telephone (exactly 10 digits, required), email (optional, valid format, ≤255 chars). Owns zero or more Pets.
- **Pet**: Belongs to exactly one Owner. Key attributes: name (required, ≤30 chars), birth date (required), pet type (required for new pets). Carries a collection of Visits ordered by date.
- **Visit**: Records a single veterinary encounter for a Pet. Key attributes: date (required, must be in the future, no duplicate per pet per date), description (required, ≤255 chars). Immutable once created — visit history is append-only.
- **PetType**: A reference classification for a Pet (e.g., dog, cat, bird). Required at pet registration. Managed as a lookup collection.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A clinic receptionist can complete new owner registration — from opening the form to viewing the confirmed owner detail page — in under 2 minutes under normal clinic conditions.
- **SC-002**: Owner search by last name returns results in under 1 second for a dataset of up to 10,000 owner records.
- **SC-003**: 100% of owner form submissions with invalid data (blank required fields, malformed telephone, invalid email) are rejected with a visible field-level error message before any record is persisted.
- **SC-004**: The owner detail page correctly displays all registered pets in alphabetical order by name for owners with up to 50 pets.
- **SC-005**: All owner-facing validation error messages render without missing keys or raw message codes in every supported locale.
- **SC-006**: Zero owner sensitive fields (name, address, telephone) appear in application logs, error responses, or actuator outputs under any tested scenario.
- **SC-007**: Duplicate visit booking for the same pet on the same date is rejected 100% of the time, with no duplicate visit records created under concurrent submission conditions.
- **SC-008**: The application starts successfully and all existing sample data loads without error across all three database profiles (H2, MySQL, PostgreSQL) after the email field schema change is applied.
- **SC-009**: 95% of receptionists successfully locate an existing owner record using the last name search on their first attempt, as measured during user acceptance testing.

## Assumptions

- The application is a single-clinic, single-location system; multi-clinic or multi-location scenarios are out of scope per the project constitution.
- The web UI is the only interface for owner management; no REST API or mobile interface is in scope for this feature.
- Authentication and authorisation for clinic staff (receptionists) are handled by an existing or separately specified mechanism; this feature does not introduce new access control roles.
- The email address field is optional for all owners, including existing records; no backfill or migration of email data for existing owners is required.
- Schema changes for the email field will be applied via the existing profile-aware schema management mechanism (Spring Data JPA DDL or versioned migration scripts) and validated against H2, MySQL, and PostgreSQL before merge.
- The duplicate visit date check applies per pet per calendar date; time-of-day scheduling within a single date is out of scope.
- Visit records are never deleted; the duplicate-date check operates only against existing, persisted visit records.
- Pagination page size for owner search results follows the existing application default; configurable page size is out of scope.
- All user-facing strings introduced by this feature will be added to all supported locale message property files simultaneously to satisfy the `I18nPropertiesSyncTest`.
- The `id` field tampering prevention applies to both the owner registration and owner edit forms.
- GraalVM native image compatibility must be maintained; any new reflection-dependent types introduced by this feature must be registered in `PetClinicRuntimeHints`.