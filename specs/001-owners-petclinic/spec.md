# Feature Specification: Owners Management

**Feature Branch**: `001-owners-petclinic`

**Created**: 2025-01-31

**Status**: Draft

**Input**: User description: "Owners for petclinic"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Register a New Owner (Priority: P1)

A clinic receptionist registers a new pet owner by entering their first name, last name, address, city, and telephone number. The system validates all required fields and persists the owner record, then redirects to the owner's detail page.

**Why this priority**: Owner registration is the foundational entry point for all downstream clinic activity — no pets can be registered, no visits can be scheduled, and no records can be maintained without a valid owner on file. Every other owner-related story depends on this capability existing first.

**Independent Test**: Can be fully tested by navigating to `/owners/new`, submitting a valid form, and verifying the owner detail page is displayed with the correct data. Delivers a complete, usable owner record with no other stories required.

**Acceptance Scenarios**:

1. **Given** a receptionist is on the new owner form at `/owners/new`, **When** they submit first name, last name, a valid address (≤255 characters), a valid city (≤80 characters), and a 10-digit telephone number, **Then** the owner is persisted and the receptionist is redirected to the new owner's detail page showing all entered data.
2. **Given** a receptionist submits the new owner form with a telephone number that is not exactly 10 digits, **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the telephone field and no owner record is created.
3. **Given** a receptionist submits the new owner form with the address field exceeding 255 characters, **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the address field and no owner record is created.
4. **Given** a receptionist submits the new owner form with the city field exceeding 80 characters, **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the city field and no owner record is created.
5. **Given** a receptionist submits the new owner form with any mandatory field left blank, **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on each blank field and no owner record is created.

---

### User Story 2 - Search for an Existing Owner (Priority: P1)

A clinic receptionist searches for an owner by last name to locate their record before a visit or to update their details. The system returns a paginated list of matching owners or redirects directly to the owner detail page when exactly one match is found.

**Why this priority**: Owner lookup is required before any pet or visit operation can proceed. Without reliable search, staff cannot locate existing records and would be forced to create duplicates, corrupting clinic data.

**Independent Test**: Can be fully tested by navigating to `/owners`, entering a partial or full last name, and verifying the results list or direct redirect. Delivers immediate value as a standalone lookup tool.

**Acceptance Scenarios**:

1. **Given** one or more owners exist with a matching last name, **When** a receptionist searches by that last name, **Then** a paginated list of matching owners is displayed showing each owner's name, address, city, and telephone number.
2. **Given** exactly one owner matches the search term, **When** the search is submitted, **Then** the receptionist is redirected directly to that owner's detail page without an intermediate list.
3. **Given** no owners match the search term, **When** the search is submitted, **Then** the results page is displayed with an empty list and an appropriate message indicating no owners were found.
4. **Given** a receptionist submits the search form with no last name entered (blank), **When** the search is submitted, **Then** all owners are returned in a paginated list.
5. **Given** a receptionist enters a last name with leading or trailing whitespace, **When** the search is submitted, **Then** the whitespace is stripped and results are returned as if the trimmed value had been entered.

---

### User Story 3 - View Owner Details (Priority: P1)

A clinic receptionist views the full detail page for a specific owner, including their contact information and the list of their registered pets with each pet's type, birth date, and visit history.

**Why this priority**: The owner detail page is the central hub from which all pet and visit management actions are initiated. It must be reliable and complete before pet registration or visit scheduling can be used effectively.

**Independent Test**: Can be fully tested by navigating to `/owners/{id}` for an existing owner and verifying all owner fields and associated pets are displayed correctly. Delivers a complete read-only view of the owner record.

**Acceptance Scenarios**:

1. **Given** an owner exists with one or more registered pets, **When** a receptionist navigates to that owner's detail page, **Then** the page displays the owner's name, address, city, telephone number, and a list of all pets ordered by name, each showing pet type, birth date, and visit history.
2. **Given** an owner exists with no registered pets, **When** a receptionist navigates to that owner's detail page, **Then** the page displays the owner's contact information and an empty pets section.
3. **Given** a receptionist navigates to `/owners/{id}` with an ID that does not correspond to any owner, **When** the page is requested, **Then** an appropriate error response is returned indicating the owner was not found.

---

### User Story 4 - Update an Existing Owner's Information (Priority: P2)

A clinic receptionist updates the contact details of an existing owner — for example, correcting a telephone number or updating an address after a move — using the owner edit form.

**Why this priority**: Owner contact information changes over time. Without an update capability, records become stale and the clinic cannot reliably contact owners. This is important but depends on owner registration (P1) being in place first.

**Independent Test**: Can be fully tested by navigating to `/owners/{id}/edit` for an existing owner, modifying one or more fields, submitting the form, and verifying the detail page reflects the updated values.

**Acceptance Scenarios**:

1. **Given** an existing owner record, **When** a receptionist submits the edit form with valid updated values for address, city, or telephone, **Then** the changes are persisted and the receptionist is redirected to the owner's detail page showing the updated information.
2. **Given** a receptionist submits the edit form with an invalid telephone number (not exactly 10 digits), **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the telephone field and the original record is unchanged.
3. **Given** a receptionist submits the edit form with an address exceeding 255 characters, **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the address field and the original record is unchanged.
4. **Given** a receptionist attempts to manipulate the owner ID via the form submission, **When** the form is submitted, **Then** the ID field is ignored and the update is applied only to the owner identified by the URL path variable.

---

### User Story 5 - Add an Optional Email Address to an Owner Record (Priority: P2)

A clinic receptionist optionally records an email address for an owner when creating or updating their record, enabling the clinic to contact owners by email in addition to telephone.

**Why this priority**: Email is a common and expected contact channel. Making it optional ensures backward compatibility with existing records while enabling richer communication options. Depends on owner registration and update (P1, P2) being in place.

**Independent Test**: Can be fully tested by submitting the owner create or edit form with a valid email address and verifying it is displayed on the owner detail page, then submitting with an invalid email and verifying the field-level error appears.

**Acceptance Scenarios**:

1. **Given** a receptionist is on the owner create or edit form, **When** they submit a valid email address of at most 255 characters, **Then** the email is persisted and displayed on the owner detail page.
2. **Given** a receptionist submits the owner form with an email address that is not in a valid email format, **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the email field and no change is persisted.
3. **Given** a receptionist submits the owner form with an email address exceeding 255 characters, **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the email field.
4. **Given** a receptionist submits the owner form without entering an email address, **When** the form is submitted, **Then** the owner record is created or updated successfully with no email stored, and no validation error is shown for the email field.
5. **Given** existing owner sample data that does not include email addresses, **When** the application starts on any supported database profile (H2, MySQL, PostgreSQL), **Then** the sample data loads without error and existing owner records are displayed correctly without an email value.

---

### User Story 6 - Prevent Duplicate Visit Bookings for the Same Pet on the Same Date (Priority: P2)

A clinic receptionist attempts to schedule a second visit for a pet on a date that already has a visit booked for that pet. The system rejects the duplicate booking while still allowing a different pet belonging to the same owner to be booked on that same date.

**Why this priority**: Duplicate visit bookings create scheduling conflicts and corrupt visit history. This rule protects data integrity for the visit record, which is append-only and must not contain conflicting entries for the same pet on the same day.

**Independent Test**: Can be fully tested by booking a visit for a pet on a future date, then attempting to book a second visit for the same pet on the same date and verifying the rejection, then booking a different pet on that same date and verifying success.

**Acceptance Scenarios**:

1. **Given** a pet already has a visit booked for a specific future date, **When** a receptionist submits a new visit form for the same pet on that same date, **Then** the form is re-displayed with a validation error on the date field and no second visit record is created.
2. **Given** a pet already has a visit booked for a specific future date, **When** a receptionist submits a new visit form for a different pet belonging to the same owner on that same date, **Then** the visit is accepted and persisted successfully.
3. **Given** a receptionist submits a visit form with a date equal to today or in the past, **When** the form is submitted, **Then** the form is re-displayed with a validation error on the date field regardless of whether a visit already exists for that date.
4. **Given** a pet has no existing visits, **When** a receptionist submits a visit form with a valid future date, **Then** the visit is accepted and persisted successfully.

---

### Edge Cases

- What happens when an owner search returns more than one page of results and the receptionist navigates to a subsequent page?
- How does the system handle concurrent submissions of the owner registration form for the same person (potential duplicate owner records)?
- What happens when a pet's visit history is very long — does the owner detail page remain usable and performant?
- How does the system behave when the `ownerId` path variable in a URL is non-numeric or malformed?
- What happens when an owner has the maximum number of pets and a new pet registration is attempted?
- How does the email field behave when the database schema has not yet been migrated to include the email column (e.g., on a fresh MySQL or PostgreSQL deployment)?
- What happens when two receptionists simultaneously attempt to update the same owner record?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow clinic staff to register a new owner by providing first name, last name, address, city, and telephone number via a web form.
- **FR-002**: System MUST validate that the owner's address is not blank and does not exceed 255 characters, rejecting the form with a field-level error if violated.
- **FR-003**: System MUST validate that the owner's city is not blank and does not exceed 80 characters, rejecting the form with a field-level error if violated.
- **FR-004**: System MUST validate that the owner's telephone number is not blank and consists of exactly 10 digits, rejecting the form with a field-level error if the format is not met.
- **FR-005**: System MUST allow clinic staff to search for owners by last name, returning a paginated list of matches; a blank search MUST return all owners.
- **FR-006**: System MUST redirect directly to the owner detail page when a last name search yields exactly one matching owner.
- **FR-007**: System MUST strip leading and trailing whitespace from the last name search input before executing the query.
- **FR-008**: System MUST display an owner's full contact information (name, address, city, telephone) and their complete list of registered pets — ordered by pet name — on the owner detail page.
- **FR-009**: System MUST allow clinic staff to update an existing owner's address, city, telephone, and email via an edit form, with the same validation rules applied as on the registration form.
- **FR-010**: System MUST prevent client-side manipulation of owner ID values by disallowing the `id` field and any nested `*.id` fields from web form binding.
- **FR-011**: System MUST support an optional email address field on the owner record, validated as a properly formatted email address not exceeding 255 characters; the field MUST be optional (no error when left blank).
- **FR-012**: System MUST persist owner email address data correctly across all supported database profiles (H2, MySQL, PostgreSQL) without breaking existing sample data loads.
- **FR-013**: System MUST prevent scheduling more than one visit for the same pet on the same calendar date, returning a field-level validation error on the date field when a duplicate is detected.
- **FR-014**: System MUST enforce that all visit dates are at least one calendar day in the future, rejecting same-day or past-date submissions with a field-level validation error.
- **FR-015**: System MUST expose all owner-facing form labels and validation error messages through all supported internationalisation message bundles so that every locale displays consistent, translated text.
- **FR-016**: System MUST return an appropriate error response when an owner is looked up by an ID that does not exist in the database.

### Key Entities

- **Owner**: A registered pet owner and clinic customer. Key attributes: first name, last name, address (≤255 chars), city (≤80 chars), telephone (exactly 10 digits), optional email (≤255 chars, valid format). Owns zero or more Pets.
- **Pet**: An animal registered under exactly one Owner. Key attributes: name (≤30 chars, required), birth date (required), pet type (required for new pets). Belongs to exactly one Owner. Has an append-only list of Visits.
- **Visit**: A scheduled veterinary appointment for a Pet. Key attributes: date (future date, at least tomorrow), description (≤255 chars, required). Associated with exactly one Pet. Immutable once created.
- **PetType**: A classification category for a Pet (e.g., dog, cat, bird). Required at Pet registration. Selected from a predefined list maintained by the clinic.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Clinic staff can complete new owner registration — from opening the form to seeing the owner detail page — in under 2 minutes under normal operating conditions.
- **SC-002**: Owner search by last name returns results in under 1 second for a database containing up to 10,000 owner records.
- **SC-003**: 100% of owner form submissions with invalid data are rejected with a visible, field-specific error message; no invalid owner record is ever persisted.
- **SC-004**: 100% of duplicate visit booking attempts (same pet, same date) are rejected with a field-level error; no duplicate visit record is ever persisted.
- **SC-005**: All owner-facing validation messages and form labels are present and correctly translated in every supported locale; the internationalisation sync test passes with zero failures.
- **SC-006**: Owner records created or updated with an email address are retrievable and display the email correctly across all three supported database profiles (H2, MySQL, PostgreSQL) without data loss or startup errors.
- **SC-007**: Existing sample data continues to load without error on all supported database profiles after the email field is introduced, with no disruption to existing owner records.
- **SC-008**: The owner detail page correctly displays all registered pets and their visit histories for owners with up to 50 pets, each with up to 100 visits, without visible performance degradation.

## Assumptions

- Clinic staff (receptionists) are the primary users of owner management screens; there is no self-service owner registration portal for pet owners themselves in this scope.
- The email address field is a new addition to the Owner entity and requires a schema migration for MySQL and PostgreSQL profiles; H2 will reflect the change automatically via DDL generation.
- Telephone number format is fixed at exactly 10 digits for all owners regardless of country; international telephone formats are out of scope.
- The duplicate visit detection check applies per pet per calendar date; time-of-day scheduling within a single date is out of scope.
- Pagination page size for owner search results follows the existing application default and is not configurable by the user in this feature.
- The owner list display on search results shows name, address, city, and telephone; email is shown only on the owner detail page.
- No authentication or role-based access control changes are required; all clinic staff have equal access to owner management screens.
- Visit records are append-only and cannot be deleted or edited once created; this constraint is pre-existing and is not modified by this feature.
- The internationalisation requirement covers all language bundles already present in the repository; no new locales are added as part of this feature.
- Multi-location or multi-clinic support is explicitly out of scope per the project constitution.