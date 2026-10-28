---

description: "Task list template for feature implementation"
---

# Tasks: Reject Past Visit Dates

**Input**: Design documents from `/specs/010-reject-past-visit-dates-15ab17d7/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/visit-form-post.md

**Tests**: Test tasks are included because User Story 4 (P2) is explicitly a deliverable test story and FR-006 mandates a specific JUnit test replacement.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. Because FR-007 restricts all changes to exactly two files (`VisitController.java` and `VisitControllerTests.java`), there is no Setup or Foundational infrastructure work; all tasks are either controller implementation or test implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Single-project Maven layout. All source under `src/main/java` and `src/test/java`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the working environment and read the live files that the NC items flag as unverified before writing any code. No files are created or modified in this phase.

- [ ] T001 Read the live source of `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` on main and record: exact signature of `processNewVisitForm`, exact current expression for `minVisitDate` in `initNewVisitForm`, exact structure of the `result.hasErrors()` guard, and exact body of the `@InitBinder` method (resolves NC-1)
- [ ] T002 Read the live source of `src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java` on main and record: exact name of the test to be replaced (`processNewVisitFormHasErrorsWhenVisitDateIsNotInFuture`), its mock setup (`given(owners.findById(...)).willReturn(...)`), and the configuration shared by all five tests in the class (resolves NC-2)
- [ ] T003 Read the live source of `src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java` and confirm the total number of test methods is currently 4 (so that adding the replacement brings the count to 5 as required by KPI-1) — record the four existing method names
- [ ] T004 Read `src/test/java/org/springframework/samples/petclinic/I18nPropertiesSyncTest.java` (or its equivalent path) and confirm whether it scans Java source for error-code strings or only checks Thymeleaf template `#{...}` key references against `messages*.properties` files; record the conclusion (resolves NC-4)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: There are no new classes, packages, schema files, or configuration files to create. The only foundational prerequisite is confirming that the two permitted files compile cleanly on main before any edit, so that any subsequent compile failure is attributable to the change.

**⚠️ CRITICAL**: Confirm the baseline before editing either file.

- [ ] T005 Run `./mvnw test -pl . -Dtest=VisitControllerTests` on unmodified main and confirm the current test count and pass/fail state; record the surefire output as the baseline (resolves NC-3 and establishes KPI-1 baseline)
- [ ] T006 Run `./mvnw validate` on unmodified main and confirm `spring-javaformat:validate` and `nohttp` checkstyle both pass with zero violations (establishes SC-003 baseline)

**Checkpoint**: Baseline confirmed — user story implementation can now begin.

---

## Phase 3: User Story 1 — Clinic Staff Submits a Visit with a Past Date (Priority: P1) 🎯 MVP

**Goal**: `VisitController.processNewVisitForm` rejects any POST whose `date` is before `LocalDate.now()`, returns HTTP 200 with the form view `pets/createOrUpdateVisitForm`, registers a `BindingResult` field error on `"date"` with error code `visit.date.pastNotAllowed` and default message `"Visit date must be today or in the future."`, and does not call `OwnerRepository.save`.

**Independent Test**: POST a date of `LocalDate.now().minusDays(1)` to `/owners/{ownerId}/pets/{petId}/visits/new` and assert HTTP 200, view `pets/createOrUpdateVisitForm`, a field error on `date` with default message exactly `"Visit date must be today or in the future."`, and `verify(owners, never()).save(any())`.

### Implementation for User Story 1

- [ ] T007 [US1] In `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java`, insert the null-guarded past-date check immediately before the `result.hasErrors()` guard in `processNewVisitForm`: `if (visit.getDate() != null && visit.getDate().isBefore(LocalDate.now())) { result.rejectValue("date", "visit.date.pastNotAllowed", "Visit date must be today or in the future."); }` — the string literal `"Visit date must be today or in the future."` MUST be a compile-time constant with no concatenation of request data (FR-003, FR-008)
- [ ] T008 [US1] In `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java`, add a code comment immediately above the `LocalDate.now()` call in `processNewVisitForm` stating: `// "Today" is defined as LocalDate.now() using the JVM default time zone. No explicit ZoneId is specified; the boundary at midnight is therefore determined by the server's JVM time zone.` (research.md §6, spec assumptions)
- [ ] T009 [US1] Verify in `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` that the `@InitBinder` method's `setDisallowedFields` (or `setAllowedFields`) body is byte-identical to main after the edit — make no change to it (FR-009)
- [ ] T010 [US1] Run `./mvnw validate` on the edited `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` and confirm `spring-javaformat:validate` and `nohttp` checkstyle pass with zero new violations (SC-003)

**Checkpoint**: At this point, the server-side past-date rejection rule is in place. User Story 1 can be verified by running the test added in Phase 6 (US4) or by a manual POST with a past date.

---

## Phase 4: User Story 2 — Clinic Staff Submits a Visit with Today's Date (Priority: P1)

**Goal**: `VisitController.processNewVisitForm` accepts a POST whose `date` equals `LocalDate.now()` (or any future date), calls `OwnerRepository.save(owner)` exactly once, and redirects to `redirect:/owners/{ownerId}`. The `minVisitDate` model attribute on GET equals `LocalDate.now()` so the form hint matches the server rule.

**Independent Test**: POST `LocalDate.now()` with a valid description to `/owners/{ownerId}/pets/{petId}/visits/new` and assert a 3xx redirect to `/owners/{ownerId}` and `verify(owners, times(1)).save(any())`. Also GET the form and assert `minVisitDate` equals `LocalDate.now()`.

### Implementation for User Story 2

- [ ] T011 [US2] In `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java`, change the `minVisitDate` model attribute value in `initNewVisitForm` from `LocalDate.now().plusDays(1)` to `LocalDate.now()` (FR-005, research.md §5, data-model.md §VisitController model attributes)
- [ ] T012 [US2] Confirm in `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` that the success path in `processNewVisitForm` (the `else` / fall-through after `result.hasErrors()`) is unchanged: `OwnerRepository.save(owner)` is called exactly once and the method returns `"redirect:/owners/{ownerId}"` (FR-002, FR-010)
- [ ] T013 [US2] Confirm that no change has been made to `src/main/resources/templates/pets/createOrUpdateVisitForm.html` — the template already reads the `minVisitDate` attribute and will reflect the updated value without a template edit (FR-007, spec assumptions)
- [ ] T014 [US2] Run `./mvnw validate` on the edited `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` and confirm `spring-javaformat:validate` and `nohttp` checkstyle pass with zero new violations (SC-003)

**Checkpoint**: At this point, today's date is accepted and the form hint matches the server rule. User Story 2 can be verified by the test added in Phase 6 (US4) or by a manual POST with today's date.

---

## Phase 5: User Story 3 — Clinic Staff Submits a Visit with a Missing or Unparseable Date (Priority: P2)

**Goal**: The new past-date check does not interfere with the existing blank-date or type-mismatch behaviour. A blank or unparseable date still produces the existing binding error; the error code `visit.date.pastNotAllowed` is absent in those cases.

**Independent Test**: POST a blank `date` field and assert HTTP 200, the form view, a field error on `date` from the existing required-field constraint, and the absence of error code `visit.date.pastNotAllowed`. POST a non-date string and assert the same absence of the new error code.

### Implementation for User Story 3

- [ ] T015 [US3] In `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java`, confirm that the null guard `visit.getDate() != null` in the past-date check (added in T007) is present and correctly short-circuits when `visit.getDate()` is null, so that the new error code is never emitted for a blank or unparseable date (FR-004, research.md §4, spec edge cases)
- [ ] T016 [US3] Confirm in `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` that the past-date check is positioned before `result.hasErrors()` and that no change has been made to the binding layer or to any `@InitBinder` configuration that would alter the existing blank/type-mismatch error behaviour (FR-004, FR-008, FR-009)
- [ ] T017 [US3] Confirm that `src/main/resources/messages.properties` and all `src/main/resources/messages_*.properties` files are byte-identical to main — no new key has been added (FR-003, FR-007)

**Checkpoint**: At this point, the existing null/type-mismatch error path is confirmed unbroken. User Story 3 regression safety is verified.

---

## Phase 6: User Story 4 — Automated Test Coverage Confirms Both Outcomes (Priority: P2)

**Goal**: One JUnit test in `VisitControllerTests` posts yesterday's date and asserts rejection (exact message, no save), then posts today's date and asserts acceptance (3xx redirect, save called once). The replaced test uses `LocalDate.now()` computed at test runtime with no fixed calendar dates. The four other existing tests are unchanged and still pass. The surefire report shows 5 tests, 0 failures, 0 errors.

**Independent Test**: Run `./mvnw test -pl . -Dtest=VisitControllerTests` and read the surefire report: 5 tests, 0 failures, 0 errors. The replacement test asserts the exact string `"Visit date must be today or in the future."` from `BindingResult`.

### Implementation for User Story 4

- [ ] T018 [US4] In `src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java`, remove the existing test method `processNewVisitFormHasErrorsWhenVisitDateIsNotInFuture` entirely (FR-006, research.md §7, KPI-1)
- [ ] T019 [US4] In `src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java`, add a new test method (replacing the one removed in T018) that: (a) computes `LocalDate today = LocalDate.now()` and `LocalDate yesterday = today.minusDays(1)` once at the start of the method; (b) performs a MockMvc POST with `date` set to `yesterday` and a valid `description`, asserts HTTP 200, view name `pets/createOrUpdateVisitForm`, a field error on `"date"` whose default message is exactly `"Visit date must be today or in the future."`, and `verify(owners, never()).save(any())`; (c) performs a MockMvc POST with `date` set to `today` and a valid `description`, asserts a 3xx redirect to `/owners/{ownerId}`, and `verify(owners, times(1)).save(any())` — the method MUST NOT use any fixed calendar date literal (FR-006, research.md §7, KPI-1, KPI-2)
- [ ] T020 [US4] In `src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java`, confirm that the mock setup used by the new test (e.g., `given(owners.findById(...)).willReturn(...)`) is consistent with the shared mock configuration recorded in T002, so that the other four existing test methods are unaffected (research.md §7, SC-001)
- [ ] T021 [US4] Run `./mvnw test -pl . -Dtest=VisitControllerTests` and confirm the surefire report shows exactly 5 tests, 0 failures, 0 errors, and that the new test's assertion on the exact string `"Visit date must be today or in the future."` passes (KPI-1, KPI-2)
- [ ] T022 [US4] Run `./mvnw validate` on the edited `src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java` and confirm `spring-javaformat:validate` and `nohttp` checkstyle pass with zero new violations (SC-003)

**Checkpoint**: At this point, both the controller change and the test replacement are complete. The surefire report confirms both KPIs.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Full-suite regression check, diff-scope verification, and rollback documentation.

- [ ] T023 Run `./mvnw test` (full suite) and confirm that `ClinicServiceTests`, `PetClinicIntegrationTests`, `OwnerControllerTests`, `PetControllerTests`, and `I18nPropertiesSyncTest` all pass with no assertion edits to any file other than `VisitControllerTests.java` (SC-001, KPI-1)
- [ ] T024 Run `git diff --name-only origin/main` and confirm the output is exactly two lines: `src/main/java/org/springframework/samples/petclinic/owner/VisitController.java` and `src/test/java/org/springframework/samples/petclinic/owner/VisitControllerTests.java` — no other file appears (SC-002, FR-007)
- [ ] T025 Confirm `src/main/java/org/springframework/samples/petclinic/owner/Visit.java` is byte-identical to main by running `git diff src/main/java/org/springframework/samples/petclinic/owner/Visit.java` and asserting empty output (FR-007)
- [ ] T026 Run the quickstart.md validation scenario 5 (optional manual smoke test): `./mvnw spring-boot:run`, navigate to any owner → pet → "Add Visit", enter a past date and confirm the message "Visit date must be today or in the future." is displayed, then enter today's date and confirm redirect to the owner detail page with the visit in history (quickstart.md §Validation scenario 5)
- [ ] T027 Record in the commit message or story description: the three behaviour changes (error code `visit.date.pastNotAllowed` added, exact error text `"Visit date must be today or in the future."`, today's date now accepted), and the rollback procedure (`git revert <commit-sha>` followed by redeploy; no schema migration to reverse) (SC-002, plan.md §E1-S1 accepted-when criteria)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately; read-only file inspection
- **Foundational (Phase 2)**: Depends on Phase 1 completion — establishes baseline before any edit
- **US1 (Phase 3)**: Depends on Phase 2 — edits `VisitController.java` (past-date check)
- **US2 (Phase 4)**: Depends on Phase 2 — edits `VisitController.java` (`minVisitDate`); can run in parallel with Phase 3 because both edits are in the same file and must be sequenced within that file
- **US3 (Phase 5)**: Depends on Phase 3 completion — confirms null-guard behaviour introduced in T007
- **US4 (Phase 6)**: Depends on Phase 3 and Phase 4 completion — the replacement test asserts both rejection (US1) and acceptance (US2)
- **Polish (Phase 7)**: Depends on all prior phases complete

### User Story Dependencies

- **US1 (P1)**: Can start after Foundational (Phase 2) — no dependency on other stories
- **US2 (P1)**: Can start after Foundational (Phase 2) — the `minVisitDate` edit is independent of the past-date check edit within the same file; sequence the two edits within `VisitController.java` to avoid conflicts
- **US3 (P2)**: Depends on US1 (Phase 3) — verifies the null-guard introduced in T007
- **US4 (P2)**: Depends on US1 and US2 — the replacement test covers both rejection and acceptance

### Within Each User Story

- Read live files (Phase 1) before any edit
- Confirm baseline (Phase 2) before any edit
- Controller edits (US1, US2) before test edits (US4)
- Null-guard confirmation (US3) after controller edit (US1)
- Full-suite run (Phase 7) after all edits

### Parallel Opportunities

- T001, T002, T003, T004 (Phase 1) can all run in parallel — all are read-only
- T005 and T006 (Phase 2) can run in parallel — independent Maven invocations
- T007 and T011 are both edits to `VisitController.java`; they MUST be sequenced (same file) — apply both edits before running any validation
- T010 and T014 (checkstyle runs on `VisitController.java`) should be combined into a single `./mvnw validate` after both T007 and T011 are applied
- T018, T019, T020 are all edits to `VisitControllerTests.java`; they MUST be sequenced (same file)
- T023, T024, T025 (Phase 7 verification tasks) can run in parallel after all edits are complete

---

## Parallel Example: Phase 1 (Setup)

```
# All four read-only inspection tasks can run simultaneously:
Task T001: Read VisitController.java on main
Task T002: Read VisitControllerTests.java on main (mock setup)
Task T003: Read VisitControllerTests.java on main (test count)
Task T004: Read I18nPropertiesSyncTest.java on main
```

## Parallel Example: Phase 7 (Polish)

```
# After all edits are committed, these verification tasks can run simultaneously:
Task T023: ./mvnw test  (full suite)
Task T024: git diff --name-only origin/main  (diff scope)
Task T025: git diff src/.../Visit.java  (byte-identical check)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (read live files)
2. Complete Phase 2: Foundational (confirm baseline)
3. Complete Phase 3: User Story 1 (past-date check in controller)
4. **STOP and VALIDATE**: POST a past date manually or via a quick MockMvc test and confirm HTTP 200 + error message + no save
5. Proceed to US2, US3, US4

### Incremental Delivery

1. Complete Setup + Foundational → baseline confirmed
2. Apply US1 controller edit → past-date rejection in place
3. Apply US2 controller edit → today accepted, `minVisitDate` updated
4. Confirm US3 null-guard → existing blank/type-mismatch path unbroken
5. Replace test (US4) → machine-readable proof of both KPIs
6. Polish phase → full suite green, diff scope confirmed, commit message written

### Single-Developer Sequence (recommended)

Because FR-007 restricts all changes to exactly two files, parallel team execution offers no benefit. The recommended sequence is strictly linear:

1. T001 → T002 → T003 → T004 (read live files)
2. T005 → T006 (confirm baseline)
3. T007 → T008 → T009 (US1 controller edits)
4. T011 → T012 → T013 (US2 controller edits)
5. T010 / T014 combined: `./mvnw validate` on `VisitController.java`
6. T015 → T016 → T017 (US3 confirmation)
7. T018 → T019 → T020 (US4 test replacement)
8. T021 → T022 (US4 surefire + checkstyle)
9. T023 → T024 → T025 → T026 → T027 (Polish)

---

## Notes

- **Two-file constraint is absolute**: FR-007 and SC-002 prohibit any change outside `VisitController.java` and `VisitControllerTests.java`. If any task appears to require a third file, stop and re-read the spec before proceeding.
- **Exact error message is a hard requirement**: The string `"Visit date must be today or in the future."` must appear verbatim as a compile-time constant in `VisitController.java`. Do not externalise it to a properties file, do not concatenate request data into it.
- **Error code `visit.date.pastNotAllowed` must not be used for type-mismatch**: FR-004 reserves the existing type-mismatch error code for genuinely unparseable dates. The new code applies only to non-null, parseable, past dates.
- **`LocalDate.now()` no-arg form**: Use the no-arg form throughout (controller and test). Do not introduce a `ZoneId` argument or an injectable `Clock` — both are out of scope per the plan's risk register.
- **Test count is exactly 5**: Replacing one test (not adding one) keeps the count at 5. If the baseline count recorded in T003 is not 4, stop and investigate before proceeding with T018.
- **NC-4 residual**: If T004 reveals that `I18nPropertiesSyncTest` scans Java source for error-code strings, the implementer must assess whether `visit.date.pastNotAllowed` appearing in `VisitController.java` will cause a failure. The expected outcome (per research.md §8) is that no action is required, but this must be confirmed before committing.
- **`[P]` tasks**: Tasks marked `[P]` in Phases 1 and 7 can run in parallel. Tasks in Phases 3–6 that edit the same file must be sequenced within that file even when they belong to different user stories.
- Commit after all edits are complete and all verification tasks pass — deliver as a single commit per SC-002.
