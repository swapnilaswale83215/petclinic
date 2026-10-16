# Feature Specification: Owners Management

**Feature Branch**: `005-owners-petclinic`

**Created**: 2026-10-16

**Status**: Draft

**Input**: User description: "Owners for petclinic"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Register a New Owner (Priority: P1)

A clinic receptionist registers a new pet owner in the system by providing their full name, address, city, and telephone number. The owner record is saved and the receptionist is redirected to the owner's detail page.

**Why this priority**: Owner registration is the foundational operation — no pets or visits can exist without a registered owner. All other owner-related workflows depend on this story being functional.

**Independent Test**: Can be fully tested by navigating to `/owners/new`, submitting a valid owner form, and verifying the owner detail page is displayed with the saved data. Delivers a complete, usable owner record.

**Acceptance Scenarios**:

1. **Given** a receptionist is on the new owner form at `/owners/new`, **When** they submit valid values for first name, last name, address, city, and a 10-digit telephone number, **Then** the owner is persisted and the receptionist is redirected to the new owner's detail page showing all submitted data.
2. **Given** a receptionist submits the new owner form with a telephone number that is not exactly 10 digits, **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the `telephone` field and no owner record is created.
3. **Given** a receptionist submits the new owner form with a blank address, **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the `address` field and no owner record is created.
4. **Given** a receptionist submits the new owner form with an address exceeding 255 characters, **When** the form is submitted, **Then** the form returns HTTP 200 with the `owners/createOrUpdateOwnerForm` view, a field error with code `Size` is present on the `address` field, and no owner record is persisted.
5. **Given** a receptionist submits the new owner form with a blank city, **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the `city` field and no owner record is created.
6. **Given** a receptionist submits the new owner form with a city exceeding 80 characters, **When** the form is submitted, **Then** the form is re-displayed with a field-level validation error on the `city` field and no owner record is created.

---

### User Story 2 - Search for an Existing Owner (Priority: P1)

A clinic receptionist searches for an existing owner by last name to locate their record before adding a pet or scheduling a visit. The system returns a paginated list of matching owners or navigates directly to the owner's detail page if only one match is found.

**Why this priority**: Owner lookup is required before any pet or visit workflow can proceed. Without reliable search, staff cannot access existing records, making the system unusable for day-to-day operations.

**Independent Test**: Can be fully tested by navigating to `/owners`, entering a partial or full last name, and verifying the results list or direct redirect. Delivers immediate value as a standalone lookup tool.

**Acceptance Scenarios**:

1. **Given** one or more owners with the last name "Davis" exist in the system, **When** a receptionist searches for "Davis", **Then** a paginated list of all matching owners is displayed with their name, address, city, and telephone number.
2. **Given** exactly one owner matches the search term, **When** the receptionist submits the search, **Then** the system redirects directly to that owner's detail page.
3. **Given** no owners match the search term, **When** the receptionist submits the search, **Then** an empty results page is displayed with a message indicating no owners were found.
4. **Given** more owners match the search term than fit on one page, **When** the results are displayed, **Then** pagination controls are shown and the receptionist can navigate between pages.
5. **Given** a receptionist submits the search form with an empty last name field, **When** the form is submitted, **Then** all owners are returned in a paginated list.

---

### User Story 3 - Update an Existing Owner's Details (Priority: P2)

A clinic receptionist updates the contact details of an existing owner — for example, correcting a telephone number or updating an address after the owner moves.

**Why this priority**: Owner contact information changes over time. Keeping records accurate is important for clinic operations, but it is secondary to the ability to register and find owners.

**Independent Test**: Can be fully tested by navigating to an existing owner's detail page, clicking edit, submitting updated values, and verifying the detail page reflects the changes. Delivers standalone value as a data-correction workflow.

**Acceptance Scenarios**:

1. **Given** an existing owner record, **When** a receptionist submits the edit form with a new valid telephone number, **Then** the owner record is updated and the detail page reflects the new telephone number.
2. **Given** an existing owner record, **When** a receptionist submits the edit form with an invalid telephone number (not exactly 10 digits), **Then** the form is re-displayed with a field-level validation error on `telephone` and the original record is unchanged.
3. **Given** an existing owner record, **When** a receptionist submits the edit form with a blank address, **Then** the form is re-displayed with a field-level validation error on `address` and the original record is unchanged.
4. **Given** a form submission that includes a manually supplied owner ID in the request body, **When** the form is processed, **Then** the supplied ID is ignored and the owner ID is taken exclusively from the URL path variable.

---

### User Story 4 - Add an Optional Email Address to an Owner Record (Priority: P2)

A clinic receptionist optionally records an email address for an owner during registration or when updating an existing record, enabling the clinic to contact owners by email in addition to telephone.

**Why this priority**: Email is a common contact channel. The field is optional, so it does not block registration, but it adds meaningful value for clinics that communicate digitally. It is lower priority than core registration and search.

**Independent Test**: Can be fully tested by submitting the owner form with a valid email, an invalid email, and no email, then verifying the detail page and error states independently. Delivers standalone value as an enhanced contact record.

**Acceptance Scenarios**:

1. **Given** a receptionist is on the owner form, **When** they submit a valid email address of 255 characters or fewer, **Then** the email is accepted, persisted, and displayed on the owner detail page.
2. **Given** a receptionist is on the owner form, **When** they submit a malformed email address (e.g., missing `@` symbol), **Then** the form is re-displayed with a field-level validation error on the `email` field and no record is created or updated.
3. **Given** a receptionist is on the owner form, **When** they submit an email address exceeding 255 characters, **Then** the form is re-displayed with a field-level validation error on the `email` field.
4. **Given** a receptionist is on the owner form, **When** they leave the email field blank, **Then** the form is accepted without error and the owner detail page does not display an email section.
5. **Given** an owner record with a saved email address, **When** the owner detail page is rendered, **Then** the email address is displayed; if no email is present, the email section is hidden entirely.
6. **Given** the application is running against H2, MySQL, or PostgreSQL profiles, **When** an owner with a valid email is saved, **Then** the email is persisted and retrievable under all three profiles.

---

### User Story 5 - Prevent Duplicate Visit Bookings for the Same Pet on the Same Date (Priority: P2)

A clinic receptionist attempts to book a second visit for a pet on a date that already has a visit scheduled. The system rejects the duplicate booking and preserves the existing visit record.

**Why this priority**: Duplicate visit bookings create scheduling conflicts and corrupt visit history. Preventing them protects data integrity, but the feature is secondary to the core owner and pet registration flows.

**Independent Test**: Can be fully tested by booking a visit for a pet on a future date, then attempting to book a second visit for the same pet on the same date, and verifying the rejection. A different pet under the same owner can still book that date, confirming the rule is pet-scoped.

**Acceptance Scenarios**:

1. **Given** a pet already has a visit booked for a specific future date, **When** a second visit is submitted for the same pet on that same date, **Then** the form is rejected with a validation error on the `date` field and no duplicate visit record is created.
2. **Given** a pet already has a visit booked for a specific future date, **When** a visit is submitted for a different pet belonging to the same owner on that same date, **Then** the visit is accepted and persisted successfully.
3. **Given** a visit submission for a pet, **When** the submitted date is today or in the past, **Then** the form is rejected with a validation error on the `date` field regardless of duplicate status.
4. **Given** a pet has no existing visits, **When** a visit is submitted for a future date, **Then** the visit is accepted and persisted.

---

### Edge Cases

- What happens when an owner ID in the URL path does not correspond to any persisted owner record? The system throws an `IllegalArgumentException` and the operation is aborted; no partial data is written.
- What happens when a visit is submitted for a pet ID that does not belong to the owner identified in the URL path? The system throws an `IllegalArgumentException` and the visit is not created.
- What happens when a null pet is added to an owner's pet list programmatically? The `addPet` method returns immediately without modifying the list.
- What happens when a duplicate pet (same object reference or same non-null ID) is added to an owner's pet list? The `addPet` method silently discards the duplicate; the list is unchanged.
- What happens when a visit is submitted with a null `petId` or null `visit` object via `Owner.addVisit`? An `IllegalArgumentException` is thrown.
- What happens when the owner form is submitted with a city value exceeding 80 characters? A field-level validation error is returned on `city` and no record is persisted.
- What happens when a client attempts to supply or override entity IDs through the owner web form? The `id` field and all nested `*.id` fields are disallowed in form binding; supplied values are ignored.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow clinic staff to register a new owner by providing first name, last name, address, city, and telephone number through a web form.
- **FR-002**: System MUST validate that the owner's telephone number is exactly 10 digits; any other format MUST be rejected with a field-level error message sourced from the i18n message bundle.
- **FR-003**: System MUST validate that the owner's address is not blank and does not exceed 255 characters; violations MUST produce a field-level error and prevent persistence.
- **FR-004**: System MUST validate that the owner's city is not blank and does not exceed 80 characters; violations MUST produce a field-level error and prevent persistence.
- **FR-005**: System MUST allow clinic staff to search for owners by last name and display results in a paginated list; if exactly one owner matches, the system MUST redirect directly to that owner's detail page.
- **FR-006**: System MUST allow clinic staff to update an existing owner's contact details (address, city, telephone) through an edit form, subject to the same validation rules as registration.
- **FR-007**: System MUST support an optional email address field on the owner form; a present email MUST be validated as a properly formatted address of at most 255 characters, and an absent email MUST be accepted without error.
- **FR-008**: System MUST display the owner's email address on the owner detail page only when an email address is present on the record.
- **FR-009**: System MUST persist owner email address data correctly across all three supported database profiles: H2, MySQL, and PostgreSQL.
- **FR-010**: System MUST prevent a pet from being booked for more than one visit on the same date; a duplicate booking attempt MUST be rejected with a field-level validation error on the `date` field.
- **FR-011**: System MUST permit different pets belonging to the same owner to be booked for visits on the same date.
- **FR-012**: System MUST reject visit bookings where the submitted date is today or in the past; only future dates (tomorrow or later) are permitted.
- **FR-013**: System MUST disallow clients from supplying or overriding owner entity IDs or nested entity IDs through web form submissions.
- **FR-014**: System MUST expose all owner-facing labels and validation error messages — including the email field label and format error — in every supported i18n message bundle; the `I18nPropertiesSyncTest` MUST pass.
- **FR-015**: System MUST abort any operation that references a non-existent owner ID or a pet ID that does not belong to the resolved owner, returning an appropriate error response.

### Key Entities

- **Owner**: A registered pet owner and clinic customer. Key attributes: first name, last name, address (max 255 chars), city (max 80 chars), telephone (exactly 10 digits), email (optional, max 255 chars, valid format). Owns zero or more pets. Sensitive fields: name, address, telephone number.
- **Pet**: An animal registered under exactly one owner. Key attributes: name (not blank, max 30 chars), birth date (not null), pet type (required at registration). Has zero or more visit records.
- **Visit**: A scheduled veterinary appointment for a pet. Key attributes: date (future date, minimum tomorrow), description (not blank, max 255 chars). Immutable once created; visit history is append-only.
- **PetType**: A classification category for a pet (e.g., dog, cat, bird). Required at pet registration.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Clinic staff can complete new owner registration in under 2 minutes from opening the form to viewing the confirmed owner detail page.
- **SC-002**: Owner search returns matching results within 1 second for a dataset of up to 10,000 owner records.
- **SC-003**: 100% of owner form submissions with invalid telephone numbers, blank addresses, or blank cities are rejected with a visible field-level error message before any data is written.
- **SC-004**: 100% of duplicate visit booking attempts (same pet, same date) are rejected with a visible field-level error; no duplicate visit records appear in visit history.
- **SC-005**: Owner records with a valid email address are retrievable with the email intact across all three database profiles (H2, MySQL, PostgreSQL) with zero data loss.
- **SC-006**: All owner-facing validation messages and field labels are present and correctly translated in every supported locale; the i18n properties sync check passes on every build with zero missing keys.
- **SC-007**: No owner sensitive data (name, address, telephone number) appears in unprotected error pages, stack traces, actuator endpoint responses, or log output.
- **SC-008**: 95% of clinic staff successfully complete the owner registration and owner search workflows on first attempt without requiring help documentation.

## Assumptions

- The application is a modular monolith with server-side rendering via Thymeleaf; no REST API or single-page application frontend is introduced for this feature.
- Authentication and authorisation of clinic staff are handled by an existing mechanism outside the scope of this feature; the owner management screens are accessible to authenticated clinic staff only.
- The email address field is a new addition to the owner domain model and requires a database schema migration compatible with H2, MySQL, and PostgreSQL profiles.
- The existing `OwnerRepository`, `PetTypeRepository`, and Spring Data JPA infrastructure are reused without introducing new repository implementation classes.
- Pagination for owner search uses the existing `Page`/`Pageable` Spring Data infrastructure already present in `OwnerController`.
- The duplicate visit date validation is enforced at the domain or controller layer within the `owner` package, consistent with the existing `PetValidator` pattern, without introducing a separate validator hierarchy.
- Visit records are never deleted; the duplicate-date check applies only to future bookings and does not affect historical records.
- Mobile-specific UI optimisation is out of scope for this feature; the Thymeleaf templates are expected to be usable on desktop browsers.
- GraalVM Native Image hints in `PetClinicRuntimeHints` must be updated if any new reflection-dependent types are introduced by this feature.
- Sample data scripts (used by the H2 development profile) will be updated to include representative owner email addresses where appropriate, but this is a development convenience and does not affect production behaviour.