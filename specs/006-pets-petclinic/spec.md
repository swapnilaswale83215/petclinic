# Feature Specification: Pets Management for PetClinic

**Feature Branch**: `006-pets-petclinic`

**Created**: 2026-10-16

**Status**: Draft

**Input**: User description: "Pets for petclinic"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Register a New Pet for an Owner (Priority: P1)

A clinic receptionist registers a new pet under an existing owner's record. They provide the pet's name, birth date, and species type. The system validates the information and saves the pet, making it immediately visible on the owner's profile.

**Why this priority**: Pet registration is the foundational capability of the Pets module. Without it, no visits can be scheduled and no pet history can be maintained. All other pet-related stories depend on at least one pet existing.

**Independent Test**: Can be fully tested by navigating to an owner's profile, clicking "Add New Pet", submitting a valid form, and confirming the pet appears in the owner's pet list — delivering a complete, usable pet registration flow.

**Acceptance Scenarios**:

1. **Given** an owner exists in the system, **When** a receptionist submits a new pet form with a valid name (1–30 characters), a valid birth date (not in the future), and a selected pet type, **Then** the pet is saved and displayed in the owner's pet list.
2. **Given** an owner exists in the system, **When** a receptionist submits a new pet form with a blank name, **Then** the form is rejected with a validation error on the name field and no pet is created.
3. **Given** an owner exists in the system, **When** a receptionist submits a new pet form with a name exceeding 30 characters, **Then** the form is rejected with a validation error on the name field.
4. **Given** an owner exists in the system, **When** a receptionist submits a new pet form without selecting a pet type, **Then** the form is rejected with a validation error on the type field.
5. **Given** an owner exists in the system, **When** a receptionist submits a new pet form with a birth date set to tomorrow or any future date, **Then** the form is rejected with a validation error on the birth date field.
6. **Given** an owner already has a pet named "Buddy", **When** a receptionist attempts to register a second pet named "Buddy" under the same owner, **Then** the form is rejected with a duplicate name validation error and no second pet is created.
7. **Given** an owner already has a pet named "Buddy", **When** a different owner registers a pet also named "Buddy", **Then** the registration succeeds because name uniqueness is enforced per owner, not globally.

---

### User Story 2 - Edit an Existing Pet's Details (Priority: P2)

A clinic receptionist updates the details of an existing pet — correcting the name, adjusting the recorded birth date, or changing the pet type — without altering the pet's identity or visit history.

**Why this priority**: Pet records occasionally contain errors entered at registration. Providing an edit capability ensures data accuracy without requiring deletion and re-creation, which would destroy visit history.

**Independent Test**: Can be fully tested by opening an existing pet's edit form, modifying the name and birth date, saving, and confirming the updated values appear on the owner's profile while the pet's visit history remains intact.

**Acceptance Scenarios**:

1. **Given** a pet exists under an owner, **When** a receptionist updates the pet's name to a new valid name (1–30 characters, not already used by another pet of the same owner), **Then** the change is saved and the updated name is displayed on the owner's profile.
2. **Given** a pet exists under an owner, **When** a receptionist updates the pet's birth date to a valid past date, **Then** the change is saved and the updated birth date is displayed.
3. **Given** a pet exists under an owner with another pet named "Max", **When** a receptionist attempts to rename the first pet to "Max", **Then** the form is rejected with a duplicate name validation error.
4. **Given** a pet exists under an owner, **When** a receptionist attempts to change the pet's type to a valid type, **Then** the change is saved successfully.
5. **Given** a pet exists under an owner, **When** the edit form is submitted, **Then** the pet's id remains unchanged and the pet's visit history is preserved.

---

### User Story 3 - Schedule a Visit for a Pet (Priority: P2)

A clinic receptionist books a veterinary visit for a specific pet. They provide a visit date and a description of the reason for the visit. The visit is appended to the pet's history and is immediately visible on the owner's profile.

**Why this priority**: Visit scheduling is the primary operational activity of the clinic. Once pets are registered, the ability to record visits is the next most critical workflow.

**Independent Test**: Can be fully tested by navigating to a pet's visit booking form, submitting a valid future date and description, and confirming the visit appears in the pet's visit history on the owner's profile.

**Acceptance Scenarios**:

1. **Given** a pet exists under an owner, **When** a receptionist submits a visit form with a valid future date and a non-blank description (at most 255 characters), **Then** the visit is saved and appears in the pet's visit history ordered by date ascending.
2. **Given** a pet exists under an owner, **When** a receptionist submits a visit form with a blank description, **Then** the form is rejected with a validation error on the description field and no visit is created.
3. **Given** a pet exists under an owner, **When** a receptionist submits a visit form with a description exceeding 255 characters, **Then** the form is rejected with a validation error on the description field.
4. **Given** a pet already has a visit booked on a specific future date, **When** a receptionist attempts to book a second visit for the same pet on that same date, **Then** the form is rejected with a validation error on the date field and the pet's visit list remains unchanged.
5. **Given** pet A and pet B both belong to the same owner, and pet A has a visit on a given future date, **When** a receptionist books a visit for pet B on that same date, **Then** the booking succeeds because the duplicate-date constraint applies per pet, not per owner.
6. **Given** a pet exists under an owner, **When** a receptionist submits a visit form with today's date or a past date, **Then** the form is rejected with a validation error on the date field.
7. **Given** a visit has been saved for a pet, **When** any user views the pet's visit history, **Then** the visit record is present and cannot be deleted or modified.

---

### User Story 4 - View a Pet's Visit History (Priority: P3)

A clinic receptionist or veterinarian views the complete, chronologically ordered visit history for a specific pet from the owner's profile page.

**Why this priority**: Viewing visit history is a read-only capability that depends on visits already existing. It is essential for clinical continuity but does not block the core registration and scheduling flows.

**Independent Test**: Can be fully tested by navigating to an owner's profile, locating a pet with existing visits, and confirming all visits are listed in ascending date order with their descriptions visible.

**Acceptance Scenarios**:

1. **Given** a pet has multiple visits recorded on different dates, **When** a receptionist views the owner's profile, **Then** all visits for that pet are displayed in ascending date order.
2. **Given** a pet has no visits recorded, **When** a receptionist views the owner's profile, **Then** the pet's visit section is displayed as empty with no errors.
3. **Given** a pet has visits recorded, **When** a receptionist views the owner's profile, **Then** each visit shows its date and description.

---

### Edge Cases

- What happens when a pet form is submitted with a birth date exactly equal to today's date? The system must reject it — birth dates must be strictly in the past.
- What happens when a visit form is submitted without a date? The system must default the date to tomorrow and allow the receptionist to change it before submitting.
- What happens when an owner is not found when attempting to add or edit a pet? The system must return an appropriate error response and not create a partial pet record.
- What happens when a pet id referenced in a visit booking does not belong to the resolved owner? The system must reject the request with an error rather than associating the visit with an invalid pet.
- What happens when two receptionists simultaneously attempt to register pets with the same name under the same owner? The system must enforce uniqueness and reject the duplicate, even under concurrent submission.
- What happens when a pet type list is empty (no types configured in the system)? The new pet form must still render, but submission without a type must be rejected.
- What happens when a visit description is exactly 255 characters? The system must accept it as valid.
- What happens when a visit description is 256 characters? The system must reject it with a validation error.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow a receptionist to register a new pet under an existing owner by providing a name, birth date, and pet type.
- **FR-002**: System MUST reject a pet name that is blank or exceeds 30 characters, returning a field-level validation error.
- **FR-003**: System MUST require a pet type to be selected when creating a new pet, rejecting submission if no type is chosen.
- **FR-004**: System MUST reject a pet birth date that is null or set to today's date or any future date, returning a field-level validation error.
- **FR-005**: System MUST enforce pet name uniqueness within the same owner's pet list on both creation and update, rejecting duplicate names with a field-level validation error.
- **FR-006**: System MUST allow a receptionist to edit an existing pet's name, birth date, and type, while preserving the pet's identity and visit history.
- **FR-007**: System MUST prevent modification of a pet's identity (id) through the edit form.
- **FR-008**: System MUST allow a receptionist to schedule a new visit for a pet by providing a visit date and a description.
- **FR-009**: System MUST default the visit date to the next calendar day when the visit booking form is first displayed.
- **FR-010**: System MUST reject a visit with a blank description or a description exceeding 255 characters, returning a field-level validation error.
- **FR-011**: System MUST reject a visit date that is today's date or any past date, returning a field-level validation error.
- **FR-012**: System MUST reject a second visit booking for the same pet on the same date, returning a field-level validation error on the date field.
- **FR-013**: System MUST permit different pets owned by the same owner to have visits booked on the same date without conflict.
- **FR-014**: System MUST display a pet's visit history in ascending date order on the owner's profile page.
- **FR-015**: System MUST treat visit records as append-only; once a visit is saved it MUST NOT be deletable or editable through any user-facing interface.
- **FR-016**: System MUST associate every pet with exactly one owner; pet creation and editing MUST be performed in the context of a valid, persisted owner.
- **FR-017**: System MUST associate every visit with exactly one valid pet belonging to the resolved owner; a visit booking referencing an invalid pet id MUST be rejected.
- **FR-018**: System MUST present all available pet types as selectable options on the pet registration and edit forms.

### Key Entities

- **Pet**: Represents an animal registered at the clinic under a single owner. Key attributes: name (unique per owner, 1–30 characters), birth date (past date only), pet type. Belongs to exactly one Owner; has an ordered collection of Visits.
- **PetType**: Represents the species or category classification of a pet (e.g., dog, cat, bird, hamster). Referenced by Pet at registration and on edit. Managed separately from the pet registration flow.
- **Visit**: Represents a single veterinary appointment recorded for a pet. Key attributes: visit date (future only, defaults to tomorrow), description (non-blank, at most 255 characters). Belongs to exactly one Pet. Immutable once created.
- **Owner**: The registered guardian of one or more pets. Pet management operations are always scoped to a specific, persisted Owner.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A receptionist can complete new pet registration — from opening the form to seeing the pet on the owner's profile — in under 2 minutes under normal clinic conditions.
- **SC-002**: A receptionist can book a visit for an existing pet — from opening the visit form to seeing the visit in the pet's history — in under 90 seconds under normal clinic conditions.
- **SC-003**: All validation errors (blank name, future birth date, duplicate pet name, duplicate visit date, blank visit description) are surfaced to the user on the same form page without data loss, so the receptionist can correct and resubmit without re-entering unaffected fields.
- **SC-004**: 100% of submitted pet and visit records that pass validation are persisted and immediately visible on the owner's profile without requiring a manual page refresh.
- **SC-005**: Duplicate pet name and duplicate visit date constraints are enforced in 100% of cases, including concurrent submissions by multiple receptionists.
- **SC-006**: Visit history for any pet is displayed in correct ascending date order in 100% of retrievals.
- **SC-007**: No visit record created through the booking form can be deleted or modified through any user-facing interface, verified across all supported database profiles.
- **SC-008**: All pet and visit management screens render correctly and all validation messages are fully translated for every supported locale, with zero untranslated strings present on any form.

## Assumptions

- The clinic operates with a single location; multi-clinic or multi-location scenarios are out of scope per the project constitution.
- Pet type reference data (e.g., dog, cat, bird, hamster) is pre-populated in the system by an administrator and is not managed through the pet registration flow.
- The receptionist role is the primary actor for pet registration, editing, and visit scheduling; no self-service owner portal is in scope for this feature.
- Mobile-specific layout optimisation is not in scope for this feature; the existing responsive Thymeleaf templates are assumed to be sufficient.
- Authentication and authorisation for the receptionist role are handled by the existing application security configuration and are not introduced by this feature.
- All user-facing strings introduced by this feature will be externalised to i18n properties files and translated for all currently supported locales before the feature is considered complete, in compliance with the project constitution.
- The H2 in-memory profile is used for development and unit testing only; MySQL and PostgreSQL profiles are the target for integration validation.
- Billing, invoicing, and payment processing related to visits are explicitly out of scope per the project constitution.
- Visit assignment to a specific veterinarian is not in scope for this feature iteration; the Visit entity's veterinarian association, if present, is managed separately.
- The existing `OwnersRepository`, `PetTypeRepository`, and Spring Data JPA infrastructure are reused without introducing new repository implementation classes.