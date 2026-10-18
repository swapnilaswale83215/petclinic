# research.md

**Feature**: Owner Search Trims Spaces
**Branch**: `009-owner-search-trims-spaces-petc-9985d018`
**Date**: 2026-10-18
**Phase**: 0 — Research & Unknowns Resolution

---

## R-001 — Root cause: does the current main controller already call String.strip()?

**Decision**: NEEDS CLARIFICATION (Case A unconfirmed)

**Rationale**: The spec names this "Case A" and treats it as the working assumption: the cached OwnerController at commit 3266d9f already calls `String.strip()` on the `lastName` parameter before the repository lookup, meaning the defect is already fixed in production code and the pull request needs only a new test. The spec explicitly states this assumption is conditional on a reproduction record (SPEC-APP-6) that has not yet been completed. Until a contributor runs the reproduction on current main, records the commit SHA, and confirms that `GET /owners?lastName=Davis%20` and `GET /owners?lastName=Davis` return identical results, Case A cannot be treated as settled. If the reproduction shows the padded and trimmed results differ, the cause is either a missing strip call (Case B — production code change required) or something else entirely (Case C — design must return to the G0 owner). This research document cannot resolve the question; it can only record what each outcome implies.

**Alternatives considered**:
- **Case A (working assumption)**: Strip call already present. Pull request = one file, `OwnerControllerTests.java` only. No production code change.
- **Case B**: Strip call absent on current main. Pull request = two files, `OwnerController.java` + `OwnerControllerTests.java`. Requires G0 owner sign-off before G1.
- **Case C**: Strip call present but padded results still differ (e.g., the form binding trims before the controller sees the value, or the repository performs its own normalisation, or a proxy/filter is involved). Root cause unknown; full investigation required before any code change.

---

## R-002 — Trimming method: String.strip() vs String.trim()

**Decision**: Use `String.strip()` (Java 11+).

**Rationale**: `String.strip()` removes all leading and trailing Unicode whitespace as defined by `Character.isWhitespace()`, which includes U+0009 (tab), U+000A (newline), U+000D (carriage return), U+0020 (space), and U+00A0 (non-breaking space). `String.trim()` removes only characters with code point ≤ U+001F or U+0020, so it does not remove U+00A0. The spec explicitly requires that a pasted non-breaking space be handled (edge case, SPEC-APP-6 U+00A0 probe), and the assumption section states "String.strip() removes Unicode whitespace including U+00A0." The PetClinic project targets Java (Spring Boot), and Spring Boot 3.x requires Java 17 as a minimum, so `String.strip()` is available without any dependency change. If the reproduction (R-001) reveals that the existing code already uses `String.trim()` and the U+00A0 probe shows a difference, the fix must use `String.strip()` rather than `String.trim()`.

**Alternatives considered**:
- **`String.trim()`**: Removes ASCII whitespace only (≤ U+0020). Does not handle U+00A0. Rejected because the spec requires U+00A0 to be stripped and `strip()` is available on the target JVM.
- **`StringUtils.strip()` (Apache Commons / Spring)**:  `org.springframework.util.StringUtils.trimWhitespace()` removes Unicode whitespace and is already on the classpath. Functionally equivalent to `String.strip()` for this use case. Not preferred because `String.strip()` is a JDK built-in with no additional import and the spec names it directly.
- **`@RequestParam` with custom binder or `@InitBinder` + `StringTrimmerEditor`**: A global `StringTrimmerEditor` registered in `@InitBinder` would trim all `String` request parameters automatically. Rejected for this change because (a) it would affect every controller and every parameter, not just `lastName` in `processFindForm`, which is a wider blast radius than the spec permits; (b) FR-009 restricts the diff to `OwnerControllerTests.java` (and `OwnerController.java` only under Case B); and (c) the spec explicitly scopes the fix to the controller method, not to a global binding configuration.
- **Trimming in `OwnerRepository.findByLastNameStartingWith`**: Rejected. FR-007 explicitly prohibits modifying the repository. The repository receives an already-trimmed value from the controller.
- **Trimming in the Thymeleaf form or JavaScript**: Rejected. FR-009 prohibits template changes. Client-side trimming would not protect the server-side contract and would not satisfy FR-002.

---

## R-003 — Placement of the strip() call within processFindForm

**Decision**: Strip the `lastName` field of the `Owner` model object exactly once, at the top of `processFindForm`, before any branch (repository lookup, out-of-range redirect, single-match redirect, no-match path).

**Rationale**: FR-001 states the controller MUST remove whitespace "exactly once, before the repository lookup and before the out-of-range redirect is constructed." The `processFindForm` method receives an `Owner` object populated by Spring MVC model binding; the `lastName` is accessed via `owner.getLastName()`. The strip must be applied to this value (or written back via `owner.setLastName(owner.getLastName().strip())`) before the first conditional branch so that every downstream path — list view, single-match redirect, out-of-range redirect, no-match error — sees the trimmed value. Applying the strip inside only one branch (e.g., only before the repository call) would leave the redirect URL construction using the raw padded value, violating FR-003.

**Alternatives considered**:
- **Strip only before the repository call**: Leaves the redirect URL construction using the raw value. Violates FR-003. Rejected.
- **Strip in each branch separately**: Duplicates logic, risks missing a branch in future refactors. Rejected.
- **Strip via a null-safe helper** (e.g., `lastName == null ? "" : lastName.strip()`): Appropriate if `lastName` can be null. The existing code likely already handles the null/blank case (the whitespace-only test `processFindFormWithWhitespaceOnlyLastNameReturnsAllOwners` implies blank is handled). Whether a null guard is needed depends on the current code; this is a minor implementation detail, not a design unknown.

---

## R-004 — Behaviour when the trimmed term is empty (whitespace-only input)

**Decision**: After trimming, an empty string is passed to the repository lookup unchanged, producing the same result as a blank `lastName` submission — all owners, paginated at 5 per page.

**Rationale**: The spec edge-case section states: "After trimming the term becomes an empty string; the controller must treat this the same as a blank search and return all owners, paginated at 5 per page — identical to today's behaviour for a blank lastName." The existing test `processFindFormWithWhitespaceOnlyLastNameReturnsAllOwners` already covers this path. The fix must not break it. No new behaviour is introduced for this case; the strip call simply means a whitespace-only input now reaches the existing blank-handling branch rather than the non-empty branch.

**Alternatives considered**:
- **Return an error for whitespace-only input**: Not specified. Would be a behaviour change. Rejected.
- **Treat whitespace-only as a special case distinct from blank**: Not specified. Adds complexity with no stated benefit. Rejected.

---

## R-005 — Behaviour for inner whitespace (e.g., "De La Cruz ")

**Decision**: Only leading and trailing whitespace is removed. Inner whitespace is preserved. "De La Cruz " trims to "De La Cruz".

**Rationale**: The spec edge-case section is explicit: "Inner whitespace is not touched; only leading and trailing whitespace is removed." `String.strip()` satisfies this requirement by design — it removes only leading and trailing whitespace, not internal whitespace. No additional logic is needed.

**Alternatives considered**:
- **Collapse internal whitespace** (e.g., `replaceAll("\\s+", " ")`): Not specified. Would change the semantics of compound last-name searches. Rejected.

---

## R-006 — U+00A0 (non-breaking space) handling

**Decision**: NEEDS CLARIFICATION, contingent on the SPEC-APP-6 reproduction record.

**Rationale**: The spec states that `String.strip()` removes U+00A0 and that "if the cached controller already calls strip() and the reproduction on current main confirms Case A, this is handled automatically." However, the reproduction has not been completed. Two sub-questions remain open: (1) Does the current main controller use `strip()` or `trim()`? If `trim()`, U+00A0 is not removed and the fix must explicitly use `strip()`. (2) Does the SPEC-APP-6 U+00A0 probe (`GET /owners?lastName=Davis%C2%A0`) show a difference from `GET /owners?lastName=Davis` on current main? If yes and Case A is otherwise confirmed, the existing strip call handles it. If yes and Case B applies, the fix must use `strip()` (not `trim()`). The decision to use `String.strip()` (R-002) already covers this case, but the reproduction record is required to confirm the assumption is not invalidated.

**Alternatives considered**:
- **Ignore U+00A0**: Acceptable only if the probe shows no difference on current main and the existing code already handles it. Cannot be confirmed without the reproduction.
- **Explicitly strip U+00A0 with a separate replace call**: Unnecessary if `String.strip()` is used. Rejected as over-engineering.

---

## R-007 — Out-of-range redirect URL construction

**Decision**: The redirect URL must be constructed using the trimmed `lastName` value. The resulting `Location` header must be `/owners?page=1&lastName=Davis` with no encoded space (`%20` or `+`).

**Rationale**: FR-003 is explicit. Spring MVC's `RedirectAttributes` or a `UriComponentsBuilder`-constructed redirect string will URL-encode the `lastName` value when building the redirect URL. If the trimmed value contains no spaces, no encoding of spaces occurs. The fix (stripping before the redirect is constructed, per R-003) ensures the value passed to the redirect builder is already clean. No change to the redirect construction logic itself is required beyond ensuring the trimmed value is used.

**Alternatives considered**:
- **Encode the redirect URL manually**: Unnecessary if the strip is applied before the redirect is built. Rejected.
- **Strip spaces only from the redirect path, not from the repository call**: Violates FR-001 (strip exactly once, before both). Rejected.

---

## R-008 — Test structure: new method in OwnerControllerTests

**Decision**: Add one new `@Test` method, `processFindFormPaddedTermMatchesTrimmedTermForMultipleOwners`, to the existing `OwnerControllerTests` class. The method submits four requests (`" Davis"`, `"Davis "`, `" Davis "`, `"Davis"`), asserts identical view name, `totalItems`, `totalPages`, and `listOwners` model attributes for each, and uses Mockito to verify the repository is called with `"Davis"` for every variant and never with a padded value.

**Rationale**: FR-004 requires exactly this structure. The spec acceptance scenario (User Story 3, scenario 1) specifies "exactly four invocations of `findByLastNameStartingWith` with the argument `'Davis'`" — one per request. The work plan (E1-S3) refines this to "a call count that matches the requests made," resolving the conflict noted in risk DEF-4 (the "exactly four" wording does not account for the page=2 request in E3-S1). The new method must not modify any existing method. The `@WebMvcTest` + Mockito pattern is already established in the class and is mandated by the constitution (Testing Requirements).

**Alternatives considered**:
- **Parameterised test (`@ParameterizedTest`)**: Would reduce boilerplate. Acceptable technically, but the spec names a single method and the existing class uses plain `@Test`. Consistency with the existing style is preferred. NEEDS CLARIFICATION: whether the project's test style guide permits `@ParameterizedTest` in `OwnerControllerTests`. If it does, a parameterised approach is equivalent.
- **Separate test class**: Rejected. FR-004 specifies `OwnerControllerTests`. A separate class would also require its own `@WebMvcTest` context, increasing build time for no benefit.
- **Integration test against H2**: Rejected. The spec scopes the new test to the `@WebMvcTest` + mocked repository pattern. Seed-backed equality (SPEC-DATA-3) is verified separately and manually (E2-S2).

---

## R-009 — Mockito verification strategy and call count

**Decision**: Use `Mockito.verify(ownerRepository, times(N)).findByLastNameStartingWith(eq("Davis"), any(Pageable.class))` where N equals the number of requests in the test method that are expected to reach the repository with a non-empty trimmed term. Use `Mockito.verify(ownerRepository, never()).findByLastNameStartingWith(argThat(s -> s != null && !s.equals("Davis")), any())` to assert no padded value reaches the repository.

**Rationale**: The spec requires that the repository is called with `"Davis"` for every padded variant and never with a padded value. The `times(N)` count must match the actual number of requests made in the test, not a hard-coded "exactly four" (which would break if the test also exercises the redirect or no-match paths that may call the repository zero or one times). The work plan (E1-S3) explicitly resolves the "exactly four" conflict in this direction. The `never()` assertion on padded values is the mutation guard: if `strip()` is removed, the padded requests pass a padded string to the repository, the `never()` assertion fails, and the test fails (satisfying FR-005).

**Alternatives considered**:
- **`verify(ownerRepository, times(4))`** (hard-coded): Matches the spec text literally but conflicts with the page=2 redirect scenario added in E3-S1. Rejected in favour of the work plan's resolution.
- **`verify(ownerRepository, atLeastOnce())`**: Too weak; does not prove the exact argument. Rejected.
- **Argument captor + assertion on captured values**: Equivalent to `eq("Davis")` but more verbose. Acceptable as an alternative implementation; not a design decision.

---

## R-010 — Mutation guard procedure

**Decision**: The developer removes the `strip()` call locally, runs the test suite, confirms the new test fails, restores the production file, and records the result in the pull request description. The production file (`OwnerController.java`) must not appear in the final diff.

**Rationale**: FR-005 requires this procedure. It is a manual step, not an automated CI gate. The pull request description is the evidence record. The constitution's code review requirement means the reviewer must check that the production file is absent from the diff after the mutation check is complete.

**Alternatives considered**:
- **Automated mutation testing (e.g., PIT)**: Would provide stronger evidence but is not in scope (FR-009 prohibits build file changes; adding PIT requires `pom.xml` or `build.gradle` changes). Rejected for this pull request.
- **Skip the mutation check**: Violates FR-005. Rejected.

---

## R-011 — Sensitive data handling in the new test

**Decision**: The new test uses only synthetic owner values already present in the test class (or equivalent fixtures: e.g., owners named "Davis" with ids 2 and 4 as used in existing tests). No real owner name, address, or telephone number is introduced. The test does not add any log statement, model attribute, or assertion on the raw (padded) search term.

**Rationale**: FR-008 and SPEC-SEC-1 prohibit introducing real sensitive data. The constitution (Principle III) prohibits logging Owner sensitive fields. The existing test class already uses synthetic fixtures; the new method follows the same pattern.

**Alternatives considered**:
- **Use a different last name**: Acceptable, but "Davis" is already established in the seed and in existing tests. Consistency is preferred.
- **Assert the model contains the raw padded term**: Prohibited by FR-008. Rejected.

---

## R-012 — Files permitted in the pull request diff

**Decision**: Under Case A (confirmed by reproduction), the diff contains exactly one file: `OwnerControllerTests.java`. Under Case B (strip call absent on current main), the diff contains exactly two files: `OwnerController.java` and `OwnerControllerTests.java`. No other file is permitted.

**Rationale**: FR-009 and SPEC-SEC-3 define the allowlist. The work plan (E1-S2, E5-S3) enforces the one-file rule under Case A and requires the delivery lead to confirm it at G2. The risk log (DEF-1) notes that the spec text still contains "Case B only" wording that should be removed from SPEC-SEC-3 and the integration notes; this is a spec editorial issue, not a design decision for the pull request.

**Alternatives considered**:
- **Modify `findOwners.html` or `ownersList.html`**: Prohibited by FR-009. Rejected.
- **Modify `pom.xml` or `build.gradle`**: Prohibited by FR-009 and FR-012. Rejected.
- **Modify `OwnerRepository`**: Prohibited by FR-007. Rejected.

---

## R-013 — CI pipeline compatibility

**Decision**: No change to the CI workflow, `pom.xml`, `build.gradle`, Docker files, or `application*.properties`. The existing pipeline runs the format check, checkstyle, and full test suite and must pass without modification.

**Rationale**: FR-012 requires this. The constitution (CI Pipeline section) states the GitHub Actions CI must execute the full build and test suite on every pull request. The new test uses the existing `@WebMvcTest` + Mockito infrastructure; no new dependency is introduced. The `I18nPropertiesSyncTest` is unaffected because no new UI strings are added. The `PetClinicRuntimeHints` are unaffected because no new reflection or serialisation is introduced.

**Alternatives considered**:
- **Add a new Maven profile for mutation testing**: Rejected (see R-010).
- **Add a new CI step for smoke testing**: Out of scope for this pull request. The smoke check (E4-S5) is a post-deploy manual step.

---

## R-014 — Rollback strategy

**Decision**: Rollback is a revert of the merge commit followed by a normal redeploy through the existing pipeline. No database, schema, configuration, or migration step is required.

**Rationale**: The spec assumption section states this explicitly. Because the change is confined to test code (Case A) or at most one production Java file (Case B), with no schema, seed, configuration, or deployment artefact change, a `git revert` of the merge commit produces a deployable state identical to the base commit.

**Alternatives considered**:
- **Feature flag**: Not warranted for a one-line fix. Adds complexity with no benefit. Rejected.
- **Blue-green deployment**: Out of scope. The existing deployment procedure is used unchanged.

---

## R-015 — Residual security exposures (out of scope, require explicit accept/reject at G1)

**Decision**: The following pre-existing conditions are out of scope for this pull request and are recorded here for the G1 approver's awareness. No decision is made in this document; each requires an explicit accept or reject.

- **THR-5**: The `/owners` endpoint has no authentication. Pre-existing. Not addressed by this change.
- **THR-6**: No audit log for owner searches. Pre-existing. Not addressed by this change.
- **THR-7**: No server-side length limit on the `lastName` parameter. Pre-existing. Not addressed by this change.
- **Actuator exposure**: `include=*` may expose sensitive data contrary to SPEC-SEC-007 and the constitution (Principle VII). Pre-existing. Not addressed by this change.

**Rationale**: FR-006 and FR-009 prohibit changes to the security posture or configuration. The spec (Assumptions) accepts these as residual risk (ADR-SEC-2). The work plan (E5 risk note) requires the approver to open separate items if any of these are rejected.

**Alternatives considered**: N/A — these are pre-existing conditions, not design choices for this pull request.

---

## Summary of open NEEDS CLARIFICATION items

| ID | Question | Blocking? | Resolution path |
|---|---|---|---|
| R-001 | Is Case A confirmed? Does current main already call strip()? | Yes — blocks all code work | Complete SPEC-APP-6 reproduction record (E1-S1, E1-S2) |
| R-006 | Does the U+00A0 probe show a difference on current main? | Conditional — blocks only if Case A is otherwise confirmed but probe differs | Include U+00A0 probe in SPEC-APP-6 reproduction record |
| R-008 | Does the project test style permit @ParameterizedTest in OwnerControllerTests? | No — plain @Test is the safe default | Check existing test class conventions; editorial only |
