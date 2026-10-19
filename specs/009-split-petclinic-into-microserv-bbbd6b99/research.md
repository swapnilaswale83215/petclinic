# Research: Split PetClinic into Microservices

**Feature**: 009-split-petclinic-into-microserv-bbbd6b99
**Date**: 2026-10-19
**Phase**: 0 — Research

---

## 1. Build System: Multi-Module Maven Layout

**Decision**: Restructure the repository as a Maven multi-module project with three modules — `vets`, `owners`, and `petclinic-ui` — each producing an independent artifact. The root POM coordinates the build but does not produce a deployable artifact. The existing `mvnw` wrapper is retained; no external Maven installation is required.

**Rationale**: The spec requires two independently versioned deployable artifacts with no shared Java library (FR-001). Maven multi-module is the natural fit for a Spring Boot project already using `mvnw`. Each module can be built in isolation with `-pl vets -am verify` or `-pl owners -am verify`, satisfying E4-S2's acceptance criterion. Gradle is an alternative but the constitution names Maven Wrapper as the build tool and switching build systems is out of scope.

**Alternatives considered**:
- Separate repositories per service: rejected because the spec requires a single repository with a shared CI pipeline and a path-filtered deploy workflow (FR-002, E4-S3). Cross-repo coordination of the import check and the KPI-2 suite would be significantly harder.
- Monorepo with independent Gradle subprojects: technically equivalent but introduces a build-tool change that the constitution does not sanction and that is not in scope.

---

## 2. Package Boundary Enforcement: Import Check

**Decision**: Add a CI step that scans compiled bytecode (or source imports) and fails the build if any class in the `vet` package imports a class from the `owner` package, or vice versa. This check runs on every pull request as part of `pr-verify`.

**Rationale**: FR-002 and SC-004 require that the Vets artifact contains no owner classes and the Owners artifact contains no vet classes, and that a cross-package import fails the build. A bytecode-level check (e.g., using `jdeps`, ArchUnit, or a custom Maven Enforcer rule) is more reliable than a source-level grep because it catches transitive dependencies introduced through shared utilities.

**Alternatives considered**:
- ArchUnit rule in a test class: clean and idiomatic for Spring Boot projects; runs as part of the normal test phase; preferred implementation approach. The exact test class location (shared test module or per-service) is NEEDS CLARIFICATION — see item 2a below.
- `jdeps` in a shell script: works but is harder to maintain and produces less readable output in PR checks.
- Maven Enforcer plugin with a custom rule: possible but requires more boilerplate than ArchUnit.

**2a. NEEDS CLARIFICATION**: Where does the ArchUnit import-check test live in the multi-module layout? Options are (i) a dedicated `build-checks` module that depends on both `vets` and `owners` compiled outputs, (ii) a test in each module that checks only its own outbound imports, or (iii) a root-level test. The choice affects whether the check can be run per-module or only at the root. This must be decided in E1-S4.

---

## 3. Model Class Duplication vs. Shared Module

**Decision**: Copy the domain model classes (entities, value objects) verbatim into each service module rather than extracting a shared library. Vets gets `Vet` and `Specialty`; Owners gets `Owner`, `Pet`, `PetType`, and `Visit`. There is no shared Java library between the two services.

**Rationale**: FR-001 explicitly prohibits a shared Java library. The spec's Key Entities section confirms the boundary: the vet package in its entirety belongs to Vets; the owner package in its entirety belongs to Owners. There is no entity that both services need to read or write at runtime. Duplication is the correct approach here because the two domains are genuinely independent after the split.

**Alternatives considered**:
- Shared `model` module as a compile-time dependency: violates FR-001 explicitly. Rejected.
- Shared `model` module published as a versioned artifact: also violates FR-001 (it is still a shared Java library). Rejected.
- Code generation from a schema: unnecessary complexity for a migration that must preserve existing class content verbatim (FR-007 requires `Owner.java` to move with no change to its content).

---

## 4. petclinic-ui Artifact: Versioning and Pinning Mechanism

**Decision**: NEEDS CLARIFICATION. The spec states that the petclinic-ui artifact versioning and pinning mechanism is to be established as part of this feature and that the exact artifact coordinates and repository location are not settled (Assumptions section). The decision between an N/N-1 compatibility window and a coordinated UI release excluded from the KPI-1 count is deferred to E1-S2 (sponsor decision).

**What is known**:
- Both services must depend on the same pinned version of petclinic-ui (FR-014).
- The artifact must contain: `layout.html`, `error.html`, the welcome page, static assets (`/resources/**`, `/webjars/**`), and all 11 i18n message bundles.
- The `I18nPropertiesSyncTest` must pass in both services with the pinned bundles (E4-S9).
- A build with an unpinned or checksum-mismatched petclinic-ui must fail CI (E5-S10).
- The publish job must run a layout.html and error.html parity test (E4-S9).

**Alternatives to be evaluated in E1-S2 and E4-S9**:
- Publish petclinic-ui as a Maven artifact to GitHub Packages (or a private registry), pinned by version and SHA-256 checksum in each service's POM. UI changes require a new version and a bump PR per service; coordinated bumps are excluded from the KPI-1 count.
- Embed petclinic-ui as a Git submodule or a versioned directory in the monorepo, with a checksum file. Simpler but less standard for artifact management.
- Publish as a JAR with a WebJar-style layout so Spring Boot's resource handler serves it automatically. Aligns with the existing `/webjars/**` route.

**4a. NEEDS CLARIFICATION**: The exact artifact coordinates (groupId, artifactId, registry URL) and the chosen compatibility rule (N/N-1 window vs. coordinated release) must be decided in E1-S2 before E4-S9, E3-S3, and E5-S10 can be finalised.

---

## 5. Edge Router Technology

**Decision**: NEEDS CLARIFICATION. The edge technology is explicitly unproven (DEF-4, DEF-5) and is to be chosen in E4-S6 against a capability checklist. The research below narrows the field.

**Required capabilities** (from FR-010 through FR-013, FR-016, FR-017, E4-S6):
- Exact-path routing (`/vets` and `/vets.html` → Vets; everything else → Owners)
- 404 response for `/actuator/**`, `/livez`, `/readyz` on the public host without forwarding to either service
- GET/HEAD-only retry with jitter; no retry of POST/PUT/DELETE
- Per-upstream circuit breaker
- Fallback: Vets down → 503 with `Retry-After`; Owners down must not affect Vets responses
- Request mirroring for the S2 shadow comparison (FR-025, E3-S8)
- Query-string masking in logs (owner last-name search, E5-S6)
- Forwarded-header stripping (E5-S1)
- No session propagation to Vets (E3-S4)
- Configurable connect and read timeouts per upstream (FR-012)
- Routing table as a reviewed file in the repository (FR-010)

**Candidates**:
- **Spring Cloud Gateway** (Spring Boot-native, Java): supports all required capabilities; routing table is a YAML file in the repository; integrates naturally with the existing Spring Boot stack; mirroring requires a custom filter or a third-party plugin. Widely used in Spring ecosystems.
- **Nginx** (with Lua or njs for mirroring and circuit breaking): mature, well-documented; mirroring is native (`mirror` directive); circuit breaking requires `nginx-plus` or a Lua module; query masking requires custom log format. Routing table is an `nginx.conf` file.
- **Envoy Proxy**: supports all capabilities natively including mirroring, circuit breaking, and header manipulation; configuration is verbose YAML; less familiar to a Spring Boot team; strong Kubernetes integration.
- **Traefik**: Kubernetes-native; supports routing, circuit breaking, retries; mirroring support is limited in the open-source edition; query masking requires middleware configuration.

**Preliminary recommendation**: Spring Cloud Gateway or Nginx are the most likely choices given the Spring Boot context and the Kubernetes deployment target. The final decision belongs to E4-S6 and must be validated against the full capability list before S1b.

**5a. NEEDS CLARIFICATION**: The edge technology must be chosen in E4-S6. Until that decision is made, contracts and configuration examples in this plan use technology-neutral descriptions. The routing table format (YAML, HCL, nginx.conf) is determined by the chosen technology.

---

## 6. CI Path-Filtered Deploy Workflows

**Decision**: Use GitHub Actions path filters (`paths:` trigger) to ensure that a change confined to the vet module triggers only `deploy-vets.yml` and a change confined to the owner module triggers only `deploy-owners.yml`. A change to shared files (root POM, petclinic-ui, edge configuration) triggers both deploy workflows.

**Rationale**: FR-002 and KPI-1 require that a change to one service does not trigger a deploy of the other. GitHub Actions `paths:` filters are the standard mechanism for this on the GitHub Actions platform (confirmed by the spec's assumption that GitHub Actions is the CI platform). The exact workflow file names are illustrative in the spec and are to be confirmed during implementation (Assumptions section).

**Alternatives considered**:
- Separate repositories with independent pipelines: rejected (see item 1).
- A single workflow with conditional job execution based on changed files using `dorny/paths-filter` or equivalent: functionally equivalent to separate workflow files but harder to audit for KPI-1 purposes because the deployment record must name the service (FR-003). Separate workflow files make the service name unambiguous.
- Manual triggering only: does not satisfy the automation requirement of FR-002.

**6a. NEEDS CLARIFICATION**: The exact workflow file names (`deploy-vets.yml`, `deploy-owners.yml`, `pr-verify.yml`) must be confirmed and recorded in the repository. The path filter patterns (e.g., `vets/**`, `owners/**`) must be defined precisely, including what happens when the root POM or shared configuration changes. This is a task for E4-S3.

---

## 7. GitHub Deployment Records for KPI-1

**Decision**: Use the GitHub Deployments API to create a Deployment object on every production deploy. Each record carries: environment name, service name (`vets` or `owners`), git SHA, and release identifier. A scheduled KPI-1 report job reads these records and counts deployments of the other service per release of one service.

**Rationale**: FR-003 and E4-S4 specify GitHub Deployment records as the data source for KPI-1. The GitHub Deployments API is the standard mechanism on GitHub Actions. The KPI-1 baseline must be recorded before S2 (E4-S1, DEF-9).

**Alternatives considered**:
- Custom deployment log in a database or file: more flexible but adds infrastructure; the spec explicitly names GitHub Deployment records.
- GitHub Releases: captures releases but not deployments to specific environments; insufficient for KPI-1 which measures per-environment deploy counts.

**7a. NEEDS CLARIFICATION**: The counting rule for KPI-1 must be decided in E4-S1. Specifically: do config-only redeploys count? Do petclinic-ui version bumps count? Does an edge-only redeploy count? DEF-9 flags this as open. The sponsor must record the counting rule before S2.

---

## 8. Database Schema Split and Migration Stages

**Decision**: The migration follows stages S2 through S6 as referenced in ADR-APP-5 and ADR-DATA-1. For the schema split:
- Vets owns: `vets`, `specialties`, `vet_specialties`
- Owners owns: `owners`, `pets`, `visits`, `types`
- No foreign key, view, or cross-service query between the two sets (FR-018)
- `schema.sql` and `data.sql` are split per engine into vet and owner subsets by verbatim extraction (E2-S1)
- In H2 profile: each service initialises only its own table subset
- In MySQL/PostgreSQL: DDL is applied only by the migration job; both services start with `spring.sql.init.mode=never` (FR-019)

**Rationale**: FR-018 and FR-019 define the ownership boundary and the DDL path. The staged approach (S2–S6) is a hard constraint from the brief. The H2 profile behaviour (each service uses its own H2 instance with only its own tables) is confirmed by the spec's Assumptions section.

**Alternatives considered**:
- Flyway or Liquibase for schema management: standard for production Spring Boot applications; the spec does not mandate a specific migration tool but requires the migration job to be the only DDL path. Flyway or Liquibase would be the natural implementation of the migration job. The exact tool is NEEDS CLARIFICATION — see item 8a.
- Shared database with schema-level separation (separate schemas, same instance): the spec does not prohibit this for MySQL/PostgreSQL but FR-020 requires database-role-level access denial, which is easier to enforce with separate databases or at minimum separate roles. The spec does not require separate database instances.

**8a. NEEDS CLARIFICATION**: The migration job implementation tool (Flyway, Liquibase, or custom SQL scripts) is not specified. The real MySQL and PostgreSQL schema scripts and profiles have not been read (DEF-8). E2-S3 must read those scripts before the migration job is designed. The idempotence strategy (create-if-missing, no demo seed in production) must be confirmed against the actual scripts.

**8b. NEEDS CLARIFICATION**: Whether the S5 vet schema copy uses a separate database instance or a separate schema within the same instance is not settled. This affects the database role configuration (FR-020) and the reconciliation tool design (FR-021). Must be decided before E2-S5.

---

## 9. Database Roles and Least-Privilege Access

**Decision**: Three database principals are required:
- **Vets runtime role**: SELECT on `vets`, `specialties`, `vet_specialties` only; no access to owner tables; no INSERT/UPDATE/DELETE on any table (vet data is read-only from the application, FR-006).
- **Owners runtime role**: SELECT, INSERT, UPDATE on `owners`, `pets`, `visits`, `types`; DELETE denied on `visits` (FR-008, E5-S8); no access to vet tables after S5 (FR-020).
- **Migration principal**: DDL rights on all tables during migration; no runtime use.

**Rationale**: FR-020 requires the Vets role to be denied SELECT on owner tables and denied all writes on vet tables. FR-008 requires Visit to be append-only. E5-S8 notes that withholding UPDATE on visits may break Hibernate's `@OneToMany` with `@JoinColumn` (DEF-3) and must be tested on real PostgreSQL and MySQL before being enforced.

**Alternatives considered**:
- Single shared runtime role for both services: violates FR-020 and the principle of least privilege. Rejected.
- Row-level security instead of table-level grants: more granular but unnecessary here since the table ownership boundary is clean. Adds complexity without benefit.

**9a. NEEDS CLARIFICATION**: Whether UPDATE on `visits` can be withheld from the Owners runtime role depends on the outcome of the Testcontainers test in E5-S8. This cannot be resolved without running the test against real PostgreSQL and MySQL under the restricted role. The decision is deferred to E5-S8.

---

## 10. Vets Cache Configuration

**Decision**: Retain `@Cacheable("vets")` on `VetRepository.findAll` in the Vets service only, backed by `CacheConfiguration` with cache statistics enabled and no eviction behaviour added. The Owners service has no cache named "vets" and no `CacheConfiguration` for vet data.

**Rationale**: FR-006 and the constitution's Section V (Service-Layer Caching Contract) require this exactly. The cache is JCache-backed as per the existing implementation. No eviction is added (FR-006 explicitly prohibits it). Cache statistics must be queryable via `cache.gets` with tag `cache=vets` on the Vets management port (FR-016, User Story 5 scenario 3).

**Alternatives considered**:
- Moving cache configuration to petclinic-ui or a shared module: violates FR-001 (no shared library) and the constitution's Section V (cache configuration must be in `CacheConfiguration`). Rejected.
- Adding eviction: explicitly prohibited by FR-006. Rejected.

---

## 11. Locale and Session Handling Across Services

**Decision**: Both services use `CookieLocaleResolver` with default English and the `lang` query parameter, as specified in FR-014. The locale cookie must carry `HttpOnly`, `SameSite=Lax`, and `Secure` on TLS (E5-S9). The Vets service must not issue a `JSESSIONID` cookie (E3-S4). A language selected on one service's page must apply on the other service's pages via the shared cookie.

**Rationale**: FR-014 requires cross-service locale persistence. `CookieLocaleResolver` is the correct mechanism because it stores the locale in a cookie that is sent with every request regardless of which service handles it, unlike `SessionLocaleResolver` which would require session sharing between services. The Vets service is stateless (no session) by design.

**Alternatives considered**:
- `SessionLocaleResolver` with a shared session store (e.g., Spring Session + Redis): would require a shared infrastructure component, adding operational complexity and a runtime dependency between services. Rejected.
- Passing locale as a query parameter on every link: fragile and would require changes to all Thymeleaf templates. Rejected.

**11a. NEEDS CLARIFICATION**: The cookie name, domain, and path attributes must be configured consistently in both services so that the cookie set by one service is readable by the other. If the two services are served from different origins (subdomains), the cookie domain must be set to the common parent domain. The exact cookie configuration depends on the deployment topology (single hostname behind the edge vs. separate subdomains), which is determined by the edge technology choice (item 5). This must be confirmed in E3-S4.

---

## 12. Actuator Exposure and Management Port

**Decision**: Both services expose only `health`, `info`, `metrics`, and `prometheus` via Spring Boot Actuator, on a dedicated management port (separate from the application port 8080). The effective `management.endpoints.web.exposure.include` is exactly `health,info,metrics,prometheus`. Liveness and readiness probes use the health groups on the management port. The edge returns 404 for `/actuator/**`, `/livez`, and `/readyz` on the public host without forwarding to either service (FR-011, FR-016).

**Rationale**: FR-016 and FR-017 require this configuration. ADR-APP-9 records it as an accepted change. The removal of `include=*` is a breaking change from the current monolith configuration and requires explicit sponsor agreement before S3 (E1-S3, DEF-6). The management port must not be routed by the edge and must be restricted by NetworkPolicy to the monitoring and orchestration network (FR-017).

**Alternatives considered**:
- Keeping `include=*` on the management port: violates FR-016 and exposes `env`, `heapdump`, `beans`, and `configprops`, which could leak owner data (constitution Section III). Rejected.
- Serving actuator on the same port as the application with path-based access control: the spec explicitly requires a dedicated management port (FR-016). Rejected.

**12a. NEEDS CLARIFICATION**: The management port number for each service must be decided and recorded in the configuration. The standard Spring Boot management port is 8081 but this must be confirmed against the existing Kubernetes manifests in `k8s/` and the Prometheus scrape configuration. This is a task for E4-S5.

---

## 13. Error Handling and CrashController Distribution

**Decision**: `CrashController` and the `/oups` route live in the Owners service only (FR-015). The Vets service uses `error.html` from the pinned petclinic-ui artifact for its own errors. Both services render the same error page layout. The edge renders the petclinic-ui error page for edge-level errors (503, circuit-breaker open) (E3-S7).

**Rationale**: FR-015 requires `/oups` to be served by the Owners service. The Vets service has no `CrashController` but must still render errors consistently using the shared `error.html`. This is consistent with the edge routing rule (FR-010): `/oups` is not a vet path and therefore routes to Owners.

**Alternatives considered**:
- Duplicating `CrashController` in both services: unnecessary; the Vets service does not need a crash endpoint. The shared `error.html` from petclinic-ui is sufficient for Vets error rendering.
- Handling all errors at the edge: would require the edge to understand application-level error semantics. Rejected; application errors should pass through unchanged (E3-S7).

---

## 14. S2 Shadow Comparison (Traffic Mirroring)

**Decision**: Before the S3 route flip, live GET `/vets` and GET `/vets.html` traffic is mirrored to the dark Vets service. Each response is compared with the monolith's response. The diff count over the agreed S2 window must be 0 for status, Content-Type, and body (FR-025, SC-003). The mirror must send no session or locale cookie.

**Rationale**: FR-025 and E3-S8 require this. The shadow comparison is the primary evidence for the S3 approval gate (E1-S14). The mirror must be passive (no effect on users if it fails) and must not carry cookies (to avoid locale or session side-effects on the dark service).

**Alternatives considered**:
- Replay of recorded traffic (offline comparison): less representative than live mirroring because it cannot capture timing-dependent or state-dependent differences. The spec explicitly requires live mirroring (FR-025).
- A/B testing framework: overkill for a binary comparison; adds complexity.

**14a. NEEDS CLARIFICATION**: The mirroring mechanism depends on the edge technology choice (item 5). Nginx supports native mirroring via the `mirror` directive; Spring Cloud Gateway requires a custom filter; Envoy supports mirroring natively. The implementation of the mirror and the diff tool must be confirmed after E4-S6.

---

## 15. S5 Vet Data Copy and Reconciliation

**Decision**: The S5 copy copies only the three vet tables (`vets`, `specialties`, `vet_specialties`) from the shared database to the Vets-owned schema. The reconciliation tool checks row counts and per-range checksums for all three tables; a mismatch blocks the switch. The freeze window must be 15 minutes or less (SC-001). No owner data is copied, exported, or logged at any point (FR-022).

**Rationale**: FR-021, FR-022, FR-023, and SC-001 define these requirements. The reconciliation report is stored as a CI artifact. The S5 step is optional (E1-S15 is a sponsor decision gate). If the sponsor declines S5, KPI-1 is judged on S3 and S4 only.

**Alternatives considered**:
- Logical replication (e.g., PostgreSQL logical replication slots, MySQL binlog): enables near-zero-downtime copy with continuous sync; reduces freeze window; more complex to set up and tear down; requires additional database permissions. Could be considered if the 15-minute freeze target is not achievable with a bulk copy on production data volumes.
- `pg_dump` / `mysqldump` of the three tables: simple and well-understood; freeze window depends on data volume; sufficient if data volume is small (PetClinic is a demo application with small data sets).
- Online schema change tools (pt-online-schema-change, gh-ost): designed for table alterations, not cross-schema copies. Not applicable here.

**15a. NEEDS CLARIFICATION**: The copy tool (bulk SQL INSERT/SELECT, `pg_dump`, logical replication, or a custom job) must be chosen based on the actual data volume and the target database engine. This is a task for E2-S5 and E2-S6. The freeze window rehearsal on production-like data will determine whether the chosen tool meets the 15-minute target.

---

## 16. Owner PII Protection in Migration Artefacts

**Decision**: No owner column or row value (name, address, telephone) appears in any Vets-side dump, copy, log, test fixture, or reconciliation report. Reconciliation reports for owner tables contain only counts and hashes (FR-022, SC-005). An automated scan of all S5 artefacts checks for owner column names before the switch is approved.

**Rationale**: FR-022 and the constitution's Section III (Sensitive Data Handling) require this. The scan must check for column names (`name`, `address`, `telephone`) as well as the table names (`owners`) in any output file. This is a hard gate before the S5 switch.

**Alternatives considered**:
- Manual review of artefacts: insufficient; the spec requires automated scanning (SC-005). Rejected.
- Differential privacy or anonymisation of owner data in reports: unnecessary; the reconciliation reports for owner tables need only counts and hashes, not any owner field values.

---

## 17. Rollback Strategy Per Stage

**Decision**: Each stage S2 through S6 has a rehearsed rollback:
- **S3 rollback**: Revert the routing table change in the edge; the monolith image is retained for at least 3 releases (E4-S8). Target: 5 minutes or less (E4-S8).
- **S4 rollback**: Redeploy the previous monolith image (retained for 3 releases). Target: 10 minutes or less.
- **S5 rollback**: Redeploy the previous Vets config against the old vet tables (which are intact by checksum). Target: 10 minutes or less. Valid only if no write to the vet tables has been detected after the S5 copy completed (edge case in spec).
- **S6**: Blocked until backup taken, restore test succeeded, and sponsor approval given (FR-023). The old vet tables are not dropped until all three pre-conditions are met.

**Rationale**: FR-023 and E1-S13 require rehearsed rollbacks for every stage. SC-002 sets the S3 flip and rollback target at 10 minutes or less (the spec notes this is an assumption and must be confirmed with the platform team). E4-S8 sets the S3 revert target at 5 minutes.

**Alternatives considered**:
- Blue-green deployment for S3: would require two full environments; the spec does not require this and the rollback is a routing-table revert, which is simpler.
- Feature flags for the route flip: possible but adds application-level complexity; the routing table change is the correct mechanism for an edge-level flip.

---

## 18. Test Suite Redistribution

**Decision**: The existing test classes are redistributed by service with no edits to expected results and no edits to test method bodies or assertions. The distribution is:
- **Vets module**: `VetControllerTests`, relevant portions of `ClinicServiceTests`
- **Owners module**: `OwnerControllerTests`, `PetControllerTests`, `VisitControllerTests`, `CrashControllerTests`, `PetClinicIntegrationTests`, `PetClinicConcurrencyTests`, relevant portions of `ClinicServiceTests`
- Both modules: `MySqlIntegrationTests`, `PostgresIntegrationTests` (scoped to each module's tables)

**Rationale**: FR-024 requires the same test methods and assertions before and after the split, with 0 failing tests. KPI-2 is measured against this suite. The `ClinicServiceTests` covers both vet and owner repository interactions and must be split by the data it exercises (E2-S1, E1-S11).

**Alternatives considered**:
- Keeping all tests in a shared test module: would not satisfy the per-service build isolation requirement (E4-S2 requires each module to build without the other). Rejected.
- Duplicating tests in both modules: violates FR-024 (the set of test methods must be identical before and after; duplication would double the count). Rejected.

**18a. NEEDS CLARIFICATION**: The exact split of `ClinicServiceTests` methods between the two modules must be determined by reading the actual test file. The spec requires verbatim redistribution (E2-S1: "moving ClinicServiceTests methods verbatim"). This is a task for E1-S11.

---

## 19. Native Image Compatibility

**Decision**: `PetClinicRuntimeHints` must be maintained in whichever module contains the classes requiring reflection or serialisation hints. If the hints are currently in a single class, they must be split or duplicated per module. Tests annotated `@DisabledInNativeImage` must be retained with their explanatory comments.

**Rationale**: The constitution requires runtime hints to be maintained for GraalVM native image builds. The multi-module split may require the hints to be distributed across modules. This is a correctness concern, not a new feature.

**Alternatives considered**:
- Dropping native image support: out of scope; the constitution requires it and the spec does not remove it.

**19a. NEEDS CLARIFICATION**: The current content of `PetClinicRuntimeHints` and which classes it covers must be read before the split. If all hints are for vet-side classes, they move to the Vets module; if mixed, they must be split. This is a task for E1-S4.

---

## 20. Open Issues Explicitly Out of Scope

**Decision**: GitHub issues #2, #3, and #5 are explicitly out of scope and must not be addressed as part of this feature, even if the migration work touches related code (Assumptions section, spec).

**Rationale**: The spec is explicit. Any incidental fix to out-of-scope issues during migration would risk scope creep and could invalidate the KPI-2 baseline (which requires no edits to expected results).

---

## 21. Java Version

**Decision**: Java 17 throughout. No upgrade or downgrade is in scope (Assumptions section).

**Rationale**: The spec is explicit. E1-S1 includes a decision on Java 17 vs. 21 as an approval gate, but the spec's Assumptions section states Java 17 remains unchanged. If E1-S1 changes this, the research document must be updated.

**Alternatives considered**: Java 21 (virtual threads, record patterns): not in scope per the spec's Assumptions section.

---

## 22. Constitution Amendment

**Decision**: After the migration is ratified by the maintainer, the constitution's Section I (Modular Monolith Architecture) must be amended to reflect the new two-service architecture. This amendment is out of scope for the implementation but must be planned as a follow-on task.

**Rationale**: The constitution's Assumptions section notes that Section I describes the pre-split state and will require amendment once the migration is ratified. The constitution is currently an unratified draft (Version 1.0.0, Status: Unratified draft).

---

## Summary of NEEDS CLARIFICATION Items

| ID | Item | Blocking Story |
|----|------|----------------|
| 2a | Location of the ArchUnit import-check test in the multi-module layout | E1-S4 |
| 4a | petclinic-ui artifact coordinates, registry URL, and compatibility rule (N/N-1 vs. coordinated release) | E1-S2, E4-S9 |
| 5a | Edge router technology choice | E4-S6 |
| 6a | Exact CI workflow file names and path filter patterns | E4-S3 |
| 7a | KPI-1 counting rule (config-only redeploys, UI bumps, edge redeploys) | E4-S1 |
| 8a | Migration job tool (Flyway, Liquibase, custom SQL) and real MySQL/PostgreSQL script content | E2-S3 |
| 8b | Separate database instance vs. separate schema for S5 vet copy | E2-S5 |
| 9a | Whether UPDATE on visits can be withheld from the Owners runtime role | E5-S8 |
| 11a | Locale cookie domain and path configuration relative to deployment topology | E3-S4 |
| 12a | Management port number for each service | E4-S5 |
| 14a | Mirroring mechanism implementation (depends on edge technology) | E3-S8 |
| 15a | S5 copy tool and freeze window validation on production-like data | E2-S5, E2-S6 |
| 18a | Exact split of ClinicServiceTests methods between modules | E1-S11 |
| 19a | Current content of PetClinicRuntimeHints and which module(s) it belongs to | E1-S4 |
