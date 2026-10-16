# Feature Specification: Pets Management for PetClinic

**Feature Branch**: `002-pets-petclinic`

**Created**: 2025-01-31

**Status**: Draft

**Input**: User description: "Pets for petclinic"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Register a New Pet for an Owner (Priority: P1)

A clinic receptionist or owner registers a new pet under an existing owner's record. They provide the pet's name, species/type, and date of birth. The system validates the information and saves the pet, making it immediately visible on the owner's profile.

**Why this priority**: Pet registration is the foundational capability of the module. Without it, no visits can be scheduled and no medical history can be tracked. All other pet-related stories depend on at least one pet existing.

**Independent Test**: Can be fully tested by navigating to an owner's detail page, clicking "Add New Pet", submitting a valid form, and verifying the pet appears in the owner's pet list. Delivers the core value of associating a pet with an owner.

**Acceptance Scenarios**:

1. **Given** an owner exists in the system, **When** a receptionist submits a new pet form with a valid name (≤30 characters), a selected pet type, and a past birth date, **Then** the pet is saved and displayed on the owner's detail page.
2. **Given** an owner exists in the system, **When** a receptionist submits a new pet form with a blank name, **Then** the form is rejected with a validation error on the name field and no pet is created.
3. **Given** an owner exists in the system, **When** a receptionist submits a new pet form with a name longer than 30 characters, **Then** the form is rejected with a validation error on the name field.
4. **Given** an owner exists in the system, **When** a receptionist submits a new pet form without selecting a pet type, **Then** the form is rejected with a validation error on the type field.
5. **Given** an owner exists in the system, **When** a receptionist submits a new pet form with a birth date set to today or a future date, **Then** the form is rejected with a validation error on the birth date field.
6. **Given** an owner already has a pet named "Buddy", **When** a receptionist attempts to register another pet named "Buddy" under the same owner, **Then** the form is rejected with a duplicate name validation error and the second pet is not created.
7. **Given** an owner exists in the system, **When** a receptionist submits a new pet form with a null birth date, **Then** the form is rejected with a validation error on the birth date field.

---

### User Story 2 - Update an Existing Pet's Details (Priority: P2)

A clinic receptionist updates the details of a pet already registered under an owner — for example, correcting the pet's name or updating its birth date after a data entry error.

**Why this priority**: Pet records need to remain accurate over time. Corrections to name or birth date are routine administrative tasks. This story is independent of visit scheduling and can be demonstrated without any visits existing.

**Independent Test**: Can be fully tested by navigating to an existing pet's edit form, modifying the name or birth date, submitting, and verifying the updated values appear on the owner's detail page.

**Acceptance Scenarios**:

1. **Given** a pet exists under an owner, **When** a receptionist updates the pet's name to a new valid name (≤30 characters, not a duplicate for that owner) and submits, **Then** the updated name is saved and displayed on the owner's detail page.
2. **Given** a pet exists under an owner, **When** a receptionist attempts to rename the pet to a name already used by another pet belonging to the same owner, **Then** the form is rejected with a duplicate name validation error and the original name is preserved.
3. **Given** a pet exists under an owner, **When** a receptionist updates the pet's birth date to a valid past date and submits, **Then** the updated birth date is saved.
4. **Given** a pet exists under an owner, **When** a receptionist attempts to update the pet's birth date to a future date, **Then** the form is rejected with a validation error on the birth date field.
5. **Given** a pet exists under an owner, **When** a receptionist submits an update with a blank name, **Then** the form is rejected with a validation error on the name field.
6. **Given** a pet update is submitted and a database-level duplicate name constraint violation occurs, **When** the system catches the constraint violation, **Then** the error is surfaced as a user-friendly duplicate name field error rather than an unhandled system error.

---

### User Story 3 - Schedule a Visit for a Pet (Priority: P2)

A clinic receptionist books a veterinary visit for a registered pet by providing a future date and a description of the reason for the visit. The visit is recorded against the pet's history.

**Why this priority**: Visit scheduling is the primary clinical workflow enabled by pet registration. It is independently testable once at least one pet exists and delivers direct business value to the clinic.

**Independent Test**: Can be fully tested by navigating to a pet's visit booking form, submitting a valid future date and description, and verifying the visit appears in the pet's visit history on the owner's detail page.

**Acceptance Scenarios**:

1. **Given** a pet exists under an owner, **When** a receptionist submits a visit form with a valid future date and a non-blank description (≤255 characters), **Then** the visit is saved and appears in the pet's visit history.
2. **Given** a pet exists under an owner, **When** a receptionist submits a visit form with a blank description, **Then** the form is rejected with a validation error on the description field and no visit is created.
3. **Given** a pet exists under an owner, **When** a receptionist submits a visit form with a description exceeding 255 characters, **Then** the form is rejected with a validation error on the description field.
4. **Given** a pet already has a visit booked for a specific future date, **When** a receptionist submits a second visit for the same pet on the same date, **Then** the form is rejected with a validation error on the date field and the pet's visit count remains unchanged.
5. **Given** a pet already has a visit booked for a specific future date, **When** a receptionist submits a new visit for the same pet on a different future date, **Then** the visit is saved successfully and the pet's visit count increases by one.
6. **Given** a pet exists with no existing visits, **When** a receptionist submits a visit form with today's date or a past date, **Then** the form is rejected with a validation error on the date field.
7. **Given** a visit form is opened, **When** the form loads, **Then** the date field defaults to tomorrow's date.

---

### User Story 4 - View a Pet's Visit History (Priority: P3)

A clinic receptionist or veterinarian views the complete visit history for a registered pet, presented in chronological order, to understand the pet's medical background before a consultation.

**Why this priority**: Viewing visit history is a read-only capability that supports clinical decision-making. It is lower priority than scheduling because it requires visits to already exist, but it is independently demonstrable once visits are present.

**Independent Test**: Can be fully tested by navigating to an owner's detail page and verifying that a pet's visits are listed in ascending date order.

**Acceptance Scenarios**:

1. **Given** a pet has multiple visits recorded on different dates, **When** a receptionist views the owner's detail page, **Then** the pet's visits are displayed in ascending date order (earliest first).
2. **Given** a pet has no visits recorded, **When** a receptionist views the owner's detail page, **Then** the pet's visit history section is empty with no errors.
3. **Given** a visit has been recorded, **When** a receptionist views the visit history, **Then** the visit record displays the date and description and cannot be deleted or modified.

---

### Edge Cases

- What happens when a pet name contains only whitespace characters? The system must treat this as a blank name and reject it with a validation error.
- What happens when two concurrent requests attempt to register pets with the same name under the same owner simultaneously? The database-level unique constraint on `unique_owner_pet_name` catches the race condition, and the system surfaces a user-friendly duplicate name error rather than an unhandled exception.
- What happens when a pet's birth date is submitted as a malformed string that cannot be parsed as a date? The system returns a type mismatch error on the birth date field and re-renders the form.
- What happens when a visit date is submitted as a malformed string? The system returns a `typeMismatch.visitDate` error on the date field and re-renders the `pets/createOrUpdateVisitForm` view.
- What happens when a pet ID is tampered with via the form submission on an update request? The `id` field is excluded from form binding, preventing client-side ID manipulation; the pet identity is resolved from the URL path and the owner's existing pet list.
- What happens when a visit description is exactly 255 characters? The visit is accepted and saved successfully.
- What happens when a visit description is 256 characters? The form is rejected with a validation error on the description field.
- What happens when an owner has no pets and a receptionist attempts to book a visit directly? The system requires a valid pet to exist under the owner before a visit can be created; the visit booking path is only accessible via a pet that already belongs to the owner.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow a receptionist to register a new pet under an existing owner by providing a name, pet type, and birth date.
- **FR-002**: System MUST reject a new pet registration if the name is blank or exceeds 30 characters.
- **FR-003**: System MUST reject a new pet registration if no pet type is selected.
- **FR-004**: System MUST reject a new pet registration if the birth date is null, today, or a future date.
- **FR-005**: System MUST reject a new or updated pet if its name duplicates an existing pet name belonging to the same owner, surfacing a user-friendly field-level error.
- **FR-006**: System MUST catch database-level unique constraint violations on pet name per owner during updates and surface them as duplicate name field errors rather than unhandled exceptions.
- **FR-007**: System MUST allow a receptionist to update an existing pet's name and birth date, subject to the same validation rules as registration.
- **FR-008**: System MUST prevent client-side tampering of the pet identifier during update operations by excluding the `id` field from form binding.
- **FR-009**: System MUST allow a receptionist to schedule a visit for a registered pet by providing a future date and a non-blank description of at most 255 characters.
- **FR-010**: System MUST reject a visit booking if the date is today or in the past, returning a field-level validation error on the date field.
- **FR-011**: System MUST reject a second visit booking for the same pet on the same date, returning a field-level validation error on the date field.
- **FR-012**: System MUST default the visit date field to tomorrow's date when the visit booking form is first loaded.
- **FR-013**: System MUST display a pet's visit history in ascending date order on the owner's detail page.
- **FR-014**: System MUST NOT allow visit records to be deleted or modified once created; visit history is append-only.
- **FR-015**: System MUST ensure every pet belongs to exactly one owner and can only be created or updated through that owner's record.
- **FR-016**: System MUST ensure every visit is associated with exactly one pet via the owning owner's aggregate.

### Key Entities

- **Pet**: Represents an animal registered at the clinic under a specific owner. Key attributes: name (unique per owner, ≤30 characters), birth date (past date), pet type. Belongs to exactly one owner. Has zero or many visits.
- **PetType**: Represents the species or category of a pet (e.g., dog, cat, bird, hamster). Required at pet registration. Managed as a reference list; not created or modified through this feature.
- **Visit**: Represents a scheduled or recorded veterinary appointment for a pet. Key attributes: date (future at time of booking), description (non-blank, ≤255 characters). Belongs to exactly one pet. Immutable once created.
- **Owner**: The registered guardian of one or more pets. Pets are always managed through the owner's record. Owner identity and validation are governed by the Owner Registration feature.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A receptionist can complete new pet registration from the owner's detail page in under 2 minutes for a straightforward case.
- **SC-002**: All validation errors (blank name, duplicate name, missing type, invalid birth date) are surfaced to the user on the same form page without data loss, requiring zero additional navigation steps to correct and resubmit.
- **SC-003**: A duplicate pet name under the same owner is rejected 100% of the time, including under concurrent submission conditions, with no unhandled exceptions reaching the user.
- **SC-004**: A visit booking for a duplicate date on the same pet is rejected 100% of the time with a clear field-level error, and the pet's visit count remains unchanged.
- **SC-005**: A pet's complete visit history is displayed in correct ascending date order on every page load with no missing or out-of-order records.
- **SC-006**: 95% of receptionists can successfully complete a pet registration and a visit booking on their first attempt without requiring support intervention.
- **SC-007**: All pet and visit management operations function correctly across all three supported database profiles (H2, MySQL, PostgreSQL) with no profile-specific data loss or constraint failures.

## Assumptions

- The list of available pet types (dog, cat, bird, hamster, etc.) is pre-populated in the system and managed separately; this feature does not include creating or editing pet types.
- Only clinic receptionists and authorised staff interact with pet registration and visit scheduling through the web UI; there is no self-service owner portal in scope.
- Mobile browser support follows the same responsive layout already established in the application; no native mobile application is in scope.
- The owner must already exist in the system before a pet can be registered; owner creation is handled by the Owner Registration feature and is a prerequisite.
- Visit history is read-only once recorded; there is no requirement to edit or cancel visits in this feature iteration.
- The application operates as a single-clinic installation; multi-location or multi-clinic scenarios are out of scope per the project constitution.
- All user-facing strings introduced by this feature will be externalised to message properties files and provided for all supported locales to satisfy the i18n sync requirement.
- GraalVM native image compatibility will be maintained; any new reflection-dependent types introduced will be registered in `PetClinicRuntimeHints`.
- Performance expectations align with standard web application norms for a single-clinic deployment; no high-concurrency or high-volume scaling requirements apply beyond what the existing infrastructure supports.