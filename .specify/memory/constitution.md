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

Validation MUST be enforced via Jakarta Bean Validation annotations embedded directly in domain classes (Owner, Pet, Visit, Vet, NamedEntity, Person) and via `PetValidator` for Pet-specific rules. No separate validator class hierarchy MUST be introduced that bypasses or duplicates these embedded constraints.

### III. Sensitive Data Handling
Owner records — specifically the `name`, `address`, and `telephone number` fields — are designated sensitive zones. Any feature, query, log statement, or diagnostic output that reads or displays Owner sensitive fields MUST apply appropriate access controls and MUST NOT expose these fields in unprotected endpoints, error pages, stack traces, or actuator outputs. Bulk export or unrestricted search of Owner sensitive fields MUST NOT be introduced without explicit review and approval.

### IV. Profile-Aware Persistence
The application MUST support profile-based database selection: H2 (in-memory, default/dev), MySQL, and PostgreSQL. Database schema MUST be managed via Spring Data JPA/Hibernate DDL or versioned migration scripts appropriate to the active profile. The H2 in-memory profile MUST be treated as a development and testing convenience only; it MUST NOT be used as evidence of production data volume or persistence behavior. Integration tests targeting MySQL MUST use `MySqlIntegrationTests` and tests targeting PostgreSQL MUST use `PostgresIntegrationTests`, both backed by Testcontainers.

### V. Service-Layer Caching Contract
Veterinarian lookups MUST be served through the caching layer configured in `CacheConfiguration`. The `@Cacheable` annotation on `VetRepository` MUST NOT be removed or bypassed without a documented architectural decision. Any new cacheable operation MUST be registered in `CacheConfiguration` and MUST have a corresponding cache-invalidation strategy documented before merging.

### VI. Scope Enforcement
The following capabilities are explicitly out of scope and MUST NOT be implemented in this repository:

- Billing or invoicing
- Payment processing
- Inventory or pharmacy management
- Insurance claims processing
- Multi-clinic or multi-location management

Any pull request introducing functionality in these areas MUST be rejected at review regardless of implementation quality.

### VII. Observability and Health
The application MUST expose health checks and metrics via Spring Boot Actuator and Micrometer. Actuator endpoints MUST remain enabled and MUST NOT be removed or disabled. Sensitive Owner data MUST NOT appear in any Actuator endpoint response, log output, or metric label.

---

## Domain Model

### Entities

| Entity | Aliases / Notes |
|---|---|
| **Owner** | The pet's registered guardian; customer of the clinic. Sensitive fields: name, address, telephone number. |
| **Pet** | A pet registered under exactly one Owner. Must have a valid PetType at registration. |
| **Visit** | A recorded veterinary appointment/encounter for a pet. Immutable once created; append-only. |
| **Veterinarian** | A vet employed at the clinic. May have zero or many Specialties. |
| **PetType** | Species/category classification of a pet (e.g., dog, cat, bird, hamster). |
| **Specialty** | A veterinarian's area of medical expertise (e.g., radiology, surgery, dentistry). |

### Relationships

- Owner OWNS Pet (one-to-many; a Pet MUST belong to exactly one Owner)
- Pet HAS Visit (one-to-many; a Visit MUST be associated with exactly one Pet)
- Visit ASSIGNED_TO Veterinarian (many-to-one)
- Pet HAS PetType (many-to-one; PetType MUST be valid at registration)
- Veterinarian HAS Specialty (many-to-many; zero or many per vet)

### Processes

- **Owner Registration**: Capture and persist Owner with valid telephone number and address.
- **Pet Registration**: Register a Pet under an Owner with a valid PetType.
- **Veterinarian Directory Management**: Add, update, and list Veterinarians and their Specialties.
- **Visit Scheduling**: Create a new Visit record for a Pet; records MUST NOT be deleted.
- **Visit History Tracking**: Retrieve and display the append-only visit history for a Pet.

### Vocabulary

| Term | Definition |
|---|---|
| Vet | Abbreviation for Veterinarian |
| Clinic | The single veterinary practice location modeled by this application |

---

## Technology Stack and Constraints

- **Language & Runtime**: Java with Spring Boot; GraalVM Native Image hints MUST be maintained in `PetClinicRuntimeHints`.
- **Web Layer**: Spring MVC with Thymeleaf server-side rendering. Controllers MUST populate model attributes consumed by templates; JSON endpoints are secondary and MUST NOT replace the primary Thymeleaf flow.
- **Persistence**: Spring Data JPA repository interfaces MUST be used; no explicit repository implementation classes MUST be introduced unless Spring Data JPA cannot satisfy the requirement. Repository interfaces are: `OwnerRepository`, `PetTypeRepository`, `VetRepository`.
- **Validation**: Jakarta Bean Validation annotations MUST reside in domain classes. `PetValidator` (implementing `org.springframework.validation.Validator`) MUST be used for Pet-specific cross-field validation.
- **Formatting**: `PetTypeFormatter` MUST be used for binding PetType from form submissions.
- **Internationalisation**: All user-facing strings MUST be externalised to i18n properties files. The `I18nPropertiesSyncTest` MUST pass; no hard-coded UI strings MUST be introduced. All languages MUST have complete translations before merging.
- **Containerisation**: Docker Compose MUST be used for containerised local runs. Kubernetes manifests in `k8s/` MUST remain consistent with the active application configuration.
- **Build**: Maven Wrapper (`mvnw`) or Gradle Wrapper scripts bundled in the repository MUST be used; no requirement for a globally installed build tool.

---

## Development Workflow and Quality Gates

### Automated CI
All commits MUST pass the GitHub Actions CI pipeline before merging. The pipeline MUST execute the full test suite including unit tests, slice tests (`@WebMvcTest`), service integration tests (`ClinicServiceTests`), and database integration tests (MySQL, PostgreSQL via Testcontainers).

### Test Requirements
- Every controller MUST have a corresponding `@WebMvcTest` slice test (e.g., `OwnerControllerTests`, `PetControllerTests`, `VisitControllerTests`, `VetControllerTests`).
- Every domain validator MUST have a corresponding unit test (e.g., `PetValidatorTests`, `ValidatorTests`).
- Business-rule enforcement (Section I–II) MUST be covered by at least one test asserting the rule boundary condition.
- Concurrency behaviour MUST be covered by `PetClinicConcurrencyTests`.
- The H2 default profile integration MUST be covered by `PetClinicIntegrationTests`.
- MySQL and PostgreSQL profiles MUST each be covered by their respective integration test classes.
- The `I18nPropertiesSyncTest` MUST pass on every build; partial translations MUST NOT be merged.

### Code Review Requirements
- Every pull request MUST be reviewed by at least one other contributor before merging.
- Reviewers MUST verify compliance with all Core Principles in this constitution, particularly business-rule integrity (Principle II), sensitive data handling (Principle III), and scope enforcement (Principle VI).
- Pull requests introducing new cacheable operations MUST include updated `CacheConfiguration` and documented invalidation strategy.
- Pull requests touching Owner sensitive fields MUST receive explicit sign-off confirming no unprotected exposure.

### Branch and Merge Policy
- The `main` branch MUST remain releasable at all times.
- Feature branches MUST be rebased or merged only after CI passes and code review is approved.
- Database schema changes MUST be accompanied by migration scripts compatible with all supported profiles (H2, MySQL, PostgreSQL).

---

## Governance

This constitution supersedes all informal conventions and undocumented practices for the `swapnilaswale83215/petclinic` repository. It is an unratified draft and MUST be ratified by human maintainers before it is treated as non-negotiable.

**Amendment Process**: Any amendment to this constitution MUST include: (1) a written description of the change and its justification, (2) identification of any Core Principle, Domain Model entry, or Workflow rule affected, (3) a migration plan for existing code that would be non-compliant under the amendment, and (4) approval from at least one senior maintainer. Amendments MUST be recorded with an updated version number and amendment date in the footer.

**Compliance**: All pull requests and code reviews MUST verify compliance with this constitution. Non-compliance MUST be raised as a blocking review comment. Complexity or deviation from any principle MUST be explicitly justified in the pull request description; unexplained deviation MUST be treated as a defect.

**Conflict Resolution**: In any conflict between this constitution and a README, inline comment, or undocumented convention, this constitution MUST take precedence once ratified. Prior to ratification, conflicts MUST be escalated to a maintainer for resolution.

**Concept File Relationship**: The Concept File (workspace proj-76f74f, v1) is the SME baseline from which this constitution is derived. Business rules quoted verbatim from the Concept File MUST NOT be weakened by implementation convenience. Source code conventions observed in the repository MAY inform implementation guidance only where they do not conflict with the Concept File.

---

**Version**: 1.0.0 | **Status**: Unratified draft | **Generated**: 2026-10-16 | **Last Amended**: 2026-10-16