# Contract: GET /owners — Owner Search Endpoint

**Feature**: Owner Search Trims Spaces
**Branch**: `009-owner-search-trims-spaces-petc-9985d018`
**Date**: 2026-10-18
**Status**: Must-not-break (existing behaviour preserved) + one new invariant (whitespace trimming)

---

## Overview

`GET /owners` is the Find Owners search endpoint. It accepts an optional `lastName` prefix and an optional `page` number, then returns either a list view, a single-owner redirect, an out-of-range redirect, or a not-found error. This contract documents the full observable behaviour of the endpoint as it must exist after the change. Every item marked **UNCHANGED** describes today's behaviour, which must not be broken. The single item marked **NEW INVARIANT** is the behaviour added by this feature.

---

## Request

### Method and Path

```
GET /owners
```

### Query Parameters

| Parameter  | Type    | Required | Constraints                                                                 |
|------------|---------|----------|-----------------------------------------------------------------------------|
| `lastName` | String  | No       | URL-decoded value is used as a prefix match against owner last names. Empty string or absent means "match all". Leading and trailing Unicode whitespace is silently removed before use. **NEW INVARIANT** |
| `page`     | Integer | No       | 1-based page index into the paginated result. Absent or invalid values default to page 1. |

### Headers

No authentication header is required. **UNCHANGED** — the endpoint is unauthenticated (pre-existing condition, residual risk THR-5, out of scope for this change).

### Encoding

`lastName` is URL-encoded in the query string. The server URL-decodes the value before processing. A trailing space is encoded as `%20`; a non-breaking space (U+00A0) is encoded as `%C2%A0`. Both are removed by `String.strip()` after decoding. **NEW INVARIANT** (for the trimming step; URL decoding itself is unchanged).

---

## Response Outcomes

The endpoint produces one of four outcomes depending on the number of matching owners and the requested page. All four outcomes are **UNCHANGED** in their structure; the new invariant affects only which trimmed term is used to compute the match count.

### Outcome 1 — Multiple owners found, page in range

**Condition**: The trimmed `lastName` prefix matches two or more owners, and `page` is within the available page range.

**HTTP Status**: `200 OK`

**View**: `owners/ownersList`

**Model attributes**:

| Attribute    | Type              | Description                                                  |
|--------------|-------------------|--------------------------------------------------------------|
| `listOwners` | `List<Owner>`     | Owners on the current page matching the trimmed prefix.      |
| `totalItems` | `long`            | Total number of matching owners across all pages.            |
| `totalPages` | `int`             | Total number of pages at page size 5.                        |
| `currentPage`| `int`             | The 1-based page number rendered. **UNCHANGED**              |

**Page size**: Fixed at 5. **UNCHANGED** — out of scope for this change.

**NEW INVARIANT**: For any `lastName` value `v`, the model attributes produced for `v` and for any whitespace-padded variant of `v` (e.g., `" v"`, `"v "`, `" v "`) are identical. Formally: `results(v) == results(strip(v))` for all `v`.

---

### Outcome 2 — Exactly one owner found

**Condition**: The trimmed `lastName` prefix matches exactly one owner.

**HTTP Status**: `302 Found` (redirect)

**Location**: `/owners/{id}` where `{id}` is the matched owner's numeric identifier. **UNCHANGED**

**NEW INVARIANT**: The redirect target for a padded term is identical to the redirect target for the trimmed term. No encoded space (`%20` or `+`) appears in the `Location` header.

---

### Outcome 3 — No owner found

**Condition**: The trimmed `lastName` prefix matches no owner.

**HTTP Status**: `200 OK` (form re-rendered with error)

**View**: `owners/findOwners`

**Model**: A field error is bound to the `lastName` field with the key `notFound`. The error text is **UNCHANGED** — no new error message is introduced by this change.

**NEW INVARIANT**: A padded term that trims to a value matching no owner produces the same not-found response as the trimmed term directly.

---

### Outcome 4 — Multiple owners found, page out of range

**Condition**: The trimmed `lastName` prefix matches two or more owners, and the requested `page` number exceeds the total number of available pages.

**HTTP Status**: `302 Found` (redirect)

**Location**: `/owners?page=1&lastName={trimmedLastName}` where `{trimmedLastName}` is the trimmed value with no leading or trailing whitespace and no encoded space (`%20` or `+`). **NEW INVARIANT** (the trimmed value is used in the redirect; the URL structure itself is unchanged).

**Example**:
- Request: `GET /owners?lastName=Davis%20&page=999`
- Response: `302 Found`, `Location: /owners?page=1&lastName=Davis`

**Example**:
- Request: `GET /owners?lastName=%20Davis&page=999`
- Response: `302 Found`, `Location: /owners?page=1&lastName=Davis`

---

## Trimming Invariant (formal statement)

For every `lastName` query parameter value `v` (after URL decoding):

```
processFindForm(v)  ≡  processFindForm(v.strip())
```

where `strip()` removes all leading and trailing Unicode whitespace as defined by `Character.isWhitespace()`, including U+0020 (space), U+0009 (tab), U+000A (newline), U+000D (carriage return), and U+00A0 (non-breaking space).

The trimming is applied exactly once, at the entry of `OwnerController.processFindForm`, before any branch. No padded value ever reaches `OwnerRepository.findByLastNameStartingWith`.

**NEEDS CLARIFICATION**: The U+00A0 probe (`GET /owners?lastName=Davis%C2%A0`) has not yet been executed on current main (SPEC-APP-6 reproduction record, R-006). If the probe reveals that the existing controller uses `String.trim()` rather than `String.strip()`, U+00A0 is not currently stripped and the invariant above does not hold for U+00A0 on current main. The fix must use `String.strip()` in that case. This contract states the required post-fix behaviour regardless of the current state.

---

## Unchanged Behaviours (must-not-break)

The following behaviours are explicitly documented as unchanged. Any pull request that alters them must be rejected.

| Behaviour | Detail |
|---|---|
| URL path | `GET /owners` — path is unchanged |
| Parameter names | `lastName` and `page` — names and types are unchanged |
| Page size | 5 owners per page — fixed, not configurable via this endpoint |
| Blank `lastName` | Absent or empty `lastName` returns all owners, paginated at 5 per page |
| Whitespace-only `lastName` | After trimming, an empty string is treated identically to a blank `lastName` (all owners returned) |
| Single-match redirect target | `/owners/{id}` — path structure unchanged |
| Out-of-range redirect target | `/owners?page=1&lastName={term}` — parameter order and names unchanged |
| Not-found field error key | `notFound` bound to `lastName` field — key and binding unchanged |
| View names | `owners/ownersList` and `owners/findOwners` — unchanged |
| Model attribute names | `listOwners`, `totalItems`, `totalPages`, `currentPage` — unchanged |
| Repository method | `OwnerRepository.findByLastNameStartingWith(String lastName, Pageable pageable)` — signature, semantics, and callers unchanged |
| Authentication | None required — pre-existing unauthenticated state unchanged |
| Template rendering | `findOwners.html` and `ownersList.html` — not modified |

---

## Out-of-Scope Behaviours

The following are explicitly not addressed by this contract or this change:

- Authentication or authorisation on `GET /owners` (THR-5, residual risk)
- Audit logging of search terms (THR-6, residual risk)
- Server-side length limit on `lastName` (THR-7, residual risk)
- Pagination link correctness on `ownersList.html` (known gap: page links drop `lastName`; separate follow-up required)
- Inner whitespace normalisation (e.g., collapsing `"De  La  Cruz"` to `"De La Cruz"`)
- Case-insensitive search
- Any endpoint other than `GET /owners`

---

## Verification

The following test handles in `OwnerControllerTests` verify this contract:

| Test method | Scenarios covered |
|---|---|
| `processFindFormPaddedTermMatchesTrimmedTermForMultipleOwners` *(new)* | Outcomes 1 and 4 for padded variants; Mockito verifies repository receives only `"Davis"` |
| `processFindFormByLastName` *(existing, unchanged)* | Outcome 1 baseline |
| `processFindFormIgnoresSurroundingWhitespace` *(existing, unchanged)* | Outcome 2 for a padded single-match term |
| `processFindFormWithWhitespaceOnlyLastNameReturnsAllOwners` *(existing, unchanged)* | Blank/whitespace-only `lastName` → all owners |
| `processFindFormNoOwnersFound` *(existing, unchanged)* | Outcome 3 |
| `processFindFormRedirectsOutOfBoundsPageToFirstPage` *(existing, unchanged)* | Outcome 4 baseline |

The new test method additionally asserts Outcome 3 (not-found) and Outcome 2 (single-match redirect) for padded terms, per E3-S1 and E5-S4.

**NEEDS CLARIFICATION**: The exact call-count assertion in `processFindFormPaddedTermMatchesTrimmedTermForMultipleOwners` (whether `times(4)` or a count derived from the number of requests that reach the repository) is resolved by the work plan (E1-S3: "a call count that matches the requests made") but must be confirmed when the test is written, since E3-S1 adds redirect and no-match assertions to the same method that may or may not invoke the repository.
