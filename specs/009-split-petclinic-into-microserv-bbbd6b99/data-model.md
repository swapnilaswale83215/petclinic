# Data Model: Split PetClinic into Microservices

**Feature**: 009-split-petclinic-into-microserv-bbbd6b99
**Date**: 2026-10-19
**Phase**: 1 — Design

---

## Overview

This document describes every entity the split touches, the table ownership boundary, field-level detail, relationships, validation rules, state transitions, and what changes against the current monolith model. It is organised by service boundary. Entities are not shared between services; each service owns its domain classes in full (FR-001, research item 3).

The monolith's domain model is unchanged in content. The split redistributes classes across two independent modules and enforces a hard ownership boundary at the database level. No field is added, removed, or renamed. No relationship is altered. No validation rule is weakened or strengthened (except the append-only constraint on Visit, which is already a rule in the constitution and is now enforced at the database-role level as well).

---

## Service Boundary Summary

| Table | Owning Service | Owning Module | Access After S5 |
|---|---|---|---|
| `vets` | Vets | `vets/` | Vets runtime role: SELECT only. Owners role: denied. |
| `specialties` | Vets | `vets/` | Vets runtime role: SELECT only. Owners role: denied. |
| `vet_specialties` | Vets | `vets/` | Vets runtime role: SELECT only. Owners role: denied. |
| `owners` | Owners | `owners/` | Owners runtime role: SELECT, INSERT, UPDATE. Vets role: denied. |
| `pets` | Owners | `owners/` | Owners runtime role: SELECT, INSERT, UPDATE. Vets role: denied. |
| `visits` | Owners | `owners/` | Owners runtime role: SELECT, INSERT. DELETE denied. Vets role: denied. |
| `types` | Owners | `owners/` | Owners runtime role: SELECT. Vets role: denied. |

No foreign key, view, or cross-service query exists between the Vets table set and the Owners table set (FR-018).

---

## Vets Service Entities

### Vet

**Java class**: `org.springframework.samples.petclinic.vet.Vet`
**Module**: `vets/`
**Table**: `vets`
**Role in service**: The central entity of the Vets service. Read-only from the application; no application writer exists. Loaded by `VetRepository.findAll`, cached under the `"vets"` JCache cache.

#### Fields

| Field | Column | Type | Constraints | Notes |
|---|---|---|---|---|
| `id` | `id` | `INT` | PK, auto-increment, NOT NULL | Inherited from `BaseEntity` |
| `firstName` | `first_name` | `VARCHAR(30)` | NOT NULL | `@NotBlank` (Jakarta Bean Validation) |
| `lastName` | `last_name` | `VARCHAR(30)` | NOT NULL | `@NotBlank` |
| `specialties` | — | `Set<Specialty>` | Mapped via `vet_specialties`; may be empty | `@ManyToMany(fetch = EAGER)` |

#### Relationships

- **Vet HAS Specialty** (many-to-many; optional — zero or many specialties per vet)
  - Join table: `vet_specialties` (`vet_id` FK → `vets.id`, `specialty_id` FK → `specialties.id`)
  - Fetch: EAGER (required for the cached `findAll` result to be fully populated before caching)
  - No cascade: specialties are reference data managed independently

#### Validation Rules

- `firstName`: `@NotBlank` — must not be null or blank
- `lastName`: `@NotBlank` — must not be null or blank
- Specialty list: no minimum cardinality; zero specialties is valid (constitution Section II)

#### State Transitions

None. Vet data is read-only from the application's perspective (FR-006). No create, update, or delete route exists in the Vets service. The migration job is the only writer during S5.

#### Cache Behaviour

- `VetRepository.findAll` is annotated `@Cacheable("vets")`
- Cache name: `"vets"`
- Backed by `CacheConfiguration` (JCache)
- Statistics enabled; queryable as `cache.gets` with tag `cache=vets` on the management port
- No eviction behaviour (FR-006 explicitly prohibits adding eviction)
- The Owners service has no cache named `"vets"` and no `CacheConfiguration` for vet data

#### Changes Against Current Model

None. `Vet.java` moves from `src/main/java/.../vet/` to `vets/src/main/java/.../vet/` with no change to its content.

---

### Specialty

**Java class**: `org.springframework.samples.petclinic.vet.Specialty`
**Module**: `vets/`
**Table**: `specialties`
**Role in service**: Reference data. A veterinarian's area of medical expertise. Loaded eagerly as part of `Vet`.

#### Fields

| Field | Column | Type | Constraints | Notes |
|---|---|---|---|---|
| `id` | `id` | `INT` | PK, auto-increment, NOT NULL | Inherited from `BaseEntity` |
| `name` | `name` | `VARCHAR(80)` | NOT NULL | `@NotBlank` |

#### Relationships

- **Specialty ASSIGNED_TO Vet** (many-to-many, inverse side; owned by `Vet`)
  - Join table: `vet_specialties`

#### Validation Rules

- `name`: `@NotBlank`

#### State Transitions

None. Reference data; no application writer.

#### Changes Against Current Model

None. `Specialty.java` moves to `vets/` module with no content change.

---

### VetRepository (interface)

**Java interface**: `org.springframework.samples.petclinic.vet.VetRepository`
**Module**: `vets/`
**Extends**: Spring Data `Repository<Vet, Integer>`

#### Methods

| Method | Annotation | Notes |
|---|---|---|
| `findAll()` | `@Cacheable("vets")` | Returns all vets with specialties eagerly loaded. Cache hit on second call. |

#### Changes Against Current Model

None. Interface moves to `vets/` module with no content change.

---

### Vets (XML/JSON wrapper)

**Java class**: `org.springframework.samples.petclinic.vet.Vets`
**Module**: `vets/`
**Role**: A wrapper list used for XML and JSON serialisation of the `GET /vets` response (FR-005).

#### Fields

| Field | Type | Notes |
|---|---|---|
| `vetList` | `List<Vet>` | `@XmlElement`; populated from `VetRepository.findAll()` |

#### Changes Against Current Model

None. `Vets.java` moves to `vets/` module with no content change. The JAXB/Jackson-dataformat-xml dependency is retained in the `vets/pom.xml` (FR-005).

---

### VetController

**Java class**: `org.springframework.samples.petclinic.vet.VetController`
**Module**: `vets/`

#### Routes Owned

| Method | Path | Response | Notes |
|---|---|---|---|
| GET | `/vets.html` | HTML (Thymeleaf) | Pagination: 5 per page. Out-of-range page → redirect to `/vets.html?page=1` (FR-004). |
| GET | `/vets` | JSON or XML | Content-Type determined by `Accept` header. Same status, field names, and values as monolith (FR-005). |

#### Changes Against Current Model

None. `VetController.java` moves to `vets/` module with no content change.

---

## Owners Service Entities

### Owner

**Java class**: `org.springframework.samples.petclinic.owner.Owner`
**Module**: `owners/`
**Table**: `owners`
**Role in service**: The root aggregate of the Owners service. Holds personal data (name, address, telephone). Owns one or more Pets.

#### Fields

| Field | Column | Type | Constraints | Notes |
|---|---|---|---|---|
| `id` | `id` | `INT` | PK, auto-increment, NOT NULL | Inherited from `BaseEntity` |
| `firstName` | `first_name` | `VARCHAR(30)` | NOT NULL | `@NotBlank` |
| `lastName` | `last_name` | `VARCHAR(30)` | NOT NULL | `@NotBlank` |
| `address` | `address` | `VARCHAR(255)` | NOT NULL | `@NotBlank` |
| `city` | `city` | `VARCHAR(80)` | NOT NULL | `@NotBlank` |
| `telephone` | `telephone` | `VARCHAR(20)` | NOT NULL | `@NotBlank`; regex `\d{10}` enforced by `@Pattern` |
| `pets` | — | `List<Pet>` | Mapped via `pets.owner_id`; may be empty | `@OneToMany(cascade = ALL, fetch = EAGER, mappedBy = "owner")` |

#### Sensitive Data Classification

`firstName`, `lastName`, `address`, `telephone` are designated sensitive fields (constitution Section III). They must not appear in logs, error pages, stack traces, actuator outputs, metric tags, or any Vets-side artefact (FR-022, SC-005).

#### Relationships

- **Owner OWNS Pet** (one-to-many; a Pet MUST belong to exactly one Owner)
  - Cascade: ALL
  - Fetch: EAGER
  - Mapped by: `Pet.owner`

#### Validation Rules

- `firstName`: `@NotBlank`
- `lastName`: `@NotBlank`
- `address`: `@NotBlank`
- `city`: `@NotBlank`
- `telephone`: `@NotBlank` + `@Pattern(regexp = "\\d{10}")` — exactly 10 digits; no other format accepted (FR-007)
- Pet list: no minimum cardinality at the Owner level; an Owner with zero pets is valid

#### State Transitions

```
[New] --register--> [Persisted]
[Persisted] --edit--> [Persisted]
```

No delete transition. No Owner delete route exists (FR-007 requires the same routes as the monolith; the monolith has no owner delete).

#### Changes Against Current Model

None. `Owner.java` moves to `owners/` module with no change to its content (FR-007). The telephone regex `\d{10}` and all `@NotBlank` rules are preserved verbatim.

---

### Pet

**Java class**: `org.springframework.samples.petclinic.owner.Pet`
**Module**: `owners/`
**Table**: `pets`
**Role in service**: A registered animal belonging to exactly one Owner. Has a PetType and an append-only visit history.

#### Fields

| Field | Column | Type | Constraints | Notes |
|---|---|---|---|---|
| `id` | `id` | `INT` | PK, auto-increment, NOT NULL | Inherited from `BaseEntity` |
| `name` | `name` | `VARCHAR(30)` | NOT NULL | Validated by `PetValidator` |
| `birthDate` | `birth_date` | `DATE` | nullable | |
| `type` | `type_id` | `INT` | NOT NULL, FK → `types.id` | `@ManyToOne(fetch = EAGER)` |
| `owner` | `owner_id` | `INT` | NOT NULL, FK → `owners.id` | `@ManyToOne` |
| `visits` | — | `List<Visit>` | Mapped via `visits.pet_id`; append-only | `@OneToMany(cascade = ALL, fetch = EAGER, mappedBy = "pet")` |

#### Unique Constraint

`UNIQUE (owner_id, name)` on the `pets` table. This constraint MUST exist on H2, MySQL, and PostgreSQL after every stage of the migration (FR-009).

#### Relationships

- **Pet BELONGS_TO Owner** (many-to-one; required — a Pet MUST belong to exactly one Owner)
- **Pet HAS PetType** (many-to-one; required at registration)
- **Pet HAS Visit** (one-to-many; append-only; cascade ALL)

#### Validation Rules

- `name`: validated by `PetValidator` — must not be blank; must be unique within the owner's existing pets (enforced by `PetValidator` at the application layer and by the `UNIQUE (owner_id, name)` constraint at the database layer)
- `type`: must not be null at registration (constitution Section II: "A Pet MUST have a valid PetType at registration")
- `owner`: must not be null (constitution Section II: "A Pet MUST always belong to exactly one Owner")
- `birthDate`: nullable; no format constraint beyond `DATE` type

#### State Transitions

```
[New] --register (with Owner, PetType)--> [Persisted]
[Persisted] --edit--> [Persisted]
```

No delete transition. No Pet delete route exists in the Owners service.

#### Changes Against Current Model

None. `Pet.java` moves to `owners/` module with no content change. The `UNIQUE (owner_id, name)` constraint is preserved at every migration stage (FR-009).

---

### PetType

**Java class**: `org.springframework.samples.petclinic.owner.PetType`
**Module**: `owners/`
**Table**: `types`
**Role in service**: Reference data. Species or category classification of a pet (e.g., dog, cat, bird, hamster). Required at Pet registration.

#### Fields

| Field | Column | Type | Constraints | Notes |
|---|---|---|---|---|
| `id` | `id` | `INT` | PK, auto-increment, NOT NULL | Inherited from `BaseEntity` |
| `name` | `name` | `VARCHAR(80)` | NOT NULL | `@NotBlank` |

#### Relationships

- **PetType CLASSIFIES Pet** (one-to-many, inverse side; owned by `Pet`)

#### Validation Rules

- `name`: `@NotBlank`

#### State Transitions

None. Reference data; managed outside the application (seed data).

#### Changes Against Current Model

None. `PetType.java` moves to `owners/` module with no content change.

---

### Visit

**Java class**: `org.springframework.samples.petclinic.owner.Visit`
**Module**: `owners/`
**Table**: `visits`
**Role in service**: A recorded veterinary appointment or encounter for a pet. Immutable once created; the visit history is append-only.

#### Fields

| Field | Column | Type | Constraints | Notes |
|---|---|---|---|---|
| `id` | `id` | `INT` | PK, auto-increment, NOT NULL | Inherited from `BaseEntity` |
| `date` | `visit_date` | `DATE` | NOT NULL; defaults to today | |
| `description` | `description` | `VARCHAR(255)` | NOT NULL | `@NotBlank` |
| `pet` | `pet_id` | `INT` | NOT NULL, FK → `pets.id` | `@ManyToOne` |

#### Relationships

- **Visit ASSOCIATED_WITH Pet** (many-to-one; required — a Visit MUST be associated with exactly one Pet)

#### Validation Rules

- `description`: `@NotBlank`
- `pet`: must not be null (constitution Section II: "A Visit MUST always be associated with exactly one Pet")
- `date`: defaults to the current date if not supplied; must be a valid `DATE`

#### Append-Only Constraint

Visit records MUST NOT be deleted once created (constitution Section II, FR-008). This is enforced at three levels:

1. **Application layer**: No delete route and no delete repository method for Visit exist in the Owners service (FR-008).
2. **Database role layer**: DELETE on `visits` is denied to the Owners runtime role (E5-S8). UPDATE is denied if the Testcontainers test in E5-S8 confirms it is not required by Hibernate's `@OneToMany` with `@JoinColumn` (NEEDS CLARIFICATION — research item 9a).
3. **Constitution layer**: The append-only rule is a MUST-level constraint in Section II.

#### State Transitions

```
[New] --create (with Pet, date, description)--> [Persisted]
```

No update or delete transition. Once persisted, a Visit record is immutable from the application's perspective.

#### Changes Against Current Model

None in content. `Visit.java` moves to `owners/` module with no content change. The append-only constraint is strengthened at the database-role level (new enforcement, not a content change).

**NEEDS CLARIFICATION (9a)**: Whether UPDATE on `visits` can be withheld from the Owners runtime role depends on the outcome of the Testcontainers test in E5-S8. Hibernate's unidirectional `@OneToMany` with `@JoinColumn` may issue an UPDATE to set the foreign key. This cannot be resolved without running the test against real PostgreSQL and MySQL under the restricted role.

---

### OwnerRepository (interface)

**Java interface**: `org.springframework.samples.petclinic.owner.OwnerRepository`
**Module**: `owners/`

#### Methods

| Method | Notes |
|---|---|
| `findByLastName(String lastName, Pageable pageable)` | Owner search by last name; returns a `Page<Owner>` |
| `findById(Integer id)` | Returns a single Owner with pets and visits eagerly loaded |
| `save(Owner owner)` | Persists a new or updated Owner (cascades to Pets and Visits) |

No delete method. No `deleteById` or `delete` method exists for Owner (FR-007).

#### Changes Against Current Model

None. Interface moves to `owners/` module with no content change.

---

### PetRepository (interface)

**Java interface**: `org.springframework.samples.petclinic.owner.PetRepository`
**Module**: `owners/`

#### Methods

| Method | Notes |
|---|---|
| `findPetTypes()` | Returns all PetType reference data |
| `findById(Integer id)` | Returns a single Pet |
| `save(Pet pet)` | Persists a new or updated Pet |

No delete method.

#### Changes Against Current Model

None. Interface moves to `owners/` module with no content change.

---

### VisitRepository (interface)

**Java interface**: `org.springframework.samples.petclinic.owner.VisitRepository`
**Module**: `owners/`

#### Methods

| Method | Notes |
|---|---|
| `save(Visit visit)` | Persists a new Visit (append-only) |

**Explicitly absent**: No `delete`, `deleteById`, or any removal method (FR-008). This is a hard constraint; any pull request adding a delete method to this interface MUST be rejected.

#### Changes Against Current Model

None in content. Interface moves to `owners/` module with no content change. The absence of a delete method is preserved verbatim.

---

## Database Schema: Table Definitions

### Vets Service Tables

#### `vets`

```sql
CREATE TABLE vets (
    id         INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(30) NOT NULL,
    last_name  VARCHAR(30) NOT NULL
);
```

#### `specialties`

```sql
CREATE TABLE specialties (
    id   INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name VARCHAR(80) NOT NULL
);
```

#### `vet_specialties`

```sql
CREATE TABLE vet_specialties (
    vet_id       INT NOT NULL REFERENCES vets(id),
    specialty_id INT NOT NULL REFERENCES specialties(id),
    PRIMARY KEY (vet_id, specialty_id)
);
```

No foreign key from any Vets table to any Owners table (FR-018).

---

### Owners Service Tables

#### `types`

```sql
CREATE TABLE types (
    id   INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name VARCHAR(80) NOT NULL
);
```

#### `owners`

```sql
CREATE TABLE owners (
    id         INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(30)  NOT NULL,
    last_name  VARCHAR(30)  NOT NULL,
    address    VARCHAR(255) NOT NULL,
    city       VARCHAR(80)  NOT NULL,
    telephone  VARCHAR(20)  NOT NULL
);
```

#### `pets`

```sql
CREATE TABLE pets (
    id         INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name       VARCHAR(30) NOT NULL,
    birth_date DATE,
    type_id    INT NOT NULL REFERENCES types(id),
    owner_id   INT NOT NULL REFERENCES owners(id),
    UNIQUE (owner_id, name)   -- FR-009: must exist on H2, MySQL, PostgreSQL at every stage
);
```

#### `visits`

```sql
CREATE TABLE visits (
    id          INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    pet_id      INT          NOT NULL REFERENCES pets(id),
    visit_date  DATE         NOT NULL,
    description VARCHAR(255) NOT NULL
);
```

No foreign key from any Owners table to any Vets table (FR-018).

**Note**: The DDL above uses ANSI-compatible syntax for illustration. The actual scripts per engine (H2, MySQL, PostgreSQL) are split verbatim from the monolith's `schema.sql` files in E2-S1. The real MySQL and PostgreSQL scripts have not been read (DEF-8); E2-S3 must read them before the migration job is designed (research item 8a).

---

## H2 Profile Initialisation

Each service initialises only its own table subset in the H2 profile. Running both services against a single shared H2 instance is not supported (spec Assumptions).

| Service | H2 `schema.sql` tables | H2 `data.sql` seed data |
|---|---|---|
| Vets | `vets`, `specialties`, `vet_specialties` | Vet and specialty seed rows |
| Owners | `owners`, `pets`, `visits`, `types` | Owner, pet, visit, and type seed rows |

`spring.sql.init.mode` is set to `always` for the H2 profile (dev/CI) and `never` for MySQL/PostgreSQL profiles (FR-019).

---

## Database Role Model

Three principals are required (research item 9):

| Principal | Tables | Permissions | Notes |
|---|---|---|---|
| `vets_runtime` | `vets`, `specialties`, `vet_specialties` | SELECT | No INSERT/UPDATE/DELETE; no access to owner tables |
| `owners_runtime` | `owners`, `pets`, `visits`, `types` | SELECT, INSERT, UPDATE on `owners`, `pets`, `types`; SELECT, INSERT on `visits`; DELETE denied on `visits` | DELETE on `visits` denied (FR-008). UPDATE on `visits`: NEEDS CLARIFICATION (research item 9a). No access to vet tables after S5. |
| `migration_principal` | All tables | DDL + DML | Used only by the migration job; not used at runtime |

After S5, the Owners runtime role is additionally denied any access to the vet tables (FR-020).

---

## Cross-Service Boundary Rules

The following rules are hard constraints enforced at multiple levels:

1. **No shared Java library**: No entity class, repository interface, or utility class is shared between the `vets` and `owners` modules (FR-001). Model classes are copied verbatim; there is no compile-time dependency between the two modules.

2. **No cross-package import**: No class in the `vet` package imports a class from the `owner` package, and vice versa. Enforced by the CI import check on every pull request (FR-002, SC-004, research item 2).

3. **No cross-service database access**: No foreign key, view, or cross-service query exists between the Vets table set (`vets`, `specialties`, `vet_specialties`) and the Owners table set (`owners`, `pets`, `visits`, `types`) (FR-018). Enforced at the database role level (FR-020) and verified by the data ownership rule scripts in E2-S2.

4. **No owner PII in Vets artefacts**: No owner column or row value (name, address, telephone) appears in any Vets-side dump, copy, log, test fixture, or reconciliation report (FR-022, SC-005). Reconciliation reports for owner tables contain only counts and hashes.

5. **Visit append-only**: No delete route and no delete repository method for Visit exist in the Owners service (FR-008). Enforced at the application layer, the database role layer, and the constitution layer.

---

## Entities Not Changed by This Feature

The following entities and their Java classes, field definitions, validation rules, and relationships are unchanged in content. They are redistributed to the appropriate module but not modified:

| Entity | Current location | Target module | Content change |
|---|---|---|---|
| `Vet` | `src/.../vet/Vet.java` | `vets/` | None |
| `Specialty` | `src/.../vet/Specialty.java` | `vets/` | None |
| `Vets` | `src/.../vet/Vets.java` | `vets/` | None |
| `VetController` | `src/.../vet/VetController.java` | `vets/` | None |
| `VetRepository` | `src/.../vet/VetRepository.java` | `vets/` | None |
| `Owner` | `src/.../owner/Owner.java` | `owners/` | None (FR-007 explicit) |
| `Pet` | `src/.../owner/Pet.java` | `owners/` | None |
| `PetType` | `src/.../owner/PetType.java` | `owners/` | None |
| `Visit` | `src/.../owner/Visit.java` | `owners/` | None |
| `OwnerRepository` | `src/.../owner/OwnerRepository.java` | `owners/` | None |
| `PetRepository` | `src/.../owner/PetRepository.java` | `owners/` | None |
| `VisitRepository` | `src/.../owner/VisitRepository.java` | `owners/` | None |
| `CacheConfiguration` | `src/.../system/CacheConfiguration.java` | `vets/` | None |
| `WebConfiguration` | `src/.../system/WebConfiguration.java` | Both modules | None in content; copied verbatim into each module's `system/` package |
| `CrashController` | `src/.../system/CrashController.java` | `owners/` only | None (FR-015) |
| `PetValidator` | `src/.../owner/PetValidator.java` | `owners/` | None |
| `BaseEntity` | `src/.../model/BaseEntity.java` | Both modules | NEEDS CLARIFICATION — see below |

**NEEDS CLARIFICATION**: `BaseEntity` (and any other classes in the `model` or `system` packages that are shared between the vet and owner packages in the monolith) must be copied verbatim into each module's package tree. The exact set of shared infrastructure classes (e.g., `BaseEntity`, `NamedEntity`, `Person`) must be confirmed by reading the monolith source before E1-S4. There is no shared module; each service carries its own copy (FR-001, research item 3).

---

## Entities Introduced by This Feature

### DeploymentRecord (GitHub Deployments API object)

**Not a Java entity; not a database table.** A GitHub Deployment object created via the GitHub Deployments API on every production deploy (FR-003, E4-S4).

#### Fields

| Field | Type | Notes |
|---|---|---|
| `environment` | `String` | e.g., `production`, `staging` |
| `service` | `String` | `vets` or `owners` |
| `sha` | `String` | Git commit SHA of the deployed image |
| `releaseId` | `String` | Release identifier (tag or workflow run ID) |
| `createdAt` | `Timestamp` | Set by GitHub |

#### Purpose

The KPI-1 report job reads these records and counts deployments of the other service per release of one service. Target: 0 (KPI-1). The counting rule (whether config-only redeploys, UI bumps, and edge redeploys count) is NEEDS CLARIFICATION (research item 7a) and must be decided in E4-S1 before S2.

---

## Summary of NEEDS CLARIFICATION Items in This Document

| ID | Item | Blocking Story |
|---|---|---|
| 9a | Whether UPDATE on `visits` can be withheld from the Owners runtime role (Hibernate `@OneToMany` with `@JoinColumn` may require it) | E5-S8 |
| 7a | KPI-1 counting rule for DeploymentRecord (config-only redeploys, UI bumps, edge redeploys) | E4-S1 |
| 8a | Real MySQL and PostgreSQL `schema.sql` content; migration job tool (Flyway, Liquibase, custom SQL) | E2-S3 |
| 8b | Separate database instance vs. separate schema for S5 vet copy (affects role configuration and reconciliation tool) | E2-S5 |
| BaseEntity | Exact set of shared infrastructure classes (`BaseEntity`, `NamedEntity`, `Person`) that must be copied into both modules | E1-S4 |
