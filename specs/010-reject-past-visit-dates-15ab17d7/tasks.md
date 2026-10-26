---

description: "Task list template for feature implementation"
---

# Tasks: Reject Past Visit Dates

**Input**: Design documents from `/specs/010-reject-past-visit-dates/`

**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/visit-form-post.md ✓

**Tests**: Test tasks are included — US4 (Priority P2) is explicitly a test-coverage deliverable per spec.md and FR-006.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. Because FR-007 and SC-002 restrict all changes to exactly two files (`VisitController.java` and `VisitControllerTests.java`), there is no shared infrastructure to build and no new entities to create. Phase 1 (Setup) and Phase 2 (Foundational) are therefore minimal orientation and read-only verification steps; all substantive work is in the user-story phases.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)
- Exact file paths are included in every description

## Path Conventions

Single-project Maven layout. All source paths are relative to the repository root.

---

## Phase 1: Setup (Orientation & Scope Verification)

**Purpose**: Confirm the working environment, locate the two permitted files, and verify the baseline test suite passes before any edit is made. No files are created or modified in this phase.

- [ ] T001 Read `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` in full and confirm the current signatures of `initNewVisitForm`, `processNewVisitForm`, and the `@InitBinder` method; note the current value of `minVisitDate` (expected: `LocalDate.now().plusDays(1)`) and the absence of any past-date check
- [ ] T002 Read `src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java` in full and identify the existing test method `processNewVisitFormHasErrorsWhenVisitDateIsNotInFuture` that must be replaced; confirm the class currently contains exactly 5 test methods and note the `@MockBean OwnerRepository` setup and any existing `ownerRepository.findById` stub patterns
- [ ] T003 Read `src/main/java/org/springframework/samples/petclinic/owner/Visit.java` in full and record the exact field declarations, annotations, and default-constructor body (expected: `this.date = LocalDate.now().plusDays(1)`); this file MUST remain byte-identical — reading it now establishes the baseline for the SC-002 diff check
- [ ] T004 Verify that `src/main/resources/messages.properties` and `src/main/resources/messages_de.properties` do NOT contain the key `visit.date.pastNotAllowed`; record the current state so the post-change diff can confirm no entry was added (FR-003, FR-007, R-006, R-013)

**Checkpoint**: Baseline confirmed — both permitted files are located, the test count is verified at 5, and the read-only files are recorded. Implementation can begin.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: There are no new shared infrastructure components to build for this feature (no new classes, no schema changes, no new dependencies). The single foundational prerequisite is understanding the exact insertion point in `processNewVisitForm` so that US1 and US2 edits are placed correctly.

**⚠️ CRITICAL**: The tasks below are read/analysis steps that MUST be completed before any edit is made to either permitted file.

- [ ] T005 In `VisitController.java`, locate the exact line in `processNewVisitForm` where `result.hasErrors()` is evaluated and the form is re-rendered; record the line number and the full method body so the null-guard insertion point (`if (visit.getDate() != null && visit.getDate().isBefore(LocalDate.now()))`) is unambiguous (R-003, R-004, FR-008)
- [ ] T006 In `VisitController.java`, locate the exact line in `initNewVisitForm` where `minVisitDate` is set (expected: `model.addAttribute("minVisitDate", LocalDate.now().plusDays(1))` or equivalent); record the current expression so the replacement (`LocalDate.now()`) is applied to the correct statement (FR-005, R-005)
- [ ] T007 In `VisitControllerTests.java`, record the full body of `processNewVisitFormHasErrorsWhenVisitDateIsNotInFuture` (the test to be replaced) and the stub pattern used by the other POST test that asserts a successful redirect, so the new combined test can reuse the same `ownerRepository.findById` stub and `MockMvc` perform pattern (R-007, R-008, FR-006)

**Checkpoint**: Insertion points identified — US1 through US4 edits can now be made with precision.

---

## Phase 3: User Story 1 — Clinic Staff Submits a Visit with a Past Date (Priority: P1) 🎯 MVP

**Goal**: `processNewVisitForm` rejects any POST where `visit.date` is non-null and strictly before `LocalDate.now()`, returns HTTP 200 with view `pets/createOrUpdateVisitForm`, records a field error on `date` with error code `visit.date.pastNotAllowed` and default message exactly `"Visit date must be today or in the future."`, and never calls `OwnerRepository.save`.

**Independent Test**: POST to `/owners/{ownerId}/pets/{petId}/visits/new` with `date` = yesterday; assert HTTP 200, view `pets/createOrUpdateVisitForm`, field error on `date` with the exact message, and `verify(ownerRepository, never()).save(any())`.

- [ ] T008 [US1] In `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java`, insert the null-guarded past-date check immediately before the `result.hasErrors()` guard in `processNewVisitForm`: `if (visit.getDate() != null && visit.getDate().isBefore(LocalDate.now())) { result.rejectValue("date", "visit.date.pastNotAllowed", "Visit date must be today or in the future."); }` — the check MUST fall through to the existing `hasErrors()` return so that a simultaneous blank `description` also produces its error in the same response (FR-001, FR-003, FR-008, FR-011, R-002, R-003, R-004)
- [ ] T009 [US1] In `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java`, add a code comment immediately above the `isBefore` comparison stating: `// "Today" is defined as LocalDate.now() using the JVM's default time zone on the server. No explicit ZoneId override is applied; see spec Assumptions and DEF-8.` (R-010, spec Assumptions)
- [ ] T010 [US1] Verify by re-reading `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` that: (a) the `@InitBinder` method and its `setAllowedFields` call are byte-identical to the baseline recorded in T001; (b) no import, field, or method other than the two targeted edits (T008, T009, T006-target) has changed; (c) the error message string contains no concatenation of request data (FR-007, FR-009, SC-002, FR-003)

**Checkpoint**: Past-date rejection is in place. US1 acceptance scenarios 1, 2, and 3 are satisfiable. US2 implementation can now proceed (it depends on the same method edit being stable).

---

## Phase 4: User Story 2 — Clinic Staff Submits a Visit with Today's Date (Priority: P1)

**Goal**: `processNewVisitForm` accepts a POST where `visit.date` equals `LocalDate.now()` or is any future date (provided all other fields are valid), calls `OwnerRepository.save` exactly once, and redirects to `redirect:/owners/{ownerId}`. The `minVisitDate` model attribute on GET equals `LocalDate.now()` so the form hint matches the server rule.

**Independent Test**: POST to `/owners/{ownerId}/pets/{petId}/visits/new` with `date` = today and a valid description; assert 3xx redirect to `/owners/{ownerId}` and `verify(ownerRepository, times(1)).save(any())`.

- [ ] T011 [US2] In `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java`, in `initNewVisitForm`, change the `minVisitDate` model attribute value from `LocalDate.now().plusDays(1)` to `LocalDate.now()` (FR-005, R-005); confirm the template file `src/main/resources/templates/pets/createOrUpdateVisitForm.html` is NOT touched (FR-007)
- [ ] T012 [US2] Re-read `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` and confirm that the `processNewVisitForm` method's success path (date >= today, all fields valid) is unchanged: `OwnerRepository.save` is still called and the redirect to `redirect:/owners/{ownerId}` is still returned; confirm no edit was made to the success-path code (FR-002, FR-010, R-003)

**Checkpoint**: Today's date is accepted and the form hint is updated. US2 acceptance scenarios 1 and 2 are satisfiable. The two P1 stories are now both implemented in `VisitController.java`.

---

## Phase 5: User Story 3 — Missing or Unparseable Date Does Not Trigger the New Error (Priority: P2)

**Goal**: When `date` is null (blank submission) or unparseable, the existing binding error fires and `visit.date.pastNotAllowed` is never emitted. The null guard inserted in T008 is the mechanism; this phase verifies it is correct and that no regression has been introduced.

**Independent Test**: POST with `date` field blank; assert HTTP 200, existing required-field binding error on `date`, and absence of error code `visit.date.pastNotAllowed`. POST with `date` = a non-date string; assert HTTP 200, `typeMismatch` binding error, and absence of `visit.date.pastNotAllowed`.

- [ ] T013 [US3] Re-read the null-guard condition inserted in T008 in `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` and confirm it reads `visit.getDate() != null &&` before the `isBefore` call; confirm that when `visit.getDate()` is null the block is skipped entirely and the method falls through to the existing `hasErrors()` guard without calling `rejectValue` (FR-004, R-004, US3 acceptance scenario 1)
- [ ] T014 [US3] Re-read `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` and confirm that the `typeMismatch.visitDate` error code is not referenced anywhere in the modified file and that the `@InitBinder` method is byte-identical to the T001 baseline (FR-004, FR-009, R-014)

**Checkpoint**: Null and type-mismatch paths are unaffected. US3 acceptance scenarios 1 and 2 are satisfiable.

---

## Phase 6: User Story 4 — Automated Test Coverage Confirms Both Outcomes (Priority: P2)

**Goal**: Replace `processNewVisitFormHasErrorsWhenVisitDateIsNotInFuture` in `VisitControllerTests` with a single new test method that (a) posts `LocalDate.now().minusDays(1)` and asserts HTTP 200, view `pets/createOrUpdateVisitForm`, field error on `date` with exact message `"Visit date must be today or in the future."`, and `verify(ownerRepository, never()).save(any())`; then (b) posts `LocalDate.now()` with a valid description and asserts a 3xx redirect and `verify(ownerRepository, times(1)).save(any())`. The class retains exactly 5 test methods. All four other existing tests pass unchanged.

**Independent Test**: `mvn test -pl . -Dtest=VisitControllerTests`; surefire report shows 5 tests, 0 failures, 0 errors.

- [ ] T015 [US4] In `src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java`, remove the method `processNewVisitFormHasErrorsWhenVisitDateIsNotInFuture` in its entirety (FR-006, R-007, KPI-1)
- [ ] T016 [US4] In `src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java`, add a new test method (suggested name: `processNewVisitFormRejectsPastDateAndAcceptsToday`) that: (1) computes `LocalDate today = LocalDate.now();` once at the top of the method; (2) stubs `ownerRepository.findById(ownerId)` to return a populated `Owner` containing a `Pet` with the correct `petId` (reuse the stub pattern identified in T007); (3) performs a MockMvc POST to `/owners/{ownerId}/pets/{petId}/visits/new` with `date` = `today.minusDays(1).toString()` and a valid `description`, asserts HTTP status 200, model attribute `view` or `andExpect(view().name("pets/createOrUpdateVisitForm"))`, and `andExpect(model().attributeHasFieldErrorCode("visit", "date", "visit.date.pastNotAllowed"))` plus assertion that the default message equals exactly `"Visit date must be today or in the future."`; (4) calls `verify(ownerRepository, never()).save(any())` after the rejection perform; (5) performs a second MockMvc POST to the same path with `date` = `today.toString()` and a valid `description`; (6) asserts a 3xx redirect to `/owners/{ownerId}`; (7) calls `verify(ownerRepository, times(1)).save(any())` (FR-006, R-007, R-008, KPI-1, KPI-2, US1 acceptance scenario 1, US2 acceptance scenario 1)
- [ ] T017 [US4] Re-read `src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java` in full and confirm: (a) the class contains exactly 5 test methods (the 4 unchanged originals plus the new method from T016); (b) no fixed calendar date literal (e.g., `LocalDate.of(...)`) appears in the new method; (c) the four pre-existing test methods are byte-identical to the T002 baseline; (d) no import was removed that the existing tests depend on (FR-006, FR-007, KPI-1, SC-001, R-007)

**Checkpoint**: Test coverage deliverable is complete. KPI-1 and KPI-2 are satisfiable by running `mvn test -pl . -Dtest=VisitControllerTests`.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final scope verification, regression confirmation, and commit hygiene. No new logic is introduced in this phase.

- [ ] T018 [P] Re-read `src/main/java/org/springframework/samples/petclinic/owner/Visit.java` and confirm it is byte-identical to the baseline recorded in T003; specifically confirm the default constructor still sets `this.date = LocalDate.now().plusDays(1)` and no annotation was added to the `date` field (FR-007, FR-012, SC-002, R-012)
- [ ] T019 [P] Re-read `src/main/resources/messages.properties` and `src/main/resources/messages_de.properties` and confirm neither file contains the key `visit.date.pastNotAllowed`; confirm both files are byte-identical to the T004 baseline (FR-003, FR-007, R-006, R-013)
- [ ] T020 Perform a mental `git diff` review: enumerate every file that has been modified and confirm the list is exactly `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` and `src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java`; confirm no template, message bundle, schema file, seed file, Kubernetes manifest, CI configuration, or `pom.xml` was touched (SC-002, FR-007, R-009)
- [ ] T021 Review `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` for `spring-javaformat` compliance: confirm no line exceeds the project's configured line-length limit, imports are ordered correctly, and no trailing whitespace was introduced; the `nohttp` checkstyle rule requires no bare `http://` URLs in source comments — confirm the new comment added in T009 uses no URL (SC-003)
- [ ] T022 Review `src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java` for `spring-javaformat` compliance: confirm the new test method follows the same indentation, brace style, and import ordering as the existing methods in the class (SC-003)

**Checkpoint**: All files verified. The change is ready for commit as a single commit touching only the two permitted files.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user-story phases
- **US1 (Phase 3)**: Depends on Phase 2 — implements the core rejection rule in `VisitController.java`
- **US2 (Phase 4)**: Depends on Phase 3 being stable (both edits land in the same method and file) — implements `minVisitDate` change and confirms success path
- **US3 (Phase 5)**: Depends on Phase 3 (null guard must be in place before it can be verified) — read-only verification; no new edits
- **US4 (Phase 6)**: Depends on Phases 3 and 4 (the controller behaviour being final before the test is written) — edits `VisitControllerTests.java`
- **Polish (Phase 7)**: Depends on all prior phases — final verification only

### User Story Dependencies

- **US1 (P1)**: Depends only on Foundational phase — no dependency on other stories
- **US2 (P1)**: Depends on US1 being stable (both touch `processNewVisitForm` and `initNewVisitForm` in the same file; sequential editing avoids conflicts)
- **US3 (P2)**: Depends on US1 (null guard must exist to verify); no new edits — can be verified immediately after US1
- **US4 (P2)**: Depends on US1 and US2 being complete (test asserts the final controller behaviour)

### Within Each User Story

- Implementation edits before verification re-reads
- `VisitController.java` edits (US1, US2) before `VisitControllerTests.java` edits (US4)
- No story requires a new class, new file, or new dependency

### Parallel Opportunities

- T001, T002, T003, T004 (Phase 1) can all run in parallel — all are read-only
- T005, T006, T007 (Phase 2) can all run in parallel — all are read-only
- T013 and T014 (Phase 5) can run in parallel — both are read-only verifications of already-written code
- T018 and T019 (Phase 7) can run in parallel — both are read-only verifications of unchanged files
- T021 and T022 (Phase 7) can run in parallel — they target different files

---

## Parallel Example: Phase 1 (Setup)

```
# All four orientation reads can proceed simultaneously:
Task T001: Read VisitController.java — src/main/java/.../owner/VisitController.java
Task T002: Read VisitControllerTests.java — src/test/java/.../owner/VisitControllerTests.java
Task T003: Read Visit.java — src/main/java/.../owner/Visit.java
Task T004: Read messages.properties + messages_de.properties — src/main/resources/
```

## Parallel Example: Phase 7 (Polish)

```
# Scope-verification reads can proceed simultaneously:
Task T018: Verify Visit.java byte-identical — src/main/java/.../owner/Visit.java
Task T019: Verify no pastNotAllowed key — src/main/resources/messages*.properties
# Format checks can proceed simultaneously after T018/T019:
Task T021: spring-javaformat check — src/main/java/.../owner/VisitController.java
Task T022: spring-javaformat check — src/test/java/.../owner/VisitControllerTests.java
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (read-only orientation)
2. Complete Phase 2: Foundational (read-only analysis — identifies insertion points)
3. Complete Phase 3: US1 — insert past-date check in `VisitController.java`
4. **STOP and VALIDATE**: The rejection rule is in place; a manual POST with a past date can be verified against the running application or by reading the code
5. Proceed to US2, US3, US4 in order

### Incremental Delivery

1. Phase 1 + Phase 2 → orientation complete
2. Phase 3 (US1) → past-date rejection live in `VisitController.java`
3. Phase 4 (US2) → today accepted, `minVisitDate` hint corrected
4. Phase 5 (US3) → null/type-mismatch regression confirmed
5. Phase 6 (US4) → test coverage deliverable complete; `mvn test -pl . -Dtest=VisitControllerTests` passes with 5 tests, 0 failures
6. Phase 7 (Polish) → scope verified, format checked, ready to commit

### Single-Developer Sequential Strategy

Because all changes land in exactly two files and the total edit surface is small (one new `if` block, one expression change, one test method replacement), a single developer can complete all phases in one sitting:

1. Read all four baseline files (T001–T004 in parallel)
2. Identify insertion points (T005–T007 in parallel)
3. Edit `VisitController.java`: insert null-guarded `rejectValue` call (T008), add comment (T009), change `minVisitDate` (T011)
4. Verify `VisitController.java` is correct (T010, T012, T013, T014)
5. Edit `VisitControllerTests.java`: remove old test (T015), add new combined test (T016)
6. Verify `VisitControllerTests.java` is correct (T017)
7. Run final cross-cutting checks (T018–T022)
8. Commit as a single commit

---

## Notes

- [P] tasks operate on different files or are read-only and have no write-dependency conflicts
- Every task references the exact file path it targets
- `Visit.java`, all `messages*.properties` files, all templates, all schema/seed files, `pom.xml`, `k8s/`, and `.github/` are read-only or untouched throughout — any edit to these files is a scope violation (SC-002, FR-007)
- The midnight-boundary flake (DEF-8) is an accepted risk; `LocalDate.now()` is computed once per test run in T016 to minimise (not eliminate) it
- The non-English locale gap (DEF-5) is accepted debt; no `messages*.properties` entry is added in this story
- Commit after Phase 7 completes; the `git diff` against the base commit on main MUST list exactly `VisitController.java` and `VisitControllerTests.java`
