# Quickstart: Reject Past Visit Dates

**Feature**: `010-reject-past-visit-dates-15ab17d7`
**Branch**: `010-reject-past-visit-dates-15ab17d7`
**Date**: 2026-10-26
**Spec**: `/specs/010-reject-past-visit-dates/spec.md`

---

## Purpose

This guide describes how to verify the feature end-to-end after the change is applied. Each step is mapped to the success criterion it proves. No implementation code is included; see `tasks.md` for that.

The feature has exactly two observable outcomes:

1. A POST to the new-visit form with a past date is rejected with the message `"Visit date must be today or in the future."` and the visit is not saved.
2. A POST with today's date (or any future date) is accepted and the visit is saved.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| Java 17 | Must be on `PATH`; `java -version` should report 17.x |
| Maven Wrapper | Use `./mvnw` from the repository root; no external Maven installation required |
| Git | To verify the diff scope (SC-002) |
| Repository checked out on the feature branch | `git checkout 010-reject-past-visit-dates-15ab17d7` |
| No uncommitted changes to files outside `VisitController.java` and `VisitControllerTests.java` | Confirmed by `git status` |

---

## Step 1 — Confirm the change is scoped to exactly two files

**Command**:

```
git diff main -- --name-only
```

**Expected output** (exactly these two lines, no others):

```
src/main/java/org/springframework/samples/petclinic/owner/VisitController.java
src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java
```

**Success criterion proved**: SC-002 — the commit touches only the two permitted files.

**What to check**: If any other file appears in the diff, the change is out of scope and must be corrected before proceeding.

---

## Step 2 — Confirm no `messages*.properties` file defines `visit.date.pastNotAllowed`

**Command**:

```
grep -r "visit.date.pastNotAllowed" src/main/resources/
```

**Expected output**: no output (exit code 1 or empty result).

**Success criterion proved**: FR-003 (message is a Java compile-time constant, not a properties key), FR-007 (no properties file edited), and the `I18nPropertiesSyncTest` precondition (R-013).

**What to check**: Any match means a properties file was edited in violation of FR-007.

---

## Step 3 — Confirm `Visit.java` is byte-identical to main

**Command**:

```
git diff main -- src/main/java/org/springframework/samples/petclinic/owner/Visit.java
```

**Expected output**: no output (empty diff).

**Success criterion proved**: FR-007 and FR-012 — `Visit.java` must remain byte-identical; no entity-level annotation was added.

---

## Step 4 — Run the format and checkstyle validators

**Command**:

```
./mvnw spring-javaformat:validate -pl . && ./mvnw validate -pl .
```

**Expected outcome**: `BUILD SUCCESS` for both invocations; zero new checkstyle violations reported.

**Success criterion proved**: SC-003 — `spring-javaformat:validate` and `nohttp` checkstyle pass on the changed files with no new suppressions.

**What to check**: Any `BUILD FAILURE` or new violation must be resolved before the test run.

---

## Step 5 — Run `VisitControllerTests` in isolation

**Command**:

```
./mvnw test -pl . -Dtest=VisitControllerTests
```

**Expected outcome**:

- `BUILD SUCCESS`
- Surefire summary: `Tests run: 5, Failures: 0, Errors: 0, Skipped: 0`
- The replaced test method (formerly `processNewVisitFormHasErrorsWhenVisitDateIsNotInFuture`) is absent from the report; a new time-relative test method is present and passes.

**Surefire report location**: `target/surefire-reports/TEST-org.springframework.samples.petclinic.owner.VisitControllerTests.xml`

**What to verify in the report**:

| Assertion | Where to look |
|---|---|
| Exactly 5 test cases listed | `<testsuite tests="5" ...>` attribute |
| 0 failures, 0 errors | `failures="0" errors="0"` attributes |
| The new test asserts the exact string `"Visit date must be today or in the future."` from the `BindingResult` | Test method name and any failure message in the XML; a passing test confirms the assertion held |
| `OwnerRepository.save` is never called for the yesterday post | Confirmed by the test passing (Mockito `verify(ownerRepository, never()).save(any())`) |
| `OwnerRepository.save` is called exactly once for the today post | Confirmed by the test passing (Mockito `verify(ownerRepository, times(1)).save(any())`) |
| A 3xx redirect is returned for the today post | Confirmed by the test passing (MockMvc `andExpect(status().is3xxRedirection())`) |

**Success criteria proved**:

- KPI-1 — 5 tests, 0 failures in `VisitControllerTests`
- KPI-2 — exact error text `"Visit date must be today or in the future."` verified by the `BindingResult` assertion
- FR-001 — `OwnerRepository.save` not called on rejection
- FR-002 — redirect on today's date
- FR-003 — exact error code and message confirmed
- FR-006 — one time-relative test using `LocalDate.now()` replaces the old fixed-date test
- FR-008 — server-side check executes before `result.hasErrors()` (structural; confirmed by the test passing without any client-side bypass)
- User Story 1 acceptance scenarios 1 and 2 (yesterday and further-past dates rejected)
- User Story 2 acceptance scenario 1 (today accepted)

---

## Step 6 — Verify the combined-error scenario (past date + blank description)

This scenario is covered by the existing `VisitControllerTests` suite. Confirm it passes within the Step 5 run: the surefire report must show 0 failures across all 5 tests, which includes any test asserting that both `date` and `description` errors are returned together.

**Success criteria proved**:

- FR-011 — both field errors returned in the same HTTP 200 response
- User Story 1 acceptance scenario 3

---

## Step 7 — Verify null-date and type-mismatch behaviour

This scenario is covered by the existing `VisitControllerTests` suite. Confirm it passes within the Step 5 run: the surefire report must show 0 failures, which includes any test asserting that a blank or unparseable date produces only the existing binding error and that `visit.date.pastNotAllowed` is absent.

**Success criteria proved**:

- FR-004 — `typeMismatch.visitDate` not used for past-date rejection
- User Story 3 acceptance scenarios 1 and 2

---

## Step 8 — Run the full test suite

**Command**:

```
./mvnw test -pl .
```

**Expected outcome**: `BUILD SUCCESS`; all test classes pass with 0 failures and 0 errors.

**Key classes to confirm in the surefire output**:

| Class | Why it matters |
|---|---|
| `VisitControllerTests` | Already confirmed in Step 5; re-confirmed here |
| `ClinicServiceTests` | Saves a `new Visit()` with a future default date directly via `OwnerRepository`; must pass with no assertion edits (R-012) |
| `PetClinicIntegrationTests` | Full-context integration test; must pass with no assertion edits |
| `OwnerControllerTests` | Unrelated controller; must not regress |
| `PetControllerTests` | Unrelated controller; must not regress |
| `I18nPropertiesSyncTest` | Confirms no new properties key was introduced (R-013) |

**Success criteria proved**:

- SC-001 — 0 regressions in the existing suite; no assertion edits to any file other than `VisitControllerTests.java`
- User Story 4 acceptance scenario 2
- KPI-1 (full-suite confirmation)

---

## Step 9 — Spot-check `VisitController.java` for the three required behaviour changes

Open `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` and confirm the following by reading the source:

| Check | What to look for |
|---|---|
| Past-date rejection | `visit.getDate() != null && visit.getDate().isBefore(LocalDate.now())` followed by `result.rejectValue("date", "visit.date.pastNotAllowed", "Visit date must be today or in the future.")` in `processNewVisitForm`, placed before the `result.hasErrors()` guard |
| `minVisitDate` set to today | `model.addAttribute("minVisitDate", LocalDate.now())` (not `plusDays(1)`) in `initNewVisitForm` |
| `@InitBinder` unchanged | `setAllowedFields` still lists `"id"` and `"*.id"` exactly as on main; no other change to the binder method |
| Time-zone comment | A code comment near `LocalDate.now()` stating that "today" is defined by the JVM's default time zone |

**Success criteria proved**:

- FR-001, FR-002 — rejection and acceptance logic present
- FR-003 — exact error code and default message as a compile-time constant with no request-data concatenation
- FR-005 — `minVisitDate` equals `LocalDate.now()`
- FR-008 — check is before `result.hasErrors()` and guarded by a null check
- FR-009 — `@InitBinder` disallowed-field rule unchanged
- R-010 — time-zone handling documented in a comment

---

## Step 10 — Confirm the story description records the three behaviour changes

Open the story description for E1-S1 and confirm it states:

1. The error code is `visit.date.pastNotAllowed`.
2. The error text is `"Visit date must be today or in the future."`.
3. Today's date is now accepted (was previously rejected on main).

**Success criterion proved**: E1-S1 acceptance criterion — the story description states the three behaviour changes.

---

## Summary of Success Criteria Coverage

| Criterion | Step(s) |
|---|---|
| KPI-1: 5 tests, 0 failures in `VisitControllerTests` | 5, 8 |
| KPI-2: Exact error text verified by `BindingResult` assertion | 5 |
| SC-001: 0 regressions in full suite | 8 |
| SC-002: Only two files changed | 1 |
| SC-003: Checkstyle passes, 0 new suppressions | 4 |
| FR-001: Save not called on rejection | 5 |
| FR-002: Redirect on today's date | 5 |
| FR-003: Exact error code and default message | 5, 9 |
| FR-004: `typeMismatch.visitDate` not used for past-date rejection | 7 |
| FR-005: `minVisitDate` equals `LocalDate.now()` | 9 |
| FR-006: One time-relative test using `LocalDate.now()` | 5 |
| FR-007: No properties file, template, schema, or other file edited | 1, 2, 3 |
| FR-008: Server-side check before `result.hasErrors()`, null-guarded | 5, 9 |
| FR-009: `@InitBinder` unchanged | 9 |
| FR-011: Both errors returned together | 6 |
| FR-012: No schema/seed change; past-dated rows unaffected | 3, 8 |
| User Story 1 (past date rejected) | 5 |
| User Story 2 (today accepted) | 5 |
| User Story 3 (null/unparseable date unaffected) | 7 |
| User Story 4 (automated test coverage) | 5, 8 |
| R-012: `ClinicServiceTests` unaffected | 8 |
| R-013: `I18nPropertiesSyncTest` passes | 8 |
