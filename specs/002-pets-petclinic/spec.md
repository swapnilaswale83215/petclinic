# Feature Specification: Pets Management for PetClinic

**Feature Branch**: `002-pets-petclinic`

**Created**: 2025-01-31

**Status**: Draft

**Input**: User description: "Pets for petclinic"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Register a New Pet for an Owner (Priority: P1)

A clinic receptionist adds a new pet to an existing owner's record. They provide the pet's name, birth date, and select a pet type from the available list. The system validates the input and saves the pet under the owner.

**Why this priority**: Pet registration is the foundational capability — without it, no visit history, no visit scheduling, and no veterinary care tracking is possible. All other pet-related workflows depend on this story being complete.

**Independent Test**: Can be fully tested by navigating to an existing owner's detail page, clicking "Add New Pet", submitting a valid name, birth date, and pet type, and confirming the pet appears in the owner's pet list.

**Acceptance Scenarios**:

1. **Given** an existing owner with no pets, **When** the receptionist submits a new pet with a valid name (≤30 characters), a past birth date, and a selected pet type, **Then** the pet is saved and appears in the owner's pet list.
2. **Given** an existing owner, **When** the receptionist submits a pet with a blank name, **Then** the form is rejected with a validation error on the name field and no pet is created.
3. **Given** an existing owner, **When** the receptionist submits a pet with a name longer than 30 characters, **Then** the form is rejected with a validation error on the name field.
4. **Given** an existing owner, **When** the receptionist submits a pet without selecting a pet type, **Then** the form is rejected with a validation error on the type field.
5. **Given** an existing owner, **When** the receptionist submits a pet with a birth date set to a future date, **Then** the form is rejected with a validation error on the birth date field.
6. **Given** an existing owner, **When** the receptionist submits a pet with a null birth date, **Then** the form is rejected with a validation error on the birth date field.
7. **Given** an existing owner who already has a pet named "Buddy", **When** the receptionist submits a new pet also named "Buddy" for the same owner, **Then** the form is rejected with a duplicate name validation error and no second pet is created.
8. **Given** two different owners, **When** each owner has a pet with the same name, **Then** both pets are accepted and saved without conflict.

---

### User Story 2 - Update an Existing Pet's Details (Priority: P2)

A clinic receptionist corrects or updates the details of a pet already registered under an owner — for example, correcting a birth date or renaming a pet.

**Why this priority**: Pet records need to remain accurate over time. Incorrect birth dates or names affect visit history readability and clinical records. This story is the second most critical because it maintains data integrity for existing records.

**Independent Test**: Can be fully tested by navigating to an existing pet's edit form, changing the name or birth date to a valid value, submitting, and confirming the updated values appear on the owner's detail page.

**Acceptance Scenarios**:

1. **Given** an existing pet with a valid name and birth date, **When** the receptionist updates the name to a different valid name (≤30 characters, not a duplicate for that owner), **Then** the pet record is updated and the new name is displayed.
2. **Given** an existing pet, **When** the receptionist updates the birth date to a valid past date, **Then** the pet record is updated with the new birth date.
3. **Given** an existing owner with pets "Buddy" and "Max", **When** the receptionist attempts to rename "Max" to "Buddy", **Then** the form is rejected with a duplicate name validation error and the pet name remains "Max".
4. **Given** an existing pet, **When** a database-level unique constraint violation occurs on the owner-pet name combination during save, **Then** the error is surfaced as a duplicate name field error rather than an unhandled system error.
5. **Given** an existing pet, **When** the receptionist submits the update form with a blank name, **Then** the form is rejected with a validation error on the name field.

---

### User Story 3 - Schedule a Visit for a Pet (Priority: P3)

A clinic receptionist books a new veterinary visit for a registered pet by providing a future date and a description of the reason for the visit.

**Why this priority**: Visit scheduling is the primary clinical workflow enabled by pet registration. It is prioritised after registration and update because it depends on a pet already existing in the system.

**Independent Test**: Can be fully tested by navigating to an existing pet's visit booking form, submitting a future date and a non-blank description, and confirming the visit appears in the pet's visit history.

**Acceptance Scenarios**:

1. **Given** an existing pet with no visits, **When** the receptionist submits a visit with a future date and a valid description (≤255 characters), **Then** the visit is saved and appears in the pet's visit history ordered by date ascending.
2. **Given** an existing pet with a visit on date A, **When** the receptionist submits a new visit on a different future date B, **Then** both visits are saved and the pet has two distinct visit records.
3. **Given** an existing pet with a visit already booked on future date A, **When** the receptionist submits a second visit for the same pet on the same date A, **Then** the form is rejected with a validation error on the date field and the pet's visit count remains unchanged.
4. **Given** an existing pet, **When** the receptionist submits a visit with today's date or a past date, **Then** the form is rejected with a validation error on the date field and no visit is persisted.
5. **Given** an existing pet, **When** the receptionist submits a visit with a blank description, **Then** the form is rejected with a validation error on the description field.
6. **Given** an existing pet, **When** the receptionist submits a visit with a description exceeding 255 characters, **Then** the form is rejected with a validation error on the description field.

---

### User Story 4 - View a Pet's Visit History (Priority: P4)

A clinic receptionist or veterinarian views the complete, chronologically ordered visit history for a specific pet from the owner's detail page.

**Why this priority**: Visit history is read-only and informational. It delivers value only after visits have been recorded, making it lower priority than the write operations above.

**Independent Test**: Can be fully tested by navigating to an owner's detail page and confirming that all previously booked visits for each pet are listed in ascending date order.

**Acceptance Scenarios**:

1. **Given** a pet with three visits on different dates, **When** the receptionist views the owner's detail page, **Then** all three visits are displayed in ascending date order.
2. **Given** a pet with no visits, **When** the receptionist views the owner's detail page, **Then** the pet is displayed with an empty visit history and no error is shown.
3. **Given** a pet with visits, **When** the receptionist views the visit history, **Then** each visit shows its date and description.

---

### Edge Cases

- What happens when a pet's birth date is submitted as today's date? The system must reject it with a validation error — birth dates must be strictly in the past.
- What happens when two concurrent requests attempt to register pets with the same name under the same owner simultaneously? The database unique constraint on `unique_owner_pet_name` must catch the race condition and surface it as a duplicate name field error rather than an unhandled exception.
- What happens when a visit is submitted for a pet ID that does not belong to the specified owner? The system must reject the request — a pet can only be accessed through its owning owner aggregate.
- What happens when the pet type list is empty (no types configured in the system)? The new pet form should still render but submission without a type must be rejected with a validation error.
- What happens when a visit description is exactly 255 characters? It must be accepted. A description of 256 characters must be rejected.
- What happens when a pet name is exactly 30 characters? It must be accepted. A name of 31 characters must be rejected.
- What happens when a visit is submitted with a date far in the future (e.g., 10 years from now)? The system must accept it — no upper bound on future visit dates is defined.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow a receptionist to register a new pet under an existing owner by providing a name, birth date, and pet type.
- **FR-002**: System MUST reject a pet name that is blank or exceeds 30 characters, displaying a field-level validation error.
- **FR-003**: System MUST require a pet type selection when creating a new pet; submission without a type must be rejected with a field-level validation error.
- **FR-004**: System MUST reject a pet birth date that is null or set to today's date or any future date, displaying a field-level validation error.
- **FR-005**: System MUST enforce uniqueness of pet names within the same owner; duplicate names must be rejected on both create and update with a field-level validation error.
- **FR-006**: System MUST catch database-level unique constraint violations on the owner-pet name combination during update and surface them as a duplicate name field error rather than an unhandled system exception.
- **FR-007**: System MUST allow a receptionist to update an existing pet's name and birth date, subject to the same validation rules as creation.
- **FR-008**: System MUST prevent client-side tampering of the pet identifier during update by disallowing the `id` field from form binding.
- **FR-009**: System MUST allow a receptionist to schedule a new visit for a registered pet by providing a future date and a non-blank description of at most 255 characters.
- **FR-010**: System MUST reject a visit booking when the submitted date is today or in the past, displaying a field-level validation error on the date field.
- **FR-011**: System MUST reject a second visit booking for the same pet on the same date, displaying a field-level validation error on the date field and leaving the pet's visit count unchanged.
- **FR-012**: System MUST reject a visit description that is blank or exceeds 255 characters, displaying a field-level validation error.
- **FR-013**: System MUST display a pet's visit history in ascending date order on the owner's detail page.
- **FR-014**: System MUST ensure visit records are append-only; existing visit records MUST NOT be modified or deleted once created.
- **FR-015**: System MUST ensure every pet belongs to exactly one owner; pet creation and update operations MUST be performed through the owning owner's aggregate.
- **FR-016**: System MUST default a new visit's date to the next calendar day at the time the visit form is initialised.

### Key Entities

- **Pet**: A registered animal belonging to exactly one owner. Key attributes: name (required, ≤30 characters, unique per owner), birth date (required, must be in the past), pet type (required). Maintains an append-only ordered collection of visits.
- **PetType**: A classification category for a pet (e.g., dog, cat, bird, hamster). Key attributes: name. Referenced by Pet; managed separately by clinic administrators.
- **Visit**: A recorded veterinary appointment for a pet. Key attributes: date (required, must be in the future at time of booking, unique per pet), description (required, ≤255 characters). Immutable once created; always associated with exactly one pet.
- **Owner**: The registered guardian of one or more pets. Owns the pet aggregate; pet operations are performed through the owner context.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A receptionist can complete new pet registration (name, birth date, type selection, and save) in under 2 minutes from the owner's detail page.
- **SC-002**: All validation errors (blank name, future birth date, missing type, duplicate name) are surfaced to the user on the same form page without navigating away, with clear field-level messages.
- **SC-003**: A receptionist can book a new visit for a pet (date selection, description entry, and save) in under 90 seconds.
- **SC-004**: 100% of duplicate visit date submissions for the same pet are rejected before any data is persisted, with a visible error on the date field.
- **SC-005**: A pet's complete visit history is displayed in ascending date order with zero missing or out-of-order records across all supported database profiles (H2, MySQL, PostgreSQL).
- **SC-006**: Concurrent attempts to register two pets with the same name under the same owner result in exactly one pet being saved and the other receiving a user-friendly duplicate name error — no unhandled system exceptions are exposed to the user.
- **SC-007**: All pet and visit management operations function correctly and produce identical results across H2, MySQL, and PostgreSQL database profiles.

## Assumptions

- The list of available pet types (e.g., dog, cat, bird, hamster) is pre-configured in the system by clinic administrators and is not managed as part of this feature.
- Only clinic receptionists interact with pet registration and visit scheduling; no self-service owner portal is in scope for this feature.
- The application renders pet management forms via server-side Thymeleaf templates; no separate client-side or REST API interface for pet management is in scope.
- "Past date" for birth date validation means strictly before today's date; today's date is not a valid birth date.
- "Future date" for visit booking means strictly after today's date; today's date is not a valid visit date.
- No upper bound is placed on how far in the future a visit date may be scheduled.
- Visit records are immutable once saved; no edit or delete capability for visits is in scope for this feature.
- The owner must already exist in the system before a pet can be registered; owner creation is out of scope for this feature.
- Internationalisation of all new user-facing validation messages and form labels is required; all strings must be externalised to the appropriate `messages_*.properties` files for all supported languages.
- Performance targets follow standard web application expectations; no special high-throughput requirements apply to pet management operations beyond what the existing application infrastructure supports.