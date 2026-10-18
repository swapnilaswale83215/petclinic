---

description: "Task list template for feature implementation"
---

# Tasks: Owner Search Trims Spaces

**Input**: Design documents from `/specs/009-owner-search-trims-spaces-petc-9985d018/`

**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/get-owners.md ✓

**Tests**: Test tasks are included — the feature specification (US3, FR-004, FR-005) explicitly requires a new automated test method as the machine-verifiable proof of the fix (KPI-1).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. This is a minimal-diff feature: under Case A (working assumption) the pull request touches exactly one file (`OwnerControllerTests.java`). Under Case B it touches two files (`OwnerController.java` + `OwnerControllerTests.java`). All code work is gated on the SPEC-APP-6 reproduction record (T001–T002).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)
- Exact file paths are given for every task

## Path Conventions

Single-project Spring Boot monolith. Source paths are relative to the repository root.

- Production code: `src/main/java/org/springframework/samples/petclinic/owner/`
- Test code: `src/test/java/org/springframework/samples/petclinic/owner/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the working environment, record the evidence baseline, and gate all code work on the SPEC-APP-6 reproduction record. No production or test file is modified in this phase.

> **⚠️ GATE**: Tasks T001–T002 MUST be completed and their results recorded before any code task (T003 onward) is started. If T002 does not confirm Case A, stop and return to the G0 owner for a replan.

- [ ] T001 Check out branch `009-owner-search-trims-spaces-petc-9985d018` and confirm the working tree is clean against commit 3266d9f (run `git status` and `git log --oneline -1`); record the exact commit SHA in the pull request description
- [ ] T002 Execute the SPEC-APP-6 reproduction record on current main: (a) run `GET /owners?lastName=Davis` and record owner ids and count; (b) run `GET /owners?lastName=Davis%20` and record owner ids and count; (c) run `GET /owners?lastName=%20Davis` and record owner ids and count; (d) run `GET /owners?lastName=Davis%C2%A0` (U+00A0 probe) and record owner ids and count; (e) run the full test suite (`./mvnw test` or `./gradlew test`) and record the base-commit pass, fail, and skip counts and the CI workflow name; confirm Case A (padded and trimmed results are identical and the controller already contains `String.strip()`) and record the confirmation in the pull request description — **if Case A is NOT confirmed, stop here and escalate to the G0 owner**

**Checkpoint**: Reproduction record complete, Case A confirmed, KPI-2 baseline recorded. Code work may now begin.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Verify the existing test infrastructure compiles and all pre-existing tests pass on the branch before any new code is added. No new file is created; no existing file is modified.

> **⚠️ CRITICAL**: Phase 3 onward cannot begin until this phase is complete.

- [ ] T003 Run the full test suite on the branch (`./mvnw test` or `./gradlew test`) and confirm: (a) all five existing `OwnerControllerTests` methods (`processFindFormByLastName`, `processFindFormIgnoresSurroundingWhitespace`, `processFindFormWithWhitespaceOnlyLastNameReturnsAllOwners`, `processFindFormNoOwnersFound`, `processFindFormRedirectsOutOfBoundsPageToFirstPage`) pass; (b) `ClinicServiceTests` passes; (c) `PetClinicConcurrencyTests` passes; (d) total fail count = 0 and newly skipped count = 0 against the T002 baseline — record the result in the pull request description
- [ ] T004 Open `src/test/java/org/springframework/samples/petclinic/owner/OwnerControllerTests.java` and read the existing class structure: note the `@WebMvcTest` annotation, the mocked `OwnerRepository` field, the existing `@Test` method signatures, the synthetic fixture values used (owner last name "Davis", ids 2 and 4), and the Mockito verification patterns already in use — this reading informs T007 and T008 and must be completed before them

**Checkpoint**: Existing suite green on branch; `OwnerControllerTests` structure understood. User story phases may now begin.

---

## Phase 3: User Story 3 — Automated Regression Proof Added to the Test Suite (Priority: P1) 🎯 MVP

**Goal**: Add one new `@Test` method `processFindFormPaddedTermMatchesTrimmedTermForMultipleOwners` to `OwnerControllerTests` that proves padded "Davis" variants behave identically to "Davis" for a multi-owner result, verifies the repository is called only with the stripped value, and serves as a mutation guard (KPI-1, FR-004, FR-005).

> **Note**: US3 is implemented before US1 and US2 because the test is the primary deliverable under Case A. US1 (the production fix) is only in scope under Case B. US3 and US4 share the same file (`OwnerControllerTests.java`) and are sequenced here to keep all test-file edits together.

**Independent Test**: Run `./mvnw test` (or `./gradlew test`); the new method `processFindFormPaddedTermMatchesTrimmedTermForMultipleOwners` appears in the test report as PASSED. Mockito verifies the repository was called with `"Davis"` for every padded variant and never with a padded value.

### Implementation for User Story 3

- [ ] T005 [US3] In `src/test/java/org/springframework/samples/petclinic/owner/OwnerControllerTests.java`, add a new `@Test` method `processFindFormPaddedTermMatchesTrimmedTermForMultipleOwners` with the following structure: (a) configure the mocked `OwnerRepository` to return a `Page` containing two synthetic `Owner` objects with last name "Davis" (ids 2 and 4, consistent with existing fixtures) when called with argument `"Davis"` and any `Pageable`; (b) perform four `MockMvc` GET requests: `GET /owners?lastName=%20Davis`, `GET /owners?lastName=Davis%20`, `GET /owners?lastName=%20Davis%20`, and `GET /owners?lastName=Davis`; (c) for each request assert: HTTP status 200, view name `owners/ownersList`, model attribute `listOwners` contains both synthetic owners, model attribute `totalItems` equals 2, model attribute `totalPages` equals 1; (d) use `Mockito.verify(ownerRepository, times(4)).findByLastNameStartingWith(eq("Davis"), any(Pageable.class))` to assert the repository was called exactly four times with the stripped argument (one call per request); (e) use `Mockito.verify(ownerRepository, never()).findByLastNameStartingWith(argThat(s -> s != null && !s.strip().equals(s)), any())` to assert no padded value ever reached the repository — **do not modify any existing method**
- [ ] T006 [US3] In `src/test/java/org/springframework/samples/petclinic/owner/OwnerControllerTests.java`, extend the method added in T005 to also assert the out-of-range redirect and no-match paths for padded terms (per E3-S1 and E5-S4): (a) add a `MockMvc` GET request `GET /owners?lastName=Davis%20&page=999` with the mocked repository configured to return a page of two Davis owners; assert HTTP status 302 and `Location` header equals `/owners?page=1&lastName=Davis` with no `%20` or `+` in the `lastName` value; (b) add a `MockMvc` GET request `GET /owners?lastName=Zzz%20` with the mocked repository configured to return an empty page; assert HTTP status 200, view name `owners/findOwners`, and a field error bound to `lastName` with code `notFound`; (c) confirm no existing method is modified and the file compiles cleanly

  > **NEEDS CLARIFICATION**: Whether the out-of-range redirect assertion (step a) and the no-match assertion (step b) belong in the same method as the multi-owner list assertions (T005) or in a separate method. The work plan (E3-S1) states "the same test file" but does not mandate the same method. If the project test style guide (R-008) permits `@ParameterizedTest`, a parameterised approach is equivalent. Use a separate method if the single method becomes too long to read clearly; the constraint is one file, not one method.

- [ ] T007 [US3] Run `./mvnw test` (or `./gradlew test`) and confirm: (a) the new method(s) added in T005–T006 appear in the test report as PASSED; (b) all five pre-existing `OwnerControllerTests` methods still pass; (c) `ClinicServiceTests` and `PetClinicConcurrencyTests` still pass; (d) total fail count = 0 and newly skipped count = 0 against the T002 baseline — record the result in the pull request description

**Checkpoint**: New test method passes. KPI-1 evidence is present. All existing tests still pass (KPI-2 maintained).

---

## Phase 4: User Story 1 — Padded Last-Name Search Returns the Same Results as the Trimmed Term (Priority: P1)

**Goal**: Ensure `OwnerController.processFindForm` strips leading and trailing Unicode whitespace from the `lastName` parameter exactly once, before any branch, so that every padded variant produces the same result as the equivalent trimmed term (FR-001, FR-002, FR-003).

> **⚠️ Case A gate**: Under Case A (confirmed in T002), `OwnerController.java` already contains the `String.strip()` call and this phase consists only of verification tasks (T008–T009). No production file is modified. Under Case B (strip call absent on current main), T008 becomes a code-change task and `OwnerController.java` enters the diff. **Do not proceed to Case B work without G0 owner sign-off.**

**Independent Test**: Open the Find Owners page, submit "Davis " (trailing space) and confirm the result list is identical to submitting "Davis". Also confirm " Davis" and " Davis " return the same list. Delivers full value on its own.

### Implementation for User Story 1 (Case A — verification only)

- [ ] T008 [US1] Open `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` and locate `processFindForm`; confirm that `String.strip()` (not `String.trim()`) is called on the `lastName` value exactly once, at the top of the method, before any branch (repository lookup, single-match redirect, out-of-range redirect, no-match error path); confirm the stripped value is used in all downstream paths including the redirect URL construction; confirm no padded value is passed to `OwnerRepository.findByLastNameStartingWith`; confirm no new log statement, model attribute, redirect parameter, or error message carries the raw padded term — record the line number of the strip call in the pull request description

  > **NEEDS CLARIFICATION (Case B only)**: If T002 revealed that `String.strip()` is absent on current main, add the following line at the top of `processFindForm` in `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java`, before any conditional branch: `owner.setLastName(owner.getLastName() == null ? "" : owner.getLastName().strip());` — use `String.strip()` (not `String.trim()`) to handle U+00A0 and other Unicode whitespace (R-002). Apply the null guard because `owner.getLastName()` may return `null` at method entry (data-model.md null-safety note). Do not add any log statement. This task is a no-op under Case A.

- [ ] T009 [US1] Verify the GET /owners contract is satisfied for all five acceptance scenarios of US1: (a) confirm the test added in T005 covers scenarios 1–3 (trailing space, leading space, both); (b) confirm the existing test `processFindFormIgnoresSurroundingWhitespace` covers scenario 4 (single-match redirect for a padded term); (c) confirm the no-match assertion added in T006 covers scenario 5 (padded no-match returns `notFound` field error); (d) confirm the out-of-range redirect assertion added in T006 covers US2 scenario 1 — record any gap as a NEEDS CLARIFICATION item in the pull request description

**Checkpoint**: US1 acceptance scenarios are all covered by existing or new tests. `OwnerController.java` is absent from the diff under Case A.

---

## Phase 5: User Story 2 — Out-of-Range Page with a Padded Term Redirects Cleanly (Priority: P2)

**Goal**: Confirm that a GET request to `/owners` with a padded `lastName` and an out-of-range `page` redirects to `/owners?page=1&lastName={trimmedLastName}` with no encoded space in the `lastName` parameter (FR-003, US2 acceptance scenarios 1–2).

**Independent Test**: Issue `GET /owners?lastName=Davis%20&page=999` and confirm the redirect `Location` is `/owners?page=1&lastName=Davis` with no `%20` or `+` in the `lastName` parameter.

### Implementation for User Story 2

- [ ] T010 [US2] Confirm that the out-of-range redirect assertion added in T006 covers both US2 acceptance scenarios: (a) `GET /owners?lastName=Davis%20&page=999` → `Location: /owners?page=1&lastName=Davis`; (b) `GET /owners?lastName=%20Davis&page=999` → `Location: /owners?page=1&lastName=Davis`; if either scenario is not yet asserted, add the missing assertion to `src/test/java/org/springframework/samples/petclinic/owner/OwnerControllerTests.java` in the method(s) created in T005–T006 — do not modify any existing method
- [ ] T011 [US2] Confirm that the existing test `processFindFormRedirectsOutOfBoundsPageToFirstPage` still passes unchanged and that its redirect `Location` value uses the trimmed term (no encoded space); record the result in the pull request description

**Checkpoint**: US2 redirect contract verified by automated assertions. No new file created; `OwnerControllerTests.java` is the only modified file.

---

## Phase 6: User Story 4 — All Existing Tests Continue to Pass (Priority: P1)

**Goal**: Confirm that no existing test method in `OwnerControllerTests`, `ClinicServiceTests`, or `PetClinicConcurrencyTests` is broken, modified, or skipped by the change (FR-006, FR-007, KPI-2).

**Independent Test**: Run the full Maven/Gradle test suite; the count of failing and newly skipped tests is zero against the T002 baseline.

### Implementation for User Story 4

- [ ] T012 [US4] Run the full test suite (`./mvnw test` or `./gradlew test`) and confirm: (a) `processFindFormByLastName` passes; (b) `processFindFormIgnoresSurroundingWhitespace` passes; (c) `processFindFormWithWhitespaceOnlyLastNameReturnsAllOwners` passes; (d) `processFindFormNoOwnersFound` passes; (e) `processFindFormRedirectsOutOfBoundsPageToFirstPage` passes; (f) `ClinicServiceTests` passes; (g) `PetClinicConcurrencyTests` passes; (h) total fail count = 0 and newly skipped count = 0 against the T002 baseline — record the full test report summary in the pull request description
- [ ] T013 [US4] Perform the diff review for KPI-2 compliance: (a) run `git diff --name-only` and confirm the changed files are exactly `src/test/java/org/springframework/samples/petclinic/owner/OwnerControllerTests.java` (one file under Case A, two files under Case B); (b) confirm `OwnerRepository.java`, `findOwners.html`, `ownersList.html`, `pom.xml`, `build.gradle`, `application*.properties`, `schema.sql`, `data.sql`, Docker files, and the CI workflow are all absent from the diff; (c) confirm the diff contains no `logger.*`, `System.out`, or `System.err` call; (d) confirm the diff contains no new model attribute referencing the raw padded `lastName` value; (e) confirm the diff uses only synthetic owner values already present in the test class (last name "Davis", ids 2 and 4) — record the diff file list in the pull request description

**Checkpoint**: KPI-2 satisfied. Diff is clean. Pull request is ready for the mutation check.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Mutation guard execution, seed-backed equality check, rollback rehearsal, and pull request finalisation. These steps span all user stories and complete the evidence record required by the spec.

- [ ] T014 Mutation guard (FR-005, E1-S4): locally remove the `String.strip()` call from `src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java` (do not commit); run `./mvnw test` (or `./gradlew test`); confirm the new test method added in T005–T006 FAILS; restore the production file to its original state; confirm `git diff` shows no change to `OwnerController.java`; record the mutation check result (which assertion failed and why) in the pull request description — this is the evidence for FR-005
- [ ] T015 [P] Seed-backed equality check (SPEC-DATA-3, E2-S2): on the running H2 dev profile, issue `GET /owners?lastName=Davis`, `GET /owners?lastName=Davis%20`, and `GET /owners?lastName=%20Davis`; confirm all three return owner ids 2 (Betty Davis) and 4 (Harold Davis) and count = 2; record the result as ids and counts only (no name, address, or telephone) in the pull request description
- [ ] T016 [P] Rollback rehearsal (SPEC-PLAT-3, E4-S3): on a local branch, run `git revert HEAD` (or equivalent); run `./mvnw test`; confirm the suite passes at the base-commit state; confirm no database, schema, configuration, or migration step is required; record the result in the pull request description
- [ ] T017 Run the full CI pipeline on the pull request branch (push to remote and confirm the GitHub Actions workflow runs the format check, checkstyle, and full test suite without any change to the workflow, `pom.xml`, `build.gradle`, Docker files, or `application*.properties`); confirm the new test method is listed as PASSED in the CI test report; confirm KPI-1 (0 owners differ between padded and trimmed results) and KPI-2 (0 failing, 0 newly skipped tests) are both readable from the CI report — record the CI run URL in the pull request description
- [ ] T018 Final pull request description review (SC-003, SC-004, FR-008, FR-009): confirm the description contains: (a) the commit SHA from T001; (b) the SPEC-APP-6 reproduction record from T002; (c) the KPI-2 baseline from T002; (d) the strip call line number from T008; (e) the mutation check result from T014; (f) the seed-backed equality check result from T015; (g) the rollback rehearsal result from T016; (h) the CI run URL from T017; confirm no Owner sensitive field (name, address, telephone) appears anywhere in the description

**Checkpoint**: All evidence recorded. Pull request is ready for G2 approval and merge.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (T001–T002 must confirm Case A) — **BLOCKS all code work**
- **US3 (Phase 3)**: Depends on Phase 2 completion — primary deliverable, implement first
- **US1 (Phase 4)**: Depends on Phase 2 completion — verification only under Case A; may run in parallel with Phase 3 if Case A is confirmed
- **US2 (Phase 5)**: Depends on Phase 3 (T005–T006 must exist before T010 can verify them)
- **US4 (Phase 6)**: Depends on Phases 3–5 (all test additions must be complete before the full-suite run)
- **Polish (Phase 7)**: Depends on Phase 6 (diff must be final before mutation check and CI run)

### User Story Dependencies

- **US3 (P1)**: Can start after Phase 2 — no dependency on other stories — **implement first**
- **US1 (P1)**: Can start after Phase 2 — verification only under Case A — can run in parallel with US3
- **US2 (P2)**: Depends on US3 (T005–T006) for the redirect assertion
- **US4 (P1)**: Depends on US3, US1, US2 — final regression gate

### Within Each User Story

- Read existing code before writing new code (T004 before T005)
- New test method written before mutation check (T005–T006 before T014)
- Full suite run after each addition (T007, T012)
- Diff review after all additions are complete (T013)

### Parallel Opportunities

- T015 (seed-backed equality check) and T016 (rollback rehearsal) can run in parallel after T013
- T008 (Case A verification of `OwnerController.java`) can run in parallel with T005–T006 (test writing) once Phase 2 is complete
- T009 (US1 scenario coverage check) can run in parallel with T010 (US2 redirect assertion) once T006 is complete

---

## Parallel Example: User Story 3 (Primary Deliverable)

```
# After Phase 2 is complete, these can proceed in parallel:

Task T008: Read OwnerController.java and confirm strip() placement
  (src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java)

Task T005: Write processFindFormPaddedTermMatchesTrimmedTermForMultipleOwners
  (src/test/java/org/springframework/samples/petclinic/owner/OwnerControllerTests.java)

# T006 depends on T005 (extends the same method/file):
Task T006: Add redirect and no-match assertions to the new test method
  (src/test/java/org/springframework/samples/petclinic/owner/OwnerControllerTests.java)

# After T005–T006:
Task T007: Run full suite and confirm new method passes + existing methods unchanged

# After T013 (diff finalised):
Task T015: Seed-backed equality check  ← parallel
Task T016: Rollback rehearsal          ← parallel
```

---

## Implementation Strategy

### MVP First (Case A — one file, one test method)

1. Complete Phase 1: Confirm branch and record SPEC-APP-6 reproduction (T001–T002)
2. Complete Phase 2: Verify existing suite is green (T003–T004)
3. Complete Phase 3 (US3): Add the new test method (T005–T007) — **this is the entire deliverable under Case A**
4. **STOP and VALIDATE**: Run the suite; confirm the new method passes and all existing methods pass
5. Complete Phase 4 (US1): Verify `OwnerController.java` already contains `strip()` (T008–T009) — no code change under Case A
6. Complete Phase 5 (US2): Verify redirect assertions are present (T010–T011)
7. Complete Phase 6 (US4): Full regression gate (T012–T013)
8. Complete Phase 7: Mutation check, seed check, rollback, CI, PR description (T014–T018)
9. Submit pull request for G2 approval

### Case B Contingency (strip call absent — requires G0 sign-off before proceeding)

1. Complete Phase 1–2 as above
2. Add `String.strip()` call to `OwnerController.processFindForm` (T008, Case B path)
3. Complete Phase 3 (US3): Add the new test method (T005–T007)
4. Complete Phases 4–7 as above
5. Diff will contain two files: `OwnerController.java` + `OwnerControllerTests.java`

### Single-Contributor Execution Order (sequential)

T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010 → T011 → T012 → T013 → T014 → T015 → T016 → T017 → T018

---

## Notes

- **[P]** tasks operate on different files or are read-only checks with no file conflicts
- **[Story]** label maps each task to its user story for traceability against spec.md acceptance scenarios
- **Case A is the working assumption**: `OwnerController.java` is NOT modified and NOT in the diff. T008 is a read-only verification under Case A.
- **String.strip() is mandatory** (not `String.trim()`) — handles U+00A0 and all Unicode whitespace (R-002)
- **Null guard required** if `owner.getLastName()` can return `null` at `processFindForm` entry — see data-model.md null-safety note
- **Sensitive data**: the new test uses only synthetic values (last name "Davis", ids 2 and 4) already present in the test class; no real owner name, address, or telephone is introduced anywhere
- **One file in the diff** under Case A (`OwnerControllerTests.java`); two files under Case B (`OwnerController.java` + `OwnerControllerTests.java`); zero files outside this set
- **Do not modify any existing test method** — T005 and T006 add new method(s) only
- Commit after T007 (new test passes), after T013 (diff verified), and after T014 (mutation check complete and production file restored)
- Stop at the T007 checkpoint to validate the new test independently before proceeding to the regression gate
