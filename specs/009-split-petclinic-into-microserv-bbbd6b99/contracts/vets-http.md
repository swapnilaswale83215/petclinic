# Contract: Vets Service — HTTP Interface

**Service**: Vets
**Version**: 1.0.0 (matches monolith behaviour at split commit)
**Status**: Must not break — states today's behaviour, which stays unchanged
**Feature**: 009-split-petclinic-into-microserv-bbbd6b99
**Date**: 2026-10-19
**References**: FR-004, FR-005, FR-006, SC-003, SPEC-APP-1, SPEC-APP-2, SPEC-APP-6

---

## Scope

This contract covers every HTTP interaction that the Vets service must honour after the split. All behaviour described here is carried forward verbatim from the monolith. No new routes, response fields, or status codes are introduced. Any deviation from this contract is a regression.

---

## Base URL

The Vets service is reachable through the edge router at the public origin. It is never addressed directly by end users or external clients. Internal Kubernetes addresses are not part of this contract.

```
Public origin (through edge):  https://<public-host>
Direct (management port only):  http://<vets-pod>:<management-port>
```

The management port number is NEEDS CLARIFICATION (research item 12a, resolved in E4-S5). All management-port endpoints are out of scope for this contract; they are covered in the operational contract below.

---

## Routes

### GET /vets.html

Serves the paginated veterinarian list as an HTML page rendered by Thymeleaf using `layout.html` and `error.html` from the pinned petclinic-ui artifact.

#### Request

| Element | Value |
|---------|-------|
| Method | `GET` |
| Path | `/vets.html` |
| Query parameter | `page` — optional, positive integer, 1-based; defaults to `1` if absent |
| Accept | Not evaluated for this route; always returns `text/html` |
| Cookies | `LOCALE` cookie (name NEEDS CLARIFICATION — see item 11a) read by `CookieLocaleResolver`; absent cookie defaults to English |
| Session | No `JSESSIONID` is issued or required by the Vets service |

#### Response — normal page

| Element | Value |
|---------|-------|
| Status | `200 OK` |
| Content-Type | `text/html;charset=UTF-8` |
| Body | Thymeleaf-rendered HTML; page size fixed at 5 vets per page; layout identical to monolith |
| Set-Cookie | None (Vets service issues no session cookie) |

#### Response — out-of-range page number

A page number below 1 or above the last page triggers a redirect, not an error.

| Element | Value |
|---------|-------|
| Status | `302 Found` |
| Location | `/vets.html?page=1` — relative path or absolute path using the public host; MUST NOT contain an internal service hostname or port |
| Body | Empty |

**Invariant**: The redirect target is always page 1, regardless of whether the requested page was too low or too high. This matches the monolith behaviour exactly (FR-004).

#### Response — Vets service unavailable (edge-level)

This response is produced by the edge, not the Vets service itself. It is documented here for completeness.

| Element | Value |
|---------|-------|
| Status | `503 Service Unavailable` |
| Headers | `Retry-After: <seconds>` (value NEEDS CLARIFICATION — edge configuration, E3-S5) |
| Body | petclinic-ui error page layout |

---

### GET /vets

Serves the veterinarian list as a structured data resource. Supports JSON and XML content negotiation.

#### Request

| Element | Value |
|---------|-------|
| Method | `GET` |
| Path | `/vets` |
| Accept | `application/json` → JSON response; `application/xml` or `text/xml` → XML response; `*/*` or absent → JSON response (monolith default) |
| Query parameters | None |
| Cookies | Not evaluated for data format; locale cookie ignored for this route |
| Session | None required |

#### Response — JSON

| Element | Value |
|---------|-------|
| Status | `200 OK` |
| Content-Type | `application/json` |
| Body | See JSON schema below |

**JSON schema** (field names and structure must be byte-equal to the monolith for the same data, SC-003):

```json
{
  "vetList": [
    {
      "id": <integer>,
      "firstName": "<string>",
      "lastName": "<string>",
      "specialties": [
        {
          "id": <integer>,
          "name": "<string>"
        }
      ],
      "nrOfSpecialties": <integer>
    }
  ]
}
```

All vets are returned in a single response. There is no pagination on this endpoint. The `nrOfSpecialties` field is derived (`specialties.size()`); it must be present and correct.

#### Response — XML

| Element | Value |
|---------|-------|
| Status | `200 OK` |
| Content-Type | `application/xml` |
| Body | See XML schema below |

**XML schema** (field names, element names, and structure must be byte-equal to the monolith for the same data, SC-003):

```xml
<vets>
  <vetList>
    <id>{integer}</id>
    <firstName>{string}</firstName>
    <lastName>{string}</lastName>
    <specialties>
      <id>{integer}</id>
      <name>{string}</name>
    </specialties>
    <nrOfSpecialties>{integer}</nrOfSpecialties>
  </vetList>
  <!-- repeated for each vet -->
</vets>
```

The JAXB/Jackson-dataformat-xml marshalling dependency must be retained in the Vets module (FR-005). The XML element names are determined by the existing `@XmlRootElement` and `@XmlElement` annotations on `Vet` and `Specialty`; they must not change.

#### Response — unacceptable Accept value

| Element | Value |
|---------|-------|
| Status | `406 Not Acceptable` |
| Body | Empty or default Spring MVC error body |

**Note**: A golden master for the 406 case must be recorded in E3-S1 (research item, plan section E3-S1). The exact response body is NEEDS CLARIFICATION until that golden master is captured.

---

## Caching Behaviour (Internal — Not Observable via HTTP Headers)

`VetRepository.findAll` is annotated `@Cacheable("vets")` backed by `CacheConfiguration` with statistics enabled and no eviction (FR-006). This is an internal implementation detail. The HTTP response for GET /vets and GET /vets.html does not carry `Cache-Control` or `ETag` headers as a result of this cache (the cache is server-side only). The observable effect is that a second call to either endpoint within the same JVM lifetime may be served from the in-process cache rather than the database, but the response body is identical.

Cache statistics are queryable on the management port (see operational contract). No eviction behaviour is added.

---

## Headers — Common Rules

| Header | Rule |
|--------|------|
| `X-Forwarded-Host`, `X-Forwarded-For`, `X-Forwarded-Proto` | Stripped by the edge before reaching the Vets service (E5-S1); the Vets service must not echo these headers in responses |
| `Location` (on redirects) | Must use a relative path or the public host; MUST NOT contain an internal Kubernetes service name or port |
| `Set-Cookie` | The Vets service issues no `JSESSIONID`; it may read but must not overwrite the locale cookie set by the Owners service |

---

## Routes That Must Return 404 at the Edge (Not Handled by Vets Service)

The following paths are blocked at the edge and must never reach the Vets service. They are listed here so that contract tests can verify the edge behaviour without involving the Vets service upstream counter.

| Path pattern | Expected edge response | Upstream request count |
|---|---|---|
| `/actuator` | `404 Not Found` | 0 |
| `/actuator/**` | `404 Not Found` | 0 |
| `/livez` | `404 Not Found` | 0 |
| `/readyz` | `404 Not Found` | 0 |

(FR-011, FR-016, User Story 5 scenario 1)

---

## Routes That Must NOT Exist in the Vets Service

The following paths must not be served by the Vets service. A request to any of these paths that somehow bypasses the edge must return `404 Not Found` from the Vets service itself.

- Any path under `/owners/**`
- Any path under `/pets/**`
- Any path under `/visits/**`
- `/oups`
- Any path not listed in the Routes section above

---

## Internationalisation

The Vets service reads the locale cookie set by `CookieLocaleResolver` (default English, `lang` query parameter). The rendered HTML for GET /vets.html uses the message bundle from the pinned petclinic-ui artifact for the active locale. All 11 supported locales must render correctly. A language selected on an Owners page and stored in the locale cookie must apply when the user navigates to /vets.html (FR-014, SC-006).

The locale cookie name, domain, and path attributes are NEEDS CLARIFICATION (research item 11a, resolved in E3-S4). The cookie must carry `HttpOnly`, `SameSite=Lax`, and `Secure` on TLS (E5-S9).

---

## Error Rendering

Application-level errors in the Vets service (unhandled exceptions, 5xx conditions) must render using `error.html` from the pinned petclinic-ui artifact. The rendered error page must be visually identical to the monolith's error page (FR-015). The Vets service has no `CrashController`; `/oups` is not a Vets route.

---

## Artifact Boundary

The Vets service artifact must contain no classes from the `owner` package (SC-004, FR-001). The CI import check enforces this on every pull request. Any violation fails the build.

---

## Golden Master Verification

Before S3, the S2 shadow comparison (E3-S8, FR-025) must produce a diff count of 0 for:
- Status code
- `Content-Type` header
- Response body

for GET /vets (JSON, XML, no-Accept, `*/*`) and GET /vets.html (all pages, page size 5) between the monolith and the Vets service. This is the primary evidence for the S3 approval gate (SC-003).
