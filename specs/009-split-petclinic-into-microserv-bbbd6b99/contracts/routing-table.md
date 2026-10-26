# Contract: Edge Routing Table

**Component**: Edge Router
**Version**: 1.0.0
**Status**: Must not break — states the required routing behaviour; this file is the authoritative routing table referenced by FR-010
**Feature**: 009-split-petclinic-into-microserv-bbbd6b99
**Date**: 2026-10-19
**References**: FR-010, FR-011, FR-012, FR-013, SPEC-APP-3, SPEC-INT-1, SPEC-INT-6, SPEC-INT-7, SPEC-INT-8, ADR-APP-9

---

## Scope

This contract defines the routing rules that the edge router must enforce. It is the reviewed file in the repository required by FR-010. The edge router is the single-origin component that routes all user-facing requests; no service is directly reachable by end users.

The edge technology is NEEDS CLARIFICATION (research item 5a, resolved in E4-S6). This contract is expressed in technology-neutral terms. The implementation file (`edge/routing-table.[yml|conf]`) must be generated from or validated against this contract. Any change to the routing table must go through code review before deployment.

---

## Upstream Definitions

| Upstream name | Target | Notes |
|---|---|---|
| `vets` | Vets service application port | ClusterIP; port NEEDS CLARIFICATION (E4-S5) |
| `owners` | Owners service application port | ClusterIP; port NEEDS CLARIFICATION (E4-S5) |

The management port of each service is not an upstream in this routing table. It is not routed by the edge under any circumstances (FR-017).

---

## Routing Rules

Rules are evaluated in the order listed. The first matching rule wins.

### Rule 1 — Block operational paths (highest priority)

| Attribute | Value |
|-----------|-------|
| Match | Path exactly `/actuator` OR path prefix `/actuator/` OR path exactly `/livez` OR path exactly `/readyz` |
| Action | Return `404 Not Found` immediately |
| Forward to upstream | None — request must not reach either service |
| Applies to | All HTTP methods |
| Rationale | FR-011, ADR-APP-9; protects operational endpoints from public exposure |

**Verification**: The upstream request counter for both `vets` and `owners` must remain 0 after a request matching this rule. This is tested in E3-S6 and User Story 5 scenario 1.

---

### Rule 2 — Route /vets.html to Vets service

| Attribute | Value |
|-----------|-------|
| Match | Path exactly `/vets.html` |
| Action | Proxy to upstream `vets` |
| Applies to | `GET` (primary); other methods pass through and are handled by the Vets service |
| Timeout (connect) | 1 second |
| Timeout (read) | 10 seconds |
| Retry | One jittered retry for `GET` and `HEAD` only; no retry for `POST`, `PUT`, `DELETE` |
| Circuit breaker | Per upstream `vets`; open state returns 503 with `Retry-After` header |
| Fallback (circuit open) | `503 Service Unavailable` with `Retry-After`; render petclinic-ui error page layout |
| Rationale | FR-004, FR-010, FR-012 |

---

### Rule 3 — Route /vets to Vets service

| Attribute | Value |
|-----------|-------|
| Match | Path exactly `/vets` |
| Action | Proxy to upstream `vets` |
| Applies to | `GET` (primary); other methods pass through |
| Timeout (connect) | 1 second |
| Timeout (read) | 10 seconds |
| Retry | One jittered retry for `GET` and `HEAD` only |
| Circuit breaker | Per upstream `vets` (shared with Rule 2) |
| Fallback (circuit open) | `503 Service Unavailable` with `Retry-After` |
| Rationale | FR-005, FR-010, FR-012 |

---

### Rule 4 — Route static assets and webjars

| Attribute | Value |
|-----------|-------|
| Match | Path prefix `/resources/` OR path prefix `/webjars/` |
| Action | Proxy to upstream `owners` (default) OR serve from petclinic-ui artifact directly if the edge supports static file serving |
| Timeout (connect) | 1 second |
| Timeout (read) | 10 seconds |
| Retry | One jittered retry for `GET` and `HEAD` only |
| Circuit breaker | Per upstream `owners` |
| Notes | The resolution of the cross-service static-asset fallback conflict (DEF-4) is NEEDS CLARIFICATION — see E3-S3. Until E3-S3 is resolved, static assets are served from the Owners upstream as the default. |
| Rationale | FR-010, FR-014, SPEC-INT-4 |

---

### Rule 5 — Default: route everything else to Owners service

| Attribute | Value |
|-----------|-------|
| Match | All paths not matched by Rules 1–4 |
| Action | Proxy to upstream `owners` |
| Applies to | All HTTP methods |
| Timeout (connect) | 1 second |
| Timeout (read) | 30 seconds (Owners has longer operations: form submissions, database writes) |
| Retry | One jittered retry for `GET` and `HEAD` only; **no retry for `POST`, `PUT`, `DELETE`** |
| Circuit breaker | Per upstream `owners` |
| Fallback (circuit open) | `503 Service Unavailable`; Vets routes must continue to work (FR-012) |
| Rationale | FR-010, FR-012, FR-013 |

---

## Write Safety Rule (All Routes)

The edge must never retry `POST`, `PUT`, or `DELETE` requests to any upstream (FR-013). An upstream failure on a write must return the edge error immediately with no second attempt. This rule applies to Rules 2, 3, 4, and 5.

**Verification**: Fault injection test — a connection reset after the request body has been sent for POST /owners/new must result in exactly 1 upstream request and no duplicate owner record (E3-S5).

---

## Service Isolation Rule

A failure of one upstream must not affect the responses of the other upstream (FR-012).

| Scenario | Expected behaviour |
|----------|--------------------|
| `vets` upstream down or circuit open | `/vets.html` and `/vets` return 503 with `Retry-After`; all owner, pet, and visit routes return normal responses |
| `owners` upstream down or circuit open | Owner, pet, and visit routes return 503; `/vets.html` and `/vets` return normal responses |

---

## Header Rules

| Header | Rule |
|--------|------|
| `X-Forwarded-Host` (inbound) | Stripped by the edge; must not be forwarded to either upstream (E5-S1) |
| `X-Forwarded-For` (inbound) | Stripped or sanitised; must not allow a forged value to appear in a `Location` response header |
| `X-Forwarded-Proto` (inbound) | Stripped; the edge sets its own forwarded-proto if needed |
| `Host` (to upstream) | Set to the upstream's internal address; must not echo the inbound `Host` header verbatim if it has been forged |
| `Location` (from upstream) | Must use the public host or a relative path; the edge must rewrite any `Location` header that contains an internal hostname or port |
| Session cookies | The edge must not forward `JSESSIONID` from the Owners service to the Vets service, and must not forward any Vets response cookie to the Owners service |
| Locale cookie | Passed through unchanged in both directions; the edge must not modify or strip the locale cookie |

---

## Query String Masking (Logging)

The edge must mask the `lastName` query parameter value in access logs for requests to `/owners` (E5-S6, SPEC-SEC-6). The log entry must record that the parameter was present but must not record its value. No other query parameter masking is required by this contract.

---

## Mirroring (S2 Shadow Comparison Only)

During the S2 shadow comparison window (E3-S8, FR-025), the edge must mirror live `GET /vets` and `GET /vets.html` requests to the dark Vets service in addition to forwarding them to the monolith. The mirror is passive: a mirror failure must have no effect on the user-facing response. The mirror must not carry session cookies or locale cookies.

This mirroring configuration is active only during the S2 window and must be removed before S3. The mirroring mechanism depends on the edge technology choice (research item 14a, resolved after E4-S6).

---

## Routing Table Completeness Invariant

The set of user-facing paths reachable through the edge after the split must be identical to the set reachable through the monolith before the split. No path that existed in the monolith may be removed. No new path may be added. This invariant is verified by the route-inventory test in E5-S1.

**Known user-facing paths** (derived from the monolith; this list must be confirmed against the golden masters captured in E3-S1):

| Path | Method(s) | Upstream after split |
|------|-----------|----------------------|
| `/` | GET | owners |
| `/owners/find` | GET | owners |
| `/owners` | GET | owners |
| `/owners/new` | GET, POST | owners |
| `/owners/{ownerId}` | GET | owners |
| `/owners/{ownerId}/edit` | GET, POST | owners |
| `/owners/{ownerId}/pets/new` | GET, POST | owners |
| `/owners/{ownerId}/pets/{petId}/edit` | GET, POST | owners |
| `/owners/{ownerId}/pets/{petId}/visits/new` | GET, POST | owners |
| `/oups` | GET | owners |
| `/vets.html` | GET | vets |
| `/vets` | GET | vets |
| `/resources/**` | GET | owners (pending E3-S3) |
| `/webjars/**` | GET | owners (pending E3-S3) |

Any path not in this table that is requested through the edge must return `404 Not Found` from the Owners service (default upstream) or from the edge itself for blocked paths.

---

## Change Control

Any change to this routing table must be:
1. Made as a pull request modifying `edge/routing-table.[yml|conf]` (or equivalent)
2. Reviewed by at least one contributor before merge (FR-010)
3. Deployed as a single atomic change (the S3 route flip is a single reviewed routing-table change, E3-S9)
4. Accompanied by a rollback plan (the revert is the previous version of this file)

The routing table version must be recorded with each deployment (E3-S9).

### Pre-Staging Gate

- **The revert artefact** (`edge/routing-table.yml` at the revert version) must be authored, reviewed, and in a mergeable state in the repository **before** the flip PR is merged.
- This is a hard prerequisite — the flip must not be applied if the revert artefact is absent or unreviewed.
- The gate is enforced as a **CI required status check** on the flip PR (not a manual checklist item); the check verifies that the revert PR exists, is approved, and is in a mergeable state.
- The CI check must fail the flip PR pipeline if the revert PR is absent, unapproved, or has merge conflicts.
- The verification mechanism is the GitHub Deployments / PR required-status-check configuration documented in tasks.md T104 (pre-staging gate CI check).

### Change Record Metadata

- Both the flip PR description and the revert PR description must include the following two structured fields verbatim:
  - `transformation: split-petclinic-into-microserv-bbbd6b99`
  - `plan-item: E3-S9 / GH-129`
- Both PRs must use the PR description template at `.github/PULL_REQUEST_TEMPLATE/routing-table-change.md`.
- A CI lint step must verify the presence and exact values of both fields in the PR description before the PR can be merged; the pipeline fails if either field is absent or incorrectly valued.
- The same two fields must appear in the commit message of the squash-merge commit for both the flip and revert PRs.

---

## Routing Table Versioning

- **Version identifier format**: `split-petclinic-YYYYMMDD-NNN` where `NNN` is a zero-padded monotonically increasing sequence number reset per calendar day (e.g. `split-petclinic-20261019-001`).
- The version identifier must be **unique** across all routing table artefacts in the repository history.
- The `version` field carrying this identifier is **mandatory** in every routing table artefact file (`edge/routing-table.yml`); a CI lint step must reject any artefact that omits or malforms the field.
- The flip artefact and the pre-staged revert artefact must carry **distinct** version identifiers.
- A CI lint step must validate the identifier format and assert it is lexicographically greater than the previous version in repository history; the pipeline fails on violation.
- The version identifier in force at the time of each deployment must be recorded in the deploy record so the KPI-1 audit trail is complete (FR-006, NFR-004).

---

## Routing Table Status Mechanism

- A mechanism must exist — implemented as `edge/scripts/check-routing-version.sh` — that allows operators to query the currently active routing table version on all edge/proxy nodes.
- The script must return a version identifier string in the `split-petclinic-YYYYMMDD-NNN` format defined in the Routing Table Versioning section.
- The returned version identifier must be programmatically comparable (string equality) against the version field in the deploy metadata record.
- The mechanism must be available and return a result within the agreed propagation window (10 minutes or less).
- **NEEDS CLARIFICATION**: the specific implementation of the query is pending resolution of research item 5a (edge technology choice); the script must be updated once the edge technology is confirmed.
- After each flip or revert, an operator must run the status check and confirm the returned version matches the deploy record before the change is considered complete (AC-013).

---

## Change Isolation Invariant

- The S3 flip routing table change **MUST NOT** modify any routing rule other than those for `/vets` and `/vets.html`.
- A before/after diff of the routing table artefact file must be produced automatically by the CI diff gate (`.github/workflows/routing-table-diff-gate.yml`) and attached to the flip PR.
- Any additional path change detected by the diff gate is a **blocking failure** — the flip PR pipeline must not pass.
- The diff gate runs as a required status check on the flip PR.
- The diff output must be included in the durable CI artefacts attached to the rehearsal run (see Rehearsal Evidence Requirements).

---

## Rehearsal Evidence Requirements

- **Rehearsal fidelity**: the rehearsal environment must match production in proxy/edge technology, routing table format, and live or live-equivalent traffic on owner routes. A fidelity checklist must be completed and attached to the S3 approval gate document (tasks.md T097) before rehearsal results are accepted as G2 gate evidence (NFR-008).
- The CI pipeline (`.github/workflows/s3-rehearsal.yml`) must persist **three durable artefact types** after each rehearsal run:
  1. **Flip and revert timing measurements** — wall-clock seconds for each operation (`artefacts/flip-timing.txt`, `artefacts/revert-timing.txt`).
  2. **Zero-failed-request counts** for owner routes during flip and revert (`artefacts/owner-request-counts.txt`).
  3. **Golden-master diff output** for `/vets` and `/vets.html` against the monolith (`artefacts/golden-master-diff.txt`).
- The CI step must fail if any of the three artefact types is absent or empty.
- Rehearsal results are only accepted as G2 gate evidence when all three artefact types are present and the fidelity checklist is signed off (AC-012, FR-011).
- CI artefact retention must be configured to exceed the post-G2 audit window; if the CI platform retention is insufficient, artefacts must be copied to `specs/009-split-petclinic-into-microserv-bbbd6b99/decisions/` for permanent storage (NFR-010).
