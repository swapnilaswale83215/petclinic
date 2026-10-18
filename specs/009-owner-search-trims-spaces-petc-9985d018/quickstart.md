# quickstart.md

**Feature**: Owner Search Trims Spaces
**Branch**: `009-owner-search-trims-spaces-petc-9985d018`
**Date**: 2026-10-18
**Phase**: 1 — Quickstart Validation Guide

---

## Purpose

This guide describes how to verify the feature end-to-end once the pull request is applied. Each step is mapped to the success criterion it proves. Steps are ordered so that the cheapest, fastest checks come first and the post-deploy smoke check comes last.

This guide does not contain implementation code, migration steps, or full test-suite listings. Those belong in `tasks.md`. For the data model see `data-model.md`; for the HTTP contract see `contracts/get-owners.md`.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| Java | 17 or later (`java -version`) |
| Build tool | Maven Wrapper (`./mvnw`) or Gradle Wrapper (`./gradlew`) present in the repository root |
| Git | Pull request branch checked out: `009-owner-search-trims-spaces-petc-9985d018` |
| Network | Not required for unit/`@WebMvcTest` steps; required for Testcontainers steps if run |
| Docker | Required only if running MySQL/PostgreSQL Testcontainers tests (out of scope for this pull request) |
| Running application | Required only for Steps 5 and 6 (smoke check); H2 profile is sufficient |

> **NEEDS CLARIFICATION**: The exact Maven command to start the application locally (e.g., `./mvnw spring-boot:run` vs a wrapper script) and the default local port are assumed to be `8080` based on Spring Boot defaults. Confirm against the project README if the port differs.

---

## Step 0 — Record the KPI-2 baseline on current main (before applying the pull request)

**Purpose**: Establish the base-commit test counts so that "0 newly failing, 0 newly skipped" can be measured precisely.

**When to run**: Once, on the base commit (before the pull request branch is applied), by the contributor completing E1-S1.

**Commands**:

```
git checkout main
./mvnw test -Dspring.profiles.active=default 2>&1 | tee baseline-test-output.txt
```

**Record**:
- Commit SHA (`git rev-parse HEAD`)
- Total tests run, passed, failed, skipped from the Surefire summary line
- CI workflow name and triggers (from `.github/workflows/`)
- Owner ids and count returned by `GET /owners?lastName=Davis`, `GET /owners?lastName=Davis%20`, `GET /owners?lastName=%20Davis`, and `GET /owners?lastName=Davis%C2%A0` on this commit (manual browser or `curl` check against a locally running application)

**Proves**: Baseline for KPI-2 (SC-002). Required before E1-S2 (G1 gate) can be signed.

> **NEEDS CLARIFICATION**: Whether the CI baseline counts include Testcontainers tests (which may be skipped without Docker). The "newly skipped" comparison must use the same environment as the pull request CI run. Confirm with E1-S1 record.

---

## Step 1 — Run the full test suite on the pull request branch

**Purpose**: Confirm KPI-2 — no existing test fails or is newly skipped after the change.

**When to run**: After checking out the pull request branch.

**Commands**:

```
git checkout 009-owner-search-trims-spaces-petc-9985d018
./mvnw test -Dspring.profiles.active=default 2>&1 | tee pr-test-output.txt
```

**Expected outcome**:
- Surefire summary shows 0 failures, 0 errors.
- The count of skipped tests is identical to the baseline recorded in Step 0.
- The build exits with code 0.

**Verification**:
Compare the summary line in `pr-test-output.txt` against `baseline-test-output.txt`. The failed and skipped counts must not increase.

**Proves**: KPI-2 (SC-002) — 100 % pass rate against the base-commit count. Covers User Story 4 acceptance scenarios 1, 2, and 3, and FR-006, FR-007, FR-012.

---

## Step 2 — Confirm the new test method exists and passes

**Purpose**: Confirm KPI-1 — the machine-verifiable proof that padded Davis terms behave identically to the trimmed term.

**When to run**: After Step 1 passes.

**Commands**:

```
./mvnw test -pl . -Dtest=OwnerControllerTests#processFindFormPaddedTermMatchesTrimmedTermForMultipleOwners -Dspring.profiles.active=default
```

> **NEEDS CLARIFICATION**: The exact Surefire filter syntax for the project's build tool. If the project uses Gradle, the equivalent is `./gradlew test --tests "*.OwnerControllerTests.processFindFormPaddedTermMatchesTrimmedTermForMultipleOwners"`. Confirm which build tool is primary.

**Expected outcome**:
- The named test method is listed as `PASSED` in the Surefire/Gradle test report.
- No other test method in `OwnerControllerTests` is listed as failed, skipped, or modified.

**Verification**:
Open the Surefire HTML report at `target/surefire-reports/` (Maven) or `build/reports/tests/test/` (Gradle) and locate `OwnerControllerTests`. Confirm:
1. `processFindFormPaddedTermMatchesTrimmedTermForMultipleOwners` — PASSED
2. `processFindFormByLastName` — PASSED (unchanged)
3. `processFindFormIgnoresSurroundingWhitespace` — PASSED (unchanged)
4. `processFindFormWithWhitespaceOnlyLastNameReturnsAllOwners` — PASSED (unchanged)
5. `processFindFormNoOwnersFound` — PASSED (unchanged)
6. `processFindFormRedirectsOutOfBoundsPageToFirstPage` — PASSED (unchanged)

**Proves**: KPI-1 (SC-001) — the new test is the machine-verifiable evidence. Covers User Story 3 acceptance scenarios 1 and 3, FR-004, FR-005 (partially — mutation guard is Step 3), and SPEC-APP-2.

---

## Step 3 — Mutation guard check (manual, local only)

**Purpose**: Confirm that the new test is a genuine guard — it fails when the trimming logic is absent.

**When to run**: Once, locally, by the contributor. The result is recorded in the pull request description. The production file must be restored before the pull request is pushed.

**Procedure**:

1. Locate `OwnerController.processFindForm` in `src/main/java/.../owner/OwnerController.java`.
2. Temporarily remove or comment out the `String.strip()` call (or equivalent trimming line).
3. Run the new test only:
   ```
   ./mvnw test -Dtest=OwnerControllerTests#processFindFormPaddedTermMatchesTrimmedTermForMultipleOwners -Dspring.profiles.active=default
   ```
4. Confirm the test is listed as `FAILED`.
5. Restore `OwnerController.java` to its original state.
6. Confirm `OwnerController.java` does not appear in `git diff` (it must not be in the pull request diff under Case A).
7. Record the failure result in the pull request description.

**Expected outcome at step 4**: The test fails with a Mockito verification error (the repository was called with a padded argument, violating the `never()` assertion, or the model attributes differ).

**Expected outcome at step 6**: `git diff` shows no changes to `OwnerController.java`.

**Proves**: User Story 3 acceptance scenario 2, FR-005. Confirms the test is not vacuous.

---

## Step 4 — Diff allowlist check

**Purpose**: Confirm SC-003 and SC-004 — the pull request touches only the permitted file(s) and introduces no sensitive data exposure.

**When to run**: Before opening the pull request, and again at review time.

**Commands**:

```
git diff main...HEAD --name-only
```

**Expected outcome under Case A**:

```
src/test/java/org/springframework/samples/petclinic/owner/OwnerControllerTests.java
```

One file only. No other file appears.

**Expected outcome under Case B** (only if E1-S2 confirms Case B):

```
src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java
src/test/java/org/springframework/samples/petclinic/owner/OwnerControllerTests.java
```

Two files only.

**Reviewer checklist** (SC-004, FR-008, SPEC-SEC-1):
- [ ] No `logger.*`, `log.*`, or `System.out` call referencing the search term or any Owner field
- [ ] No new `model.addAttribute` carrying the raw padded term or any Owner sensitive field
- [ ] No change to the `notFound` field error text
- [ ] Only synthetic owner values used in the new test (last name "Davis", ids 2 and 4 or equivalent)
- [ ] No `findOwners.html`, `ownersList.html`, `pom.xml`, `build.gradle`, `application*.properties`, `schema.sql`, `data.sql`, Docker file, or CI workflow file in the diff

**Proves**: SC-003, SC-004, FR-008, FR-009, SPEC-SEC-1, SPEC-SEC-3.

---

## Step 5 — Seed-backed equality check on the running application (manual)

**Purpose**: Confirm that the H2 seed data returns the same owners for padded and trimmed Davis terms on page 1 of a live application instance.

**When to run**: After the pull request branch is built and the application is started locally with the H2 profile.

**Start the application**:

```
./mvnw spring-boot:run -Dspring-boot.run.profiles=default
```

> **NEEDS CLARIFICATION**: Confirm the local start command and port. `http://localhost:8080` is assumed.

**Requests to issue** (browser or `curl`):

| Request | Expected HTTP status | Expected result |
|---|---|---|
| `GET /owners?lastName=Davis` | 200 | Page lists Betty Davis (id 2) and Harold Davis (id 4); total 2 owners |
| `GET /owners?lastName=Davis%20` | 200 | Identical page — same two owners, same order, same count |
| `GET /owners?lastName=%20Davis` | 200 | Identical page — same two owners, same order, same count |
| `GET /owners?lastName=%20Davis%20` | 200 | Identical page — same two owners, same order, same count |
| `GET /owners?lastName=Davis%C2%A0` | 200 | Identical page — same two owners (if `strip()` handles U+00A0); see NEEDS CLARIFICATION below |

**Verification**: The owner ids and count in the response body must be identical across all five requests. Record ids and counts only — do not record names, addresses, or telephone numbers (FR-008, Principle III).

**Out-of-range redirect check**:

| Request | Expected HTTP status | Expected `Location` header |
|---|---|---|
| `GET /owners?lastName=Davis%20&page=999` | 302 | `/owners?page=1&lastName=Davis` (no `%20`, no `+`) |
| `GET /owners?lastName=%20Davis&page=999` | 302 | `/owners?page=1&lastName=Davis` |

**Proves**: SC-005, KPI-1 (seed-level evidence, E2-S2), FR-002, FR-003, User Story 1 acceptance scenarios 1–3, User Story 2 acceptance scenarios 1–2.

> **NEEDS CLARIFICATION**: Whether the U+00A0 probe (`Davis%C2%A0`) returns the same result as `Davis` depends on the SPEC-APP-6 reproduction record (R-001, R-006). If the reproduction confirms Case A and the existing `strip()` call handles U+00A0, the probe passes automatically. If the probe shows a difference, the design must return to the G0 owner before G1 is signed.

---

## Step 6 — Post-deploy smoke check (after merge and normal redeploy)

**Purpose**: Confirm SC-005 on the deployed environment — the fix is live and padded searches agree with trimmed searches in production.

**When to run**: After the delivery lead approves the merge (E4-S4), CI passes on main, and the normal redeploy completes (E4-S5).

> **NEEDS CLARIFICATION**: The deployed application URL and whether the Davis seed owners (ids 2 and 4) are present in the production or staging database. If the deployed environment uses MySQL or PostgreSQL with a different dataset, the owner ids may differ. The check should use whatever last name is known to return at least two owners in that environment, or use the H2-backed staging environment if available.

**Requests to issue**:

| Request | Expected result |
|---|---|
| `GET /owners?lastName=Davis` (or equivalent known last name) | Returns N owners on page 1 |
| `GET /owners?lastName=Davis%20` | Returns the same N owners on page 1 |

**Verification**: Owner ids and count are identical between the two requests. Record ids and counts only.

**Proves**: SC-005, E4-S5 acceptance criterion.

---

## Step mapping summary

| Step | Success criteria proved | Stories / FRs covered |
|---|---|---|
| 0 — Baseline record | KPI-2 baseline established | E1-S1, SPEC-APP-6, SPEC-DATA-3 |
| 1 — Full suite on PR branch | KPI-2 (SC-002): 0 failures, 0 newly skipped | US4 AC1–3, FR-006, FR-007, FR-012 |
| 2 — New test passes | KPI-1 (SC-001): padded = trimmed, mocked repo called with "Davis" only | US3 AC1, AC3, FR-004 |
| 3 — Mutation guard | New test is a genuine guard; fails without strip() | US3 AC2, FR-005 |
| 4 — Diff allowlist | SC-003: ≤2 files; SC-004: no sensitive data exposure | FR-008, FR-009, SPEC-SEC-1, SPEC-SEC-3 |
| 5 — Seed equality check | KPI-1 (seed level), SC-005 (local); redirect URL clean | US1 AC1–3, US2 AC1–2, FR-002, FR-003 |
| 6 — Post-deploy smoke | SC-005 on deployed environment | E4-S5, SPEC-PLAT-2 |

---

## Open NEEDS CLARIFICATION items in this guide

| ID | Question | Blocking step |
|---|---|---|
| QS-1 | Local application start command and port (assumed `./mvnw spring-boot:run`, port 8080) | Step 5 |
| QS-2 | Surefire/Gradle filter syntax for single-method test run | Step 2 |
| QS-3 | Whether Testcontainers tests are included in the baseline count (affects "newly skipped" comparison) | Step 0, Step 1 |
| QS-4 | U+00A0 probe result on current main (depends on SPEC-APP-6 reproduction record) | Step 5 |
| QS-5 | Deployed environment URL and dataset for post-deploy smoke check | Step 6 |
