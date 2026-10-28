# Quickstart Validation Guide: Reject Past Visit Dates

**Feature**: `010-reject-past-visit-dates-15ab17d7`
**Branch**: `010-reject-past-visit-dates-15ab17d7`
**Date**: 2026-10-26
**Plan**: `specs/010-reject-past-visit-dates-15ab17d7/plan.md`

---

## Purpose

This guide describes how to verify the feature end-to-end after the two-file change (`VisitController.java` and `VisitControllerTests.java`) has been applied to the branch. Each scenario is mapped to the success criteria it proves. Run the scenarios in order; a failure in an earlier scenario is a prerequisite failure for later ones.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| Java | 17 or later (JVM default time zone determines "today"; no override needed) |
| Build tool | Maven Wrapper (`./mvnw`) present in the repository root; no external Maven installation required |
| Database | None required for automated tests; H2 in-memory is the default profile |
| Branch | `010-reject-past-visit-dates-15ab17d7` checked out and up to date with the two-file change applied |
| Network | Not required for unit or integration tests on the H2 profile |

Confirm the branch and working tree before running any scenario:

```
git status
git log --oneline -1
```

Expected: working tree clean, HEAD is the feature commit.

---

## Scenario 1 — Unit test suite for `VisitControllerTests`

**Proves**: KPI-1, KPI-2, FR-001, FR-002, FR-003, FR-006, FR-008, FR-011

**What it checks**:
- The replacement test posts yesterday's date and asserts HTTP 200, the form view `pets/createOrUpdateVisitForm`, a `BindingResult` field error on `date` with the exact default message `"Visit date must be today or in the future."`, and that `OwnerRepository.save` is never called.
- The same test posts today's date with a valid description and asserts a 3xx redirect and that `OwnerRepository.save` is called exactly once.
- The surefire report for the class shows exactly 5 tests, 0 failures, 0 errors.

**Command**:

```
./mvnw test -pl . -Dtest=VisitControllerTests
```

**Expected outcome**:

```
Tests run: 5, Failures: 0, Errors: 0, Skipped: 0
```

The surefire XML report is written to `target/surefire-reports/`. The test method that replaced `processNewVisitFormHasErrorsWhenVisitDateIsNotInFuture` must appear in the report and must show status PASS.

**Failure signals**:
- `Tests run: 6` — the old test was not removed; the replacement added a second method instead of replacing the first.
- `Tests run: 4` — the replacement test was not added or the old test was removed without a replacement.
- `Failures: 1` on the replacement test — the exact message string does not match, the view name is wrong, the redirect assertion failed, or the `save` mock verification failed.
- `Failures: 1` on any other test — a regression was introduced in one of the four unchanged tests.

**NC-3 note**: The surefire XML path (`target/surefire-reports/`) is the Maven default. If the CI pipeline uses a non-standard output directory, confirm the path by reading the GitHub Actions workflow file. This does not affect local verification.

---

## Scenario 2 — Full automated test suite regression check

**Proves**: SC-001, FR-007, FR-012, FR-009, Gate 8 (I18nPropertiesSyncTest)

**What it checks**:
- `ClinicServiceTests` passes without modification, confirming that the past-date check is not applied at the persistence layer and that `shouldAddNewVisitForPet` (which saves a `new Visit()` with a tomorrow default date) is unaffected.
- `PetClinicIntegrationTests` passes, confirming no regression in the broader integration surface.
- `OwnerControllerTests` passes, confirming no cross-controller regression.
- `PetControllerTests` passes, confirming no cross-controller regression.
- `I18nPropertiesSyncTest` passes, confirming that no new template key was introduced and no `messages*.properties` file was edited.

**Command**:

```
./mvnw test
```

**Expected outcome**: All test classes pass. The surefire summary shows 0 failures and 0 errors across the full suite.

**Failure signals**:
- `I18nPropertiesSyncTest` fails — a `messages*.properties` file was edited, or the test scans Java source for error codes and flags `visit.date.pastNotAllowed`. If the latter, read `I18nPropertiesSyncTest.java` to confirm scan scope (NC-4); if the test does scan Java source, a bundle entry for `visit.date.pastNotAllowed` must be added to every `messages*.properties` file, which requires a spec amendment before proceeding.
- `ClinicServiceTests.shouldAddNewVisitForPet` fails — the past-date check was placed at the entity or persistence layer rather than in the controller only; revert to the controller-only approach.
- Any other test class fails — a file outside the two permitted files was modified, or a shared test fixture was inadvertently changed.

---

## Scenario 3 — Code format and checkstyle validation

**Proves**: SC-003, FR-007 (no pom.xml or CI config change)

**What it checks**:
- `spring-javaformat:validate` passes on the changed files with no new suppressions.
- `nohttp` checkstyle passes with no new violations.

**Command**:

```
./mvnw validate
```

**Expected outcome**: BUILD SUCCESS with no checkstyle or format violations reported.

**Failure signals**:
- Format violation in `VisitController.java` or `VisitControllerTests.java` — run `./mvnw spring-javaformat:apply` to auto-fix, then re-validate.
- `nohttp` violation — a bare `http://` URL was introduced in a comment or string literal; replace with `https://` or a relative reference.

---

## Scenario 4 — Diff scope check

**Proves**: SC-002, FR-007

**What it checks**:
- Exactly two files differ from the base commit on main: `VisitController.java` and `VisitControllerTests.java`.
- No template, `messages*.properties` file, schema file, seed file, Kubernetes manifest, CI configuration file, or `pom.xml` appears in the diff.

**Command**:

```
git diff --name-only origin/main
```

**Expected output** (exactly two lines, order may vary):

```
src/main/java/org/springframework/samples/petclinic/owner/VisitController.java
src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java
```

**Supplementary check** — confirm `Visit.java` is byte-identical:

```
git diff origin/main -- src/main/java/org/springframework/samples/petclinic/owner/Visit.java
```

Expected: no output (empty diff).

**Failure signals**:
- Any file other than the two permitted files appears in the diff — identify which constraint was violated and revert the unintended change.
- `Visit.java` appears in the diff — the entity was modified; revert it.

---

## Scenario 5 — Manual smoke test (optional)

**Proves**: FR-001, FR-002, FR-005, FR-010 (observable end-to-end behaviour in the running application)

**What it checks**:
- The form hint (`minVisitDate`) reflects today's date, not tomorrow's.
- Submitting a past date re-renders the form with the message "Visit date must be today or in the future." and does not save the visit.
- Submitting today's date with a valid description redirects to the owner detail page and the visit appears in the visit history.

**Setup**:

```
./mvnw spring-boot:run
```

Wait for the application to start (look for `Started PetClinicApplication` in the console output). The application runs on `http://localhost:8080` by default.

**Steps**:

1. Navigate to `http://localhost:8080/owners` and select any owner.
2. Select any pet belonging to that owner.
3. Click "Add Visit".
4. **Past-date rejection** (proves FR-001, FR-003):
   - Enter a date that is at least one day before today (e.g., yesterday's date in the form's date picker or text field).
   - Enter a valid description (e.g., "Annual checkup").
   - Submit the form.
   - **Expected**: The form re-renders (HTTP 200). The message "Visit date must be today or in the future." is displayed near the date field. No new visit appears in the pet's visit history.
5. **Today acceptance** (proves FR-002, FR-005):
   - Enter today's date.
   - Enter a valid description.
   - Submit the form.
   - **Expected**: The browser redirects to the owner detail page. The new visit appears in the pet's visit history with today's date and the description entered.
6. **Form hint** (proves FR-005):
   - Return to "Add Visit" for the same pet.
   - Inspect the date field's minimum value hint (rendered from the `minVisitDate` model attribute).
   - **Expected**: The hint reflects today's date, not tomorrow's.

**Teardown**: Stop the application with `Ctrl+C`. The H2 in-memory database is discarded on shutdown; no cleanup is required.

**Note**: This scenario is optional because Scenarios 1 and 2 provide machine-verifiable proof of all acceptance criteria. The smoke test is useful for visual confirmation and for verifying the `minVisitDate` hint change, which is not directly asserted by the automated tests.

---

## Rollback

If any scenario fails and the change must be reverted:

```
git revert <commit-sha>
```

Then redeploy (or restart the local application). No schema migration was introduced; there is nothing to reverse at the database layer.

---

## Scenario-to-Criteria Map

| Scenario | KPI / SC / FR proved |
|---|---|
| 1 — `VisitControllerTests` (5 tests, 0 failures) | KPI-1, KPI-2 |
| 1 — yesterday POST: HTTP 200, form view, exact error message, no save | FR-001, FR-003, FR-008 |
| 1 — today POST: 3xx redirect, save called once | FR-002 |
| 1 — combined past date + blank description: both errors returned | FR-011 |
| 2 — full suite passes, no assertion edits | SC-001 |
| 2 — `ClinicServiceTests` passes | FR-012 (controller-only check, no persistence-layer impact) |
| 2 — `I18nPropertiesSyncTest` passes | FR-003 (no properties file edited), FR-007 |
| 3 — `mvn validate` passes | SC-003 |
| 4 — diff shows exactly two files | SC-002, FR-007 |
| 4 — `Visit.java` byte-identical | FR-007 |
| 5 — form re-renders with exact message on past date | FR-001, FR-003, FR-010 |
| 5 — redirect on today's date | FR-002, FR-010 |
| 5 — `minVisitDate` hint reflects today | FR-005 |
