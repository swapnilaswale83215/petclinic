# Feature Specification: Owner Search Trims Spaces

**Feature Branch**: `009-owner-search-trims-spaces-petc-9985d018`

**Created**: 2026-10-18

**Status**: Draft

**Input**: User description: "Owner search by last name ignores leading and trailing spaces: searching 'Davis ' on the Find Owners page returns exactly what 'Davis' returns."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Padded last-name search returns the same results as the trimmed term (Priority: P1)

A clinic receptionist copies an owner's last name from another document and pastes it into the Find Owners search box. The pasted value carries a trailing space (e.g., "Davis "). Today the search returns no results, leaving the receptionist to believe the owner does not exist. After this change, the application silently discards the surrounding whitespace and returns the same owner list that "Davis" returns.

**Why this priority**: This is the sole defect being fixed (PETC-8). Every other story depends on this behaviour being correct. Without it the feature has no value.

**Independent Test**: Open the Find Owners page, submit "Davis " (trailing space) and confirm the result list is identical to submitting "Davis". Delivers full value on its own.

**Acceptance Scenarios**:

1. **Given** the Find Owners page is displayed and the seed data contains owners Betty Davis (id 2) and Harold Davis (id 4), **When** the receptionist submits the search term "Davis " (one trailing space), **Then** the results page shows both Davis owners — the same list, order and total count as a search for "Davis".
2. **Given** the Find Owners page is displayed, **When** the receptionist submits " Davis" (one leading space), **Then** the results page shows the same owners as "Davis".
3. **Given** the Find Owners page is displayed, **When** the receptionist submits " Davis " (leading and trailing spaces), **Then** the results page shows the same owners as "Davis".
4. **Given** the Find Owners page is displayed and the search term after trimming matches exactly one owner (e.g., " Jean" trimming to "Jean" with a single match), **When** the form is submitted, **Then** the browser is redirected to that owner's detail page, identical to submitting the trimmed term directly.
5. **Given** the Find Owners page is displayed and the search term after trimming matches no owner, **When** the form is submitted with a padded term (e.g., "Zzz "), **Then** the form re-renders with the "not found" field error on lastName, identical to submitting "Zzz".

---

### User Story 2 — Out-of-range page with a padded term redirects cleanly (Priority: P2)

A receptionist navigates to a bookmarked URL that includes a padded lastName parameter and a page number beyond the available range. The redirect must strip the padding from the lastName value so the resulting URL is clean and consistent with the trimmed-term redirect.

**Why this priority**: Correctness of the redirect URL is a must-not-break constraint and a security concern (no encoded spaces in the Location header). It is secondary to the basic search fix but must be verified in the same pull request.

**Independent Test**: Issue GET /owners?lastName=Davis%20&page=999 and confirm the redirect Location is /owners?page=1&lastName=Davis with no encoded space.

**Acceptance Scenarios**:

1. **Given** a GET request to /owners with lastName="Davis " (encoded as Davis%20) and a page number beyond the last page, **When** the controller processes the request, **Then** the response is a redirect to /owners?page=1&lastName=Davis with no leading or trailing space and no encoded space (%20 or +) in the lastName parameter.
2. **Given** a GET request to /owners with lastName=" Davis" (encoded as %20Davis) and an out-of-range page, **When** the controller processes the request, **Then** the redirect Location is /owners?page=1&lastName=Davis.

---

### User Story 3 — Automated regression proof added to the test suite (Priority: P1)

A developer adds one new test method to OwnerControllerTests that proves the padded "Davis" variants behave identically to "Davis" for a multi-owner result. This test is the machine-verifiable evidence for KPI-1 and must pass in CI on the pull request and on main after merge.

**Why this priority**: The approved brief requires a new automated test as the proof of the fix. Without it KPI-1 cannot be measured and the pull request cannot be accepted.

**Independent Test**: Run the test suite; the new method appears in the report as passed. The mocked repository is called with exactly "Davis" (stripped) for every padded variant.

**Acceptance Scenarios**:

1. **Given** the OwnerControllerTests class with a mocked OwnerRepository that returns two Davis owners for the argument "Davis", **When** the new test method submits GET /owners?lastName=Davis%20, GET /owners?lastName=%20Davis and GET /owners?lastName=%20Davis%20, **Then** each call renders owners/ownersList, the model contains the same listOwners, totalItems and totalPages as the "Davis" call, and Mockito verifies exactly four invocations of findByLastNameStartingWith with the argument "Davis" and zero invocations with any padded value.
2. **Given** the new test method exists, **When** String.strip() (or equivalent trimming) is temporarily removed from the production code locally, **Then** the new test fails — confirming it is a genuine mutation guard. This result is recorded in the pull request description.
3. **Given** the full CI run on the pull request, **When** all tests execute, **Then** the new method is listed as passed and no existing test method is modified, removed or disabled.

---

### User Story 4 — All existing tests continue to pass (Priority: P1)

No existing test method in OwnerControllerTests, ClinicServiceTests or PetClinicConcurrencyTests is broken, modified or skipped by the change.

**Why this priority**: KPI-2 requires 100 % pass rate. Regressions in any of these suites block merge.

**Independent Test**: Run the full Maven/Gradle test suite; the count of failing and newly skipped tests is zero against the base-commit count.

**Acceptance Scenarios**:

1. **Given** the full test suite at the base commit, **When** the pull request is applied and the suite is run, **Then** the count of failing tests is 0 and the count of newly skipped tests is 0.
2. **Given** the existing OwnerControllerTests methods processFindFormByLastName, processFindFormIgnoresSurroundingWhitespace, processFindFormWithWhitespaceOnlyLastNameReturnsAllOwners, processFindFormNoOwnersFound and processFindFormRedirectsOutOfBoundsPageToFirstPage, **When** the suite runs, **Then** all five methods pass without modification.
3. **Given** ClinicServiceTests and PetClinicConcurrencyTests, **When** the suite runs, **Then** both pass unchanged, confirming that OwnerRepository.findByLastNameStartingWith is unmodified.

---

### Edge Cases

- What happens when the search term is whitespace only (e.g., a single space or multiple spaces)? After trimming the term becomes an empty string; the controller must treat this the same as a blank search and return all owners, paginated at 5 per page — identical to today's behaviour for a blank lastName.
- What happens when the search term contains inner whitespace (e.g., "De La Cruz")? Inner whitespace is not touched; only leading and trailing whitespace is removed. "De La Cruz " trims to "De La Cruz" and the prefix match proceeds normally.
- What happens when the search term contains a non-breaking space (U+00A0, encoded as %C2%A0)? String.strip() removes Unicode whitespace including U+00A0. If the cached controller already calls strip() and the reproduction on current main confirms Case A, this is handled automatically. If the reproduction reveals a different cause (Case C), the design must return to the G0 owner before G1 is signed (see SPEC-APP-6). [NEEDS CLARIFICATION: The reproduction on current main (SPEC-APP-6) has not yet been completed. If the padded and trimmed results differ on current main, the root cause may not be String.strip() and the pull request content changes. This spec is conditional on Case A being confirmed by the reproduction record.]
- What happens when the page size or pagination logic changes? Page size is fixed at 5 and is out of scope; this edge case is a must-not-break constraint, not a new behaviour.
- What happens when no owners exist in the database? The search returns an empty result and the "not found" field error is shown, regardless of padding — same as today.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001** (SPEC-APP-1): The controller MUST remove leading and trailing whitespace from the lastName search term exactly once, before the repository lookup and before the out-of-range redirect is constructed. A search for a padded term MUST return the same owners, view or redirect as the equivalent trimmed term.
- **FR-002** (SPEC-APP-1): GET /owners with lastName values " Davis", "Davis " and " Davis " MUST each invoke the owner lookup with the argument "Davis" (no surrounding whitespace). No padded value MUST ever reach the repository.
- **FR-003** (SPEC-APP-1, SPEC-INT-1): The out-of-range redirect for a padded term MUST use the trimmed lastName value in the Location URL. The redirect target MUST be /owners?page=1&lastName=Davis with no encoded space (%20 or +) in the lastName parameter.
- **FR-004** (SPEC-APP-2): One new test method MUST be added to OwnerControllerTests. It MUST use a mocked repository that returns two or more Davis owners, submit the three padded variants and the trimmed term, and verify that the repository is called with "Davis" for every variant and never with a padded value.
- **FR-005** (SPEC-APP-2): The new test method MUST serve as a mutation guard: with the trimming logic temporarily removed, the test MUST fail. The pull request description MUST record this result.
- **FR-006** (SPEC-APP-3, SPEC-INT-2): The /owners URL, the lastName and page query parameters, the page size of 5, the "notFound" field error on an empty result, the single-match redirect to /owners/{id} and the list rendering for a blank search MUST all behave exactly as they do today.
- **FR-007** (SPEC-APP-4, SPEC-DATA-2, SPEC-INT-3): OwnerRepository.findByLastNameStartingWith MUST NOT be modified. Its signature, semantics and callers (ClinicServiceTests, PetClinicConcurrencyTests) MUST remain unchanged.
- **FR-008** (SPEC-APP-5, SPEC-SEC-1): The pull request MUST NOT add any log statement, model attribute or error text that carries the search term or any Owner sensitive field (name, address, telephone). The new test MUST use only synthetic owner values already present in the test class.
- **FR-009** (SPEC-APP-5, SPEC-SEC-3, SPEC-PLAT-1): The pull request diff MUST be limited to OwnerControllerTests.java (and OwnerController.java only if Case B applies after the reproduction). It MUST NOT touch findOwners.html, ownersList.html, pom.xml, build.gradle, application*.properties, schema.sql, data.sql, Docker files or the CI workflow.
- **FR-010** (SPEC-APP-6): Before G1 is signed, the team MUST attach a reproduction record on current main that states: the commit SHA tested; the owner ids and count for lastName=Davis; the same for lastName=Davis%20 and lastName=%20Davis; the result for lastName=Davis%C2%A0 (U+00A0 probe); and the base-commit suite pass/fail count as the KPI-2 baseline. Case A is confirmed only if the padded and trimmed results are identical and the controller on that SHA already contains the strip call.
- **FR-011** (SPEC-DATA-3): The number of owners that differ between the result for any padded variant and the result for "Davis" MUST be 0 on the H2 seed, where "Davis" matches owner ids 2 (Betty Davis) and 4 (Harold Davis).
- **FR-012** (SPEC-PLAT-1): The existing CI workflow MUST build and test the pull request without any change to the pipeline, build files or deployment files. The validate-phase format and checkstyle checks MUST pass.

### Key Entities

- **Owner**: A registered pet guardian. Relevant attributes for this feature: last name (used as the prefix-match search term), id (used to identify search results and construct the single-match redirect URL). The name field is a sensitive zone; it MUST NOT appear in logs or new model attributes introduced by this change.
- **OwnerController.processFindForm**: The single application entry point for the owner search. It receives the raw lastName parameter, trims it, calls the repository, and decides between the list view, the single-match redirect and the out-of-range redirect. This is the only production component in scope.
- **OwnerRepository.findByLastNameStartingWith**: The read-only derived Spring Data JPA query that performs the prefix match. It receives the already-trimmed term from the controller. It is out of scope for modification.
- **OwnerControllerTests**: The @WebMvcTest test class with a mocked OwnerRepository. The new test method is added here. No existing method is modified.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **KPI-1** (SC-001): The number of owners that differ between the result for a padded search term (e.g., "Davis " or " Davis") and the result for the trimmed term ("Davis") is **0**. This is proven by the new automated test method in OwnerControllerTests, which MUST pass in CI on the pull request and on main after merge.
- **KPI-2** (SC-002): The count of existing tests that fail or are newly skipped after the change is applied is **0**. The overall test pass rate remains **100 %** against the base-commit count.
- **SC-003**: The pull request diff contains at most two files (OwnerControllerTests.java, and OwnerController.java only if the Case A reproduction reveals that the strip call is absent on current main). Zero files outside this set are modified.
- **SC-004**: No Owner sensitive field (name, address, telephone) appears in any new log statement, model attribute, redirect parameter or error message introduced by the change, as verified by diff review at pull request time.
- **SC-005**: After the change is deployed, a smoke check confirms that GET /owners?lastName=Davis%20 and GET /owners?lastName=Davis return the same owners on page 1 in the running application.

## Assumptions

- **Case A is the working assumption**: The cached OwnerController at commit 3266d9f already calls String.strip() on the lastName before the repository lookup. The pull request is therefore expected to consist of the new test only, with no production code change. This assumption is conditional on the reproduction record (SPEC-APP-6) confirming that padded and trimmed results are identical on current main. If the reproduction contradicts Case A, the design must return to the G0 owner before G1 is signed and this spec will be revised.
- **H2 seed data**: The development and CI seed data contains exactly two owners with the last name "Davis": Betty Davis (id 2) and Harold Davis (id 4). The new test relies on this or an equivalent synthetic fixture in the mock.
- **String.strip() semantics**: The trimming call removes all leading and trailing Unicode whitespace, including U+00A0 (non-breaking space). Inner whitespace (e.g., spaces within a compound last name) is not affected. If the U+00A0 probe in SPEC-APP-6 reveals a difference, this assumption is invalidated and the design must be revisited.
- **Single pull request, single contributor**: The repository has one active contributor (swapnilaswale83215), who is both the author and the reviewer of the pull request. The pull request is small by design (one file changed under Case A).
- **No authentication or authorisation change**: The /owners endpoint is currently unauthenticated. This is a pre-existing condition accepted as residual risk (ADR-SEC-2) and is not addressed by this change.
- **No database, schema, API, configuration or deployment change**: The fix is entirely within application code. The H2 seed, the MySQL and PostgreSQL schemas, the CI workflow and all deployment artefacts are untouched.
- **Existing OwnerControllerTests coverage**: The test class already contains processFindFormIgnoresSurroundingWhitespace and processFindFormWithWhitespaceOnlyLastNameReturnsAllOwners, which cover single-match and whitespace-only cases. The new test covers the multi-owner (list) case, which is the gap identified in the brief.
- **Template and form unchanged**: findOwners.html and ownersList.html are not modified. The form field, the model attributes and the pagination links remain as they are today.
- **Rollback is a code revert**: Because no data, schema or configuration changes, the release can be reversed by reverting the merge commit and redeploying through the existing pipeline, with no additional steps.
