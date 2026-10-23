# Contract: CI/CD Pipeline (SPEC-PLAT-6)

**Component**: GitHub Actions CI/CD pipeline (`.github/workflows/ci-cd-pipeline.yml`)
**Version**: 1.0.0
**Status**: New contract — introduces the delivery pipeline and G5 gate required for E4-S6
**Feature**: 009-split-petclinic-into-microserv-bbbd6b99
**Date**: 2026-10-23
**References**: FR-001 through FR-016, NFR-001 through NFR-006, AC-001 through AC-013, SPEC-PLAT-6, E4-S6

---

## Scope

This contract defines the ordered pipeline stage list, the G5 approval record schema, the digest equality rule, the SBOM artifact naming convention, the scan severity threshold, and the fail-fast rule for the petclinic-mysql delivery pipeline. It is the authoritative reference for the workflow file `.github/workflows/ci-cd-pipeline.yml`.

This contract supplements `deployment-record.md`, which defines the GitHub Deployment object schema for KPI-1 measurement. The G5 approval record schema defined here is consistent with the `payload` fields in `deployment-record.md`.

---

## Ordered Pipeline Stage List

Stages execute in the following order. No stage begins if a preceding mandatory stage has failed (fail-fast rule, NFR-004).

| Order | Stage | Job name | Mandatory | Depends on |
|-------|-------|----------|-----------|------------|
| 1a | Workflow lint and script tests | `lint-workflow` | Yes (parallel) | — |
| 1b | Formatting validation | `format-check` | Yes | — |
| 2 | Checkstyle validation | `checkstyle` | Yes | `format-check` |
| 3 | Unit tests | `unit-tests` | Yes | `checkstyle` |
| 4 | Integration tests | `integration-tests` | Yes | `unit-tests` |
| 5 | SonarQube analysis and quality gate | `sonarqube` | Yes | `integration-tests` |
| 6 | Image build, scan, and SBOM | `image-build` | Yes | `sonarqube` |
| 7 | Contract harness (rehearsal) | `contract-harness` | Yes | `image-build` |
| 8 | Image promotion by digest | `image-promote` | Yes | `contract-harness`, `image-build` |
| 9 | G5 approval gate | `g5-approval` | Yes | `image-promote` |
| 10 | Database migration | `migrate` | Yes | `g5-approval` |
| 11 | Production deploy (digest equality check + traffic shift) | `production-deploy` | Yes | `g5-approval`, `migrate`, `image-build` |

---

## Fail-Fast Rule

Every mandatory stage declares `needs:` pointing to its predecessor(s). GitHub Actions propagates failure: if a job fails, all jobs that (directly or transitively) depend on it are skipped. No stage begins if a preceding mandatory stage has failed or been skipped (NFR-004).

---

## Required Test Suites

The `unit-tests` job MUST execute all five named suites. A build fails if any suite is absent from the Surefire reports or contains a failing test (FR-003 through FR-007, AC-001 through AC-005):

- `OwnerControllerTests`
- `PetControllerTests`
- `VisitControllerTests`
- `ClinicServiceTests`
- `PetClinicConcurrencyTests`

The `integration-tests` job MUST execute both named suites with `-DfailIfNoTests=true` (FR-008, FR-009, AC-006, AC-007):

- `MySqlIntegrationTests` (profile: `mysql`)
- `PostgresIntegrationTests` (profile: `postgres`)

---

## SonarQube Project Key

```
swapnilaswale83215_petclinic
```

The `sonarqube` job MUST pass `-Dsonar.projectKey=swapnilaswale83215_petclinic` to `./mvnw sonar:sonar`. A quality gate status other than `OK` is a hard build failure (FR-010).

---

## Scan Severity Threshold

| Variable | Default | Effect |
|----------|---------|--------|
| `SCAN_SEVERITY_THRESHOLD` | `HIGH` | Advisory documentation of intent |

The Trivy scan is invoked with `--severity CRITICAL,HIGH --exit-code 1`. Any finding at CRITICAL or HIGH severity fails the `image-build` job and halts the pipeline (FR-011, BR-5). The `SCAN_SEVERITY_THRESHOLD` environment variable documents the intent but does not dynamically control the Trivy flag (to avoid duplicate severity values such as `CRITICAL,CRITICAL`).

---

## SBOM Artifact Naming Convention

SBOM artifacts MUST be named using the image digest with the `sha256:` prefix stripped (GitHub Actions artifact names cannot contain colons):

```
sbom-<hex64-digest>
```

Example: `sbom-abc123...def456` (64 lowercase hex characters, no `sha256:` prefix).

The SBOM file itself is stored in CycloneDX JSON format and named `sbom-<hex64-digest>.json`. The Trivy scan report is stored as `trivy-scan-<hex64-digest>.txt`. Both artifacts MUST be retained as pipeline artifacts linked to the promoted digest (NFR-001, NFR-002, AC-013).

---

## G5 Approval Record Schema

Every production deployment MUST produce exactly one G5 approval record conforming to this schema. The record is stored as a pipeline artifact named `g5-approval-record` and uploaded as `g5-approval-record.json` (NFR-003, FR-014, AC-010).

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `image_digest` | string (`sha256:`-prefixed) | Yes | The OCI image digest (SHA-256) of the image being approved for production deployment |
| `approver` | string (GitHub username) | Yes | The GitHub username of the person who granted the G5 approval |
| `timestamp` | string (ISO 8601 UTC) | Yes | The UTC timestamp at which the G5 approval was recorded (format: `YYYY-MM-DDTHH:MM:SSZ`) |
| `workflow_run_id` | string | Yes | The GitHub Actions workflow run ID for audit traceability |
| `repository` | string | Yes | The `owner/repo` identifier of the repository |
| `sha` | string | Yes | The full git SHA of the commit being deployed |

### Example

```json
{
  "image_digest": "sha256:abc123...def456",
  "approver": "delivery-lead",
  "timestamp": "2026-10-23T14:00:00Z",
  "workflow_run_id": "12345678",
  "repository": "swapnilaswale83215/petclinic",
  "sha": "3266d9f..."
}
```

### GitHub Environment Protection Rule

The `g5-approval` job and the `production-deploy` job both declare `environment: production`. The GitHub Environment named `production` MUST be configured in repository Settings → Environments with required reviewers from the G5 group. The orchestrator blocks both jobs until a G5 reviewer approves. Attempting to start without approval surfaces an actionable error in the GitHub Actions UI (AC-010).

---

## Digest Equality Rule

The rehearsal-tested digest MUST equal the promoted digest before any production traffic shift occurs (FR-015, NFR-005, AC-012).

### Rule

1. The `production-deploy` job reads the rehearsal digest from `needs.image-build.outputs.image_digest`.
2. The `production-deploy` job reads the promoted digest from `needs.g5-approval.outputs.promoted_digest`.
3. Both values MUST be non-empty and MUST match the pattern `sha256:[0-9a-f]{64}`.
4. Both values MUST be equal.
5. If any check fails, the job exits 1 with a `FATAL:` message and the traffic shift does not occur.

### Hard Failure Messages

| Condition | Message |
|-----------|----------|
| Either digest is empty or malformed | `FATAL: digest value is empty or not in sha256:<hex64> format — aborting production deploy` |
| Digests do not match | `FATAL: rehearsal digest <X> does not match promoted digest <Y> — aborting production deploy` |
| Both checks pass | `Digest equality verified: <digest>` |

This check has no `if:` condition and no `continue-on-error:` override. It is the first step in `production-deploy` and is non-bypassable (NFR-005).

---

## Required Secrets

The following secrets MUST be configured in the repository or environment before the pipeline can run:

| Secret | Used by | Purpose |
|--------|---------|----------|
| `SONAR_TOKEN` | `sonarqube` | SonarQube authentication token |
| `SONAR_HOST_URL` | `sonarqube` | SonarQube server URL |
| `REGISTRY_USERNAME` | `image-build`, `image-promote` | Container registry username |
| `REGISTRY_PASSWORD` | `image-build`, `image-promote` | Container registry password |
| `REHEARSAL_ENV_URL` | `contract-harness` | Rehearsal environment base URL |
| `REHEARSAL_ENV_TOKEN` | `contract-harness` | Rehearsal environment authentication token |
| `PROD_DB_URL` | `migrate` | Production database JDBC URL |
| `PROD_DB_USER` | `migrate` | Production database username |
| `PROD_DB_PASSWORD` | `migrate` | Production database password |

---

## Relationship to deployment-record.md

This contract governs the pipeline stages and gates. The `deployment-record.md` contract governs the GitHub Deployment object schema created by the pipeline on a production deploy. The G5 approval record schema defined here is consistent with the `payload` fields in `deployment-record.md` (`payload.image_digest`, `payload.actor`, `payload.timestamp`). Both contracts must be satisfied for a production deployment to be considered complete and auditable.
