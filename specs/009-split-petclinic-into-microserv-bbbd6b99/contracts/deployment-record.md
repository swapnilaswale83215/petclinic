# Contract: Deployment Record Schema

**Component**: GitHub Deployments API (CI pipeline — deploy-vets.yml, deploy-owners.yml)
**Version**: 1.0.0
**Status**: New contract — introduces the deployment record required for KPI-1 measurement
**Feature**: 009-split-petclinic-into-microserv-bbbd6b99
**Date**: 2026-10-19
**References**: FR-003, SPEC-=== FILE: deployment-record.md ===
# Contract: Deployment Record Schema

**Component**: GitHub Deployments API (CI pipeline — deploy-vets.yml, deploy-owners.yml)
**Version**: 1.0.0
**Status**: New contract — introduces the deployment record required for KPI-1 measurement
**Feature**: 009-split-petclinic-into-microserv-bbbd6b99
**Date**: 2026-10-19
**References**: FR-003, SPEC-PLAT-3, E4-S4, E4-S1

---

## Scope

This contract defines the schema and required fields for every GitHub Deployment object created by the CI pipeline on a production deploy. These records are the authoritative data source for KPI-1 measurement. Every production deploy of either service must create exactly one record conforming to this schema.

---

## GitHub Deployment Object — Required Fields

Every deployment record created via the GitHub Deployments API must carry the following fields:

| Field | Type | Required | Value |
|-------|------|----------|-------|
| `environment` | string | Yes | The target environment name (e.g., `production`, `staging`); must be consistent across deploys so that the KPI-1 report can filter by environment |
| `ref` | string | Yes | The full git SHA of the commit being deployed (not a branch name or tag) |
| `payload.service` | string | Yes | Either `vets` or `owners`; identifies which service this deployment record belongs to |
| `payload.release_id` | string | Yes | A release identifier that groups a set of related deployments; format NEEDS CLARIFICATION (research item 7a, resolved in E4-S1) — candidates are the GitHub release tag, the workflow run ID, or a manually assigned identifier |
| `payload.image_digest` | string | Yes | The OCI image digest (SHA-256) of the image being deployed; enables rollback to a specific image |
| `payload.actor` | string | Yes | The GitHub username of the person or bot that triggered the deploy |
| `payload.timestamp` | string (ISO 8601) | Yes | The UTC timestamp at which the deployment was initiated |
| `description` | string | Yes | Human-readable summary: `"Deploy {service} {short-sha} to {environment}"` |
| `auto_merge` | boolean | Yes | `false` — deployments must not trigger auto-merge |
| `required_contexts` | array | Yes | Must include the `pr-verify` status check; deployment is blocked if `pr-verify` has not passed |

---

## Deployment Status Updates

After the deployment completes, the pipeline must update the deployment status via the GitHub Deployment Statuses API:

| State | When set | Description |
|-------|----------|-------------|
| `in_progress` | Immediately after the deployment job starts | `"Deploying {service} to {environment}"` |
| `success` | After the service passes its readiness probe post-deploy | `"Deployed {service} {short-sha} to {environment}"` |
| `failure` | If the deploy job fails or the readiness probe does not pass within the timeout | `"Deploy failed for {service} {short-sha}"` |

---

## KPI-1 Counting Rule

The KPI-1 report job reads GitHub Deployment records and counts, for each release of one service, how many deployments of the other service occurred in the same release window.

**Target**: 0 deployments of the other service per release of one service.

**Counting rule**: NEEDS CLARIFICATION (research item 7a, resolved in E4-S1). The following cases must be explicitly decided by the sponsor before S2:

| Case | Question | Must be decided in |
|------|----------|--------------------|
| Config-only redeploy (no code change) | Does it count as a deployment for KPI-1 purposes? | E4-S1 |
| petclinic-ui version bump | Does bumping the pinned UI version in one service count as a deployment that could trigger a KPI-1 violation if the other service is also bumped? | E4-S1 |
| Edge-only redeploy | Does redeploying only the edge router count as a deployment of either service? | E4-S1 |
| Migration job run | Does running the migration job count as a deployment of either service? | E4-S1 |

Until the counting rule is decided, the KPI-1 report must record all deployment events and flag the ambiguous cases rather than silently excluding them.

---

## KPI-1 Report Job

The scheduled KPI-1 report job (`kpi-1-report.yml`) must:

1. Query the GitHub Deployments API for all deployment records in the target environment since the last report run
2. Group records by `payload.release_id`
3. For each release of the `vets` service, count the number of `owners` deployments in the same release window
4. For each release of the `owners` service, count the number of `vets` deployments in the same release window
5. Report the count per release; flag any release where the count is greater than 0 as a KPI-1 violation
6. Store the report as a CI artifact

**Baseline**: The KPI-1 baseline value (the count before the split) must be recorded in E4-S1 before S2. The report must display the baseline alongside current values.

---

## Promotion Gate

Every production deployment must wait for reviewer approval from the G5 reviewer group before the deployment record transitions from `in_progress` to `success` (E4-S4). The pipeline must not proceed to the readiness-probe check until approval is granted.

---

## Rollback Record

When a rollback is executed, the pipeline must create a new deployment record for the rolled-back image digest. The rollback record must carry the same required fields as a normal deployment record, with `payload.release_id` set to `"rollback-{original-release-id}"` (exact format NEEDS CLARIFICATION — E4-S1). The rollback must not reuse the original deployment record.

---

## Retention

The last three production image digests for each service must be retained in the container registry (E4-S8). The corresponding deployment records in the GitHub Deployments API are retained by GitHub's standard retention policy and must not be deleted by the pipeline.
