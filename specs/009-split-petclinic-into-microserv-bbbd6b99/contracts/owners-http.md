# Contract: Owners Service — HTTP Interface

**Service**: Owners
**Version**: 1.0.0 (matches monolith behaviour at split commit)
**Status**: Must not break — states today's behaviour, which stays unchanged
**Feature**: 009-split-petclinic-into-microserv-bbbd6b99
**Date**: 2026-10-19
**References**: FR-007, FR-008, FR-009, FR-013, FR-014, FR-015, SPEC-APP-5, SPEC-APP-11

---

## Scope

This contract covers every HTTP interaction that the Owners service must honour after the split. All behaviour described here is carried forward verbatim from the monolith. No new routes, response fields, status codes, or validation rules are introduced. Any deviation from this contract is a regression.

The Owners service handles every user-facing path that is not `/vets` or `/vets.html`. It is the sole writer of owner, pet, and visit data.

---

## Base URL

The Owners service is reachable through the edge router at the public origin. It is never addressed directly by end users or external clients.

```
Public origin (through edge):  https://<public-host>
Direct (management port only):  http://<owners-pod>:<management-port>
```

The management port number is NEEDS CLARIFICATION (research item 12a, resolved in E4-S5).

---

## Routes

### GET /

Serves the welcome page.

| Element | Value |
|---------|-------|
| Method | `GET` |
| Path | `/` |
| Status | `200 OK` |
| Content-Type | `text/html;charset=UTF-8` |
| Body | Thymeleaf-rendered welcome page using `welcome.html` from the pinned petclinic-ui artifact; layout identical to monolith |

---

### Owner Routes

#### GET /owners/find

Serves the owner search form.

| Element | Value |
|---------|-------|
| Method | `GET` |
| Path | `/owners/find` |
| Status | `200 OK` |
| Content-Type | `text/html;charset=UTF-8` |
| Body | Owner search form; layout identical to monolith |

#### GET /owners

Processes the owner search and returns results.

| Element | Value |
|---------|-------|
| Method | `GET` |
| Path | `/owners` |
| Query parameter | `lastName` — optional string; empty or absent returns all owners |
| Status (single result) | `302 Found` → redirects to `/owners/{id}` |
| Status (multiple results) | `200 OK` — renders owner list |
| Status (no results) | `200 OK` — renders owner list with empty results |
| Content-Type | `text/html;charset=UTF-8` |

#### GET /owners/new

Serves the new owner registration form.

| Element | Value |
|---------|-------|
| Method | `GET` |
| Path | `/owners/new` |
| Status | `200 OK` |
| Content-Type | `text/html;charset=UTF-8` |

#### POST /owners/new

Submits the new owner registration form.

| Element | Value |
|---------|-------|
| Method | `POST` |
| Path | `/owners/new` |
| Content-Type (request) | `application/x-www-form-urlencoded` |
| Body fields | `firstName`, `lastName`, `address`, `city`, `telephone` |

**Validation rules** (carried forward verbatim from `Owner.java`; must not change, FR-007):

| Field | Rule | Error message key |
|-------|------|-------------------|
| `firstName` | `@NotBlank` | (existing message bundle key) |
| `lastName` | `@NotBlank` | (existing message bundle key) |
| `address` | `@NotBlank` | (existing message bundle key) |
| `city` | `@NotBlank` | (existing message bundle key) |
| `telephone` | `@NotBlank` + matches regex `\d{10}` | (existing message bundle key) |

The exact message bundle keys are determined by the existing `Owner.java` annotations and `messages_*.properties` files. They must not change.

| Outcome | Status | Body |
|---------|--------|------|
| Validation passes | `302 Found` → `/owners/{newId}` | Empty |
| Validation fails | `200 OK` | Re-renders form with inline error messages identical to monolith |

**Edge behaviour**: The edge must not retry POST requests. An upstream failure on POST /owners/new must return the edge error immediately with no second attempt (FR-013). No duplicate owner record must be created on a connection reset after the request body has been sent.

#### GET /owners/{ownerId}/edit

Serves the owner edit form.

| Element | Value |
|---------|-------|
| Method | `GET` |
| Path | `/owners/{ownerId}/edit` |
| Path variable | `ownerId` — positive integer |
| Status (found) | `200 OK` |
| Status (not found) | NEEDS CLARIFICATION — the monolith behaviour for a non-existent ownerId must be captured in the golden master (E3-S1) |
| Content-Type | `text/html;charset=UTF-8` |

#### POST /owners/{ownerId}/edit

Submits the owner edit form.

| Element | Value |
|---------|-------|
| Method | `POST` |
| Path | `/owners/{ownerId}/edit` |
| Content-Type (request) | `application/x-www-form-urlencoded` |
| Body fields | Same as POST /owners/new |
| Validation rules | Same as POST /owners/new |

| Outcome | Status | Body |
|---------|--------|------|
| Validation passes | `302 Found` → `/owners/{ownerId}` | Empty |
| Validation fails | `200 OK` | Re-renders form with inline error messages |

**Edge behaviour**: No retry on POST (FR-013).

#### GET /owners/{ownerId}

Serves the owner detail page.

| Element | Value |
|---------|-------|
| Method | `GET` |
| Path | `/owners/{ownerId}` |
| Status (found) | `200 OK` |
| Content-Type | `text/html;charset=UTF-8` |
| Body | Owner detail page including pet list and visit history; layout identical to monolith |

---

### Pet Routes

#### GET /owners/{ownerId}/pets/new

Serves the new pet registration form.

| Element | Value |
|---------|-------|
| Method | `GET` |
| Path | `/owners/{ownerId}/pets/new` |
| Status | `200 OK` |
| Content-Type | `text/html;charset=UTF-8` |

#### POST /owners/{ownerId}/pets/new

Submits the new pet registration form.

| Element | Value |
|---------|-------|
| Method | `POST` |
| Path | `/owners/{ownerId}/pets/new` |
| Content-Type (request) | `application/x-www-form-urlencoded` |
| Body fields | `name`, `birthDate`, `type` (PetType id or name — NEEDS CLARIFICATION: exact field name must be confirmed from the existing form and `PetValidator`) |

**Validation rules** (enforced by `PetValidator`; must not change, FR-007):

| Rule | Condition |
|------|-----------|
| `name` must not be blank | Always |
| `name` must be unique within the owner's pets | Enforced by `PetValidator`; backed by the unique constraint on `(owner_id, name)` on the `pets` table (FR-009) |
| `birthDate` must not be null | Always |
| `type` must be a valid `PetType` | Always |

| Outcome | Status | Body |
|---------|--------|------|
| Validation passes | `302 Found` → `/owners/{ownerId}` | Empty |
| Validation fails | `200 OK` | Re-renders form with inline error messages |

**Edge behaviour**: No retry on POST (FR-013).

#### GET /owners/{ownerId}/pets/{petId}/edit

Serves the pet edit form.

| Element | Value |
|---------|-------|
| Method | `GET` |
| Path | `/owners/{ownerId}/pets/{petId}/edit` |
| Status | `200 OK` |
| Content-Type | `text/html;charset=UTF-8` |

#### POST /owners/{ownerId}/pets/{petId}/edit

Submits the pet edit form.

| Element | Value |
|---------|-------|
| Method | `POST` |
| Path | `/owners/{ownerId}/pets/{petId}/edit` |
| Content-Type (request) | `application/x-www-form-urlencoded` |
| Body fields | Same as POST /owners/{ownerId}/pets/new |
| Validation rules | Same as POST /owners/{ownerId}/pets/new |

| Outcome | Status | Body |
|---------|--------|------|
| Validation passes | `302 Found` → `/owners/{ownerId}` | Empty |
| Validation fails | `200 OK` | Re-renders form with inline error messages |

**Edge behaviour**: No retry on POST (FR-013).

---

### Visit Routes

#### GET /owners/{ownerId}/pets/{petId}/visits/new

Serves the new visit creation form.

| Element | Value |
|---------|-------|
| Method | `GET` |
| Path | `/owners/{ownerId}/pets/{petId}/visits/new` |
| Status | `200 OK` |
| Content-Type | `text/html;charset=UTF-8` |
| Body | Visit form pre-populated with pet name and existing visit history |

#### POST /owners/{ownerId}/pets/{petId}/visits/new

Submits the new visit creation form.

| Element | Value |
|---------|-------|
| Method | `POST` |
| Path | `/owners/{ownerId}/pets/{petId}/visits/new` |
| Content-Type (request) | `application/x-www-form-urlencoded` |
| Body fields | `date`, `description` |

**Validation rules**:

| Field | Rule |
|-------|------|
| `date` | Must not be null; exact format NEEDS CLARIFICATION — must be confirmed from the existing form and `Visit.java` |
| `description` | `@NotBlank` (must be confirmed from `Visit.java`) |

| Outcome | Status | Body |
|---------|--------|------|
| Validation passes | `302 Found` → `/owners/{ownerId}` | Empty |
| Validation fails | `200 OK` | Re-renders form with inline error messages |

**Append-only invariant**: Visit records must never be deleted once created (FR-008, constitution Section II). There is no DELETE route for visits. There is no delete method on `VisitRepository`. A POST to this endpoint creates a new visit record; it never overwrites or deletes an existing one.

**Edge behaviour**: No retry on POST (FR-013). No duplicate visit record must be created on a connection reset after the request body has been sent.

---

### Error Route

#### GET /oups

Serves the crash/error demonstration page. This route lives in the Owners service only (FR-015).

| Element | Value |
|---------|-------|
| Method | `GET` |
| Path | `/oups` |
| Status | `200 OK` (the page renders; the controller intentionally triggers an exception that is caught by the error handler) |
| Content-Type | `text/html;charset=UTF-8` |
| Body | Error page rendered using `error.html` from the pinned petclinic-ui artifact; layout identical to monolith |

---

## Routes That Must NOT Exist in the Owners Service

The following paths must not be served by the Owners service. A request to any of these paths must return `404 Not Found`.

- `/vets`
- `/vets.html`
- Any path under `/actuator/**` (blocked at edge; must also return 404 if reached directly)
- `/livez`
- `/readyz`

---

## Routes That Must Return 404 at the Edge (Not Handled by Owners Service)

| Path pattern | Expected edge response | Upstream request count |
|---|---|---|
| `/actuator` | `404 Not Found` | 0 |
| `/actuator/**` | `404 Not Found` | 0 |
| `/livez` | `404 Not Found` | 0 |
| `/readyz` | `404 Not Found` | 0 |

(FR-011, FR-016)

---

## Data Integrity Invariants

These invariants are enforced at the database level and must hold at every stage of the migration.

| Invariant | Enforcement |
|-----------|-------------|
| A Pet must belong to exactly one Owner | JPA mapping (`@ManyToOne`, not null); FK on `pets.owner_id` |
| A Visit must be associated with exactly one Pet | JPA mapping; FK on `visits.pet_id` |
| Pet name must be unique within an owner's pets | Unique constraint on `(owner_id, name)` on `pets` table; must exist on H2, MySQL, and PostgreSQL at every stage (FR-009) |
| Visit records are append-only | No DELETE route; no delete method on `VisitRepository`; DELETE on `visits` denied to the Owners runtime database role (FR-008, E5-S8) |
| Owner telephone matches `\d{10}` | `@Pattern` annotation on `Owner.telephone`; must not change (FR-007) |

---

## Headers — Common Rules

| Header | Rule |
|--------|------|
| `X-Forwarded-Host`, `X-Forwarded-For`, `X-Forwarded-Proto` | Stripped by the edge before reaching the Owners service (E5-S1) |
| `Location` (on redirects) | Must use a relative path or the public host; MUST NOT contain an internal Kubernetes service name or port |
| `Set-Cookie` (locale) | `CookieLocaleResolver` may set the locale cookie; must carry `HttpOnly`, `SameSite=Lax`, and `Secure` on TLS (E5-S9) |
| `Set-Cookie` (session) | `JSESSIONID` may be issued by the Owners service for flash message support (POST-redirect-GET pattern); must not be forwarded to the Vets service |

---

## Internationalisation

The Owners service reads and writes the locale cookie set by `CookieLocaleResolver` (default English, `lang` query parameter). All rendered HTML uses message bundles from the pinned petclinic-ui artifact. A language selected on an Owners page must apply when the user navigates to a Vets page, and vice versa (FR-014, SC-006). The locale cookie name, domain, and path attributes are NEEDS CLARIFICATION (research item 11a, resolved in E3-S4).

---

## Edge Resilience Rules for Owners Routes

| Rule | Detail |
|------|--------|
| No retry on POST, PUT, DELETE | FR-013; an upstream failure on a write returns the edge error immediately |
| Owners service down | Owner routes must return an edge error; Vets routes must continue to work without any failed requests (FR-012) |
| Read timeout | 30 seconds for Owners upstream (FR-012) |
| Connect timeout | 1 second (FR-012) |
| GET/HEAD retry | One jittered retry for GET and HEAD requests only (FR-012) |

---

## Artifact Boundary

The Owners service artifact must contain no classes from the `vet` package (SC-004, FR-001). The CI import check enforces this on every pull request.
