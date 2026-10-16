# PetClinic Constitution

## Core Principles

### I. Modular Monolith Architecture
The application MUST be structured as a modular monolith with server-side rendering via Thymeleaf. Controllers MUST return model attributes consumed directly by Thymeleaf templates; the application MUST NOT be treated or extended as a pure REST API. Package boundaries MUST be respected: `owner` package owns Owner, Pet, PetType, Visit, and related controllers/repositories; `vet` package owns Vet, Specialty, and related controllers/repositories; `system` package owns infrastructure concerns (caching, web configuration, error handling). Cross-package dependencies MUST be introduced only when explicitly justified and reviewed.

### II. Business-Rule Integrity
All domain operations MUST enforce the following rules verbatim:

- A Pet MUST always belong to exactly one Owner.
- A Visit MUST always be associated with exactly one Pet.
- A Pet MUST have a valid PetType at registration.
- An Owner MUST have a valid telephone number and address before registration is complete.
- Veterinarian specialty assignments are optional (zero or many per vet).
- Visit records MUST NOT be deleted once created; visit history MUST only be appended to.

Validation MUST be enforced via Jakarta Bean Validation annotations embedded directly in domain classes (e.g., `@NotBlank`, `@NotNull`) and via `PetValidator` for Pet-specific rules. No separate standalone validator classes MUST be introduced that duplicate or contradict domain-embedded constraints.

### III. Sensitive Data Handling
Owner records — specifically the `name`, `address`, and `telephone number` fields — are designated sensitive zones. Any feature, query, log statement, or diagnostic output that reads or displays Owner sensitive fields MUST apply appropriate access controls and MUST NOT expose these fields in unprotected endpoints, error pages, stack traces, or actuator outputs. Logging of Owner sensitive fields is prohibited. Any change to how Owner data is stored, displayed, or transmitted MUST be explicitly reviewed for data exposure risk.

### IV. Profile-Aware Persistence
The application MUST support profile-based database selection: H2 in-memory for development/testing, MySQL and PostgreSQL for production-representative environments. The default H2 in-memory profile resets all data on restart and MUST NOT be used as representative of real production data volume or persistence behavior. Integration tests targeting MySQL MUST use `MySqlIntegrationTests` with Testcontainers; integration tests targeting PostgreSQL MUST use `PostgresIntegrationTests` with Testcontainers. Schema management MUST be handled via Spring Data JPA/Hibernate DDL or versioned scripts appropriate to the active profile; manual schema changes MUST NOT be applied outside the profile-managed mechanism.

### V. Service-Layer Caching Contract
A caching layer MUST be applied at the service/repository layer for veterinarian lookups via `VetRepository` using `@Cacheable`. Cache configuration MUST be managed exclusively in `CacheConfiguration`. Controllers MUST NOT implement their own caching logic for veterinarian data. Any change to the veterinarian data model or retrieval contract MUST include a corresponding review and update of the cache configuration to prevent stale data.

### VI. Scope Boundary Enforcement
The following capabilities are explicitly out of scope and MUST NOT be introduced into this codebase:

- Billing or invoicing
- Payment processing
- Inventory or pharmacy management
- Insurance claims processing
- Multi-clinic or multi-location management

Any pull request introducing functionality in these areas MUST be rejected at review regardless of implementation quality.

### VII. Observability and Health
The application MUST expose health checks and metrics via Spring Boot Actuator and Micrometer. Actuator endpoints MUST be configured to avoid exposing sensitive Owner data. Structured application health MUST be verifiable via the `/actuator/health` endpoint in all deployment environments. Observability configuration MUST NOT be removed or disabled without an explicit architectural decision record.

---

## Domain Model

### Entities

| Entity | Aliases | Description |
|---|---|---|
| Owner | The pet's registered guardian/customer of the clinic | Holds name, address, and telephone number; owns one or more Pets |
| Pet | — | Registered animal belonging to exactly one Owner; has a PetType and a visit history |
| Visit | A recorded veterinary appointment/encounter for a pet | Immutable once created; associated with exactly one Pet |
| Veterinarian | Vet | Clinic staff member; may have zero or many Specialties |
| PetType | Species/category classification of a pet (e.g., dog, cat, bird, hamster) | Required at Pet registration |
| Specialty | A veterinarian's area of medical expertise (e.g., radiology, surgery, dentistry) | Optional; zero or many per Veterinarian |

### Relationships

- Owner OWNS Pet (one-to-many; a Pet MUST belong to exactly one Owner)
- Pet HAS Visit (one-to-many; append-only)
- Visit ASSIGNED_TO Veterinarian (many-to-one)
- Pet HAS PetType (many-to-one; required)
- Veterinarian HAS Specialty (many-to-many; optional)

### Processes

- **Owner Registration**: Capture and validate Owner name, address, and telephone number before persisting.
- **Pet Registration**: Associate a new Pet with an existing Owner; require a valid PetType selection.
- **Veterinarian Directory Management**: Add, update, and list Veterinarians and their optional Specialties.
- **Visit Scheduling**: Create a new Visit record for a Pet; MUST NOT overwrite or delete existing Visit records.
- **Visit History Tracking**: Retrieve and display the append-only list of Visits for a given Pet.

### Vocabulary

- **Vet**: Abbreviation for Veterinarian; used interchangeably in code and UI.
- **Clinic**: The single veterinary practice location modeled by this application; multi-location is out of scope.

---

## Technology Stack and Constraints

### Runtime Stack
- **Language**: Java (Spring Boot application entry point: `PetClinicApplication`)
- **Web Layer**: Spring MVC with Thymeleaf server-side rendering; i18n via `WebConfiguration` and `messages_*.properties` files
- **Persistence**: Spring Data JPA; repository interfaces (`OwnerRepository`, `PetTypeRepository`, `VetRepository`) MUST use auto-generated implementations; no explicit repository implementation classes MUST be written unless Spring Data cannot satisfy the requirement
- **Databases**: H2 (dev/test), MySQL, PostgreSQL (profile-activated)
- **Caching**: JCache-backed cache managed via `CacheConfiguration`; `@EnableCaching` MUST remain active
- **Observability**: Spring Boot Actuator + Micrometer
- **Build**: Maven Wrapper (`mvnw`) or Gradle Wrapper (`gradlew`) as bundled in the repository; external Maven/Gradle installations MUST NOT be required
- **Containerisation**: Docker Compose for local containerised runs; Kubernetes manifests in `k8s/` for cluster deployment
- **CI**: GitHub Actions pipeline MUST pass before any merge to the main branch

### Internationalisation
All user-facing strings displayed in Thymeleaf templates MUST be externalised to `messages_*.properties` files. The `I18nPropertiesSyncTest` MUST pass, enforcing that no hard-coded strings exist in HTML files and that every key is translated in every supported language. Adding a new UI string MUST include entries in all language property files simultaneously.

### Native Image Compatibility
Runtime hints MUST be maintained in `PetClinicRuntimeHints` for any class or resource requiring reflection or serialisation in GraalVM native image builds. Tests annotated `@DisabledInNativeImage` document known native incompatibilities and MUST include a comment explaining the reason.

---

## Development Workflow and Quality Gates

### Testing Requirements
- Unit tests MUST be provided for all controller classes using `@WebMvcTest` with Mockito-based mocking of repositories.
- Domain validation logic MUST be covered by unit tests (e.g., `ValidatorTests`, `PetValidatorTests`).
- Service-layer integration tests MUST be provided in `ClinicServiceTests` covering all repository interactions.
- Database integration tests MUST be executed against both MySQL (`MySqlIntegrationTests`) and PostgreSQL (`PostgresIntegrationTests`) using Testcontainers before a release is cut.
- Concurrency behaviour MUST be validated by `PetClinicConcurrencyTests` to guard against race conditions in concurrent owner/pet operations.
- The full test suite MUST pass on the H2 profile in CI on every pull request.

### CI Pipeline
- GitHub Actions CI MUST execute the full Maven/Gradle build and test suite on every pull request and every push to the main branch.
- A failing CI pipeline MUST block merge; no exceptions are permitted without a documented architectural decision.
- Docker Compose smoke tests SHOULD be executed in CI when infrastructure changes are made to `docker-compose.yml` or `k8s/` manifests.

### Code Review
- Every pull request MUST be reviewed by at least one other contributor before merge.
- Reviewers MUST verify compliance with all Core Principles in this constitution, including scope boundary enforcement and sensitive data handling rules.
- Pull requests introducing new entities or relationships MUST update the Domain Model section of this constitution as part of the same change.

### Branch and Versioning
- The main branch MUST always represent a deployable state.
- Database schema changes MUST be backward-compatible or accompanied by a migration script appropriate to the active profile.

---

## Governance

This constitution is the authoritative specification for the `swapnilaswale83215/petclinic` repository. It supersedes any conflicting conventions found in inline comments, README fragments, or informal team practices.

**Compliance**: All pull requests MUST be evaluated against this constitution. Any implementation that violates a MUST-level rule MUST be rejected or remediated before merge, regardless of test passage.

**Amendments**: Amendments to this constitution MUST be proposed as a pull request modifying this document directly. An amendment MUST include: (1) a description of the change and its rationale, (2) identification of any existing code or tests affected, and (3) a migration plan if existing behaviour must change. Amendments MUST be approved by at least one maintainer before taking effect.

**Out-of-Scope Additions**: Any feature request touching billing, payment, inventory, insurance, or multi-location management MUST be rejected at the constitution review stage without requiring full implementation review.

**Ratification**: This document is an unratified draft. It MUST be reviewed and explicitly ratified by the project maintainer(s) before it is treated as non-negotiable. Until ratified, it serves as the working baseline for development decisions.

**Sensitive Data Governance**: Any proposed change to the storage, display, transmission, or logging of Owner name, address, or telephone number fields MUST be flagged explicitly in the pull request description and MUST receive explicit approval from a maintainer.

---

**Version**: 1.0.0 | **Status**: Unratified draft | **Generated**: 2026-10-16 | **Last Amended**: 2026-10-16