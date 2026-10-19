# Contract: Data Migration Job

**Component**: Migration job (`migration/` module)
**Version**: 1.0.0
**Status**: New contract — introduces the migration job as the sole DDL path for MySQL and PostgreSQL environments
**Feature**: 009-split-petclinic-into-microserv-bbbd6b99
**Date**: 2026-10-19
**References**: FR-018, FR-019, FR-020, FR-021, FR-022, FR-023, SPEC-DATA-1, SPEC-DATA-3, SPEC-DATA-5, SPEC-DATA-6, SPEC-DATA-7, SPEC-DATA-8, SPEC-DATA-9, SC-001, SC-005, E2-S1 through E2-S7

---

## Scope

This contract defines the behaviour, inputs, outputs, and invariants of the migration job. The migration job is the only component permitted to apply DDL to MySQL and PostgreSQL stores. Neither the Vets service nor the Owners service may run DDL or seed data against a persistent store. The migration job is separate from both services and runs independently (as a Kubernetes Job).

The migration job tool (Flyway, Liquibase, or custom SQL) is NEEDS CLARIFICATION (research item 8a, resolved in E2-S3). This contract is expressed in tool-neutral terms.

---

## Table Ownership

| Table | Owning service | Owning module |
|-------|---------------|---------------|
| `vets` | Vets | `vets` |
| `specialties` | Vets | `vets` |
| `vet_specialties` | Vets | `vets` |
| `owners` | Owners | `owners` |
| `pets` | Owners | `owners` |
| `visits` | Owners | `owners` |
| `types` | Owners | `owners` |

There must be no foreign key, view, or cross-service query between the vet table set and the owner table set (FR-018).

---

## DDL Rules

| Rule | Detail |
|------|--------|
| Only the migration job applies DDL | Neither service runs `schema.sql` or `data.sql` against a persistent MySQL or PostgreSQL store; `spring.sql.init.mode=never` is set in `application.properties` for both services (FR-019) |
| Idempotence | The migration job must be idempotent: running it twice against the same store must produce no change on the second run (no row added, no table altered); verified by checksum comparison on a copy of production data (E2-S3) |
| No demo seed in production | The migration job must not insert demo/seed data into a production store; seed data is only applied in the H2 profile via `data.sql` within each service module |
| Failed job blocks deploy | If the migration job fails, the deploy pipeline must stop; neither service may be deployed against a store that has not been successfully migrated (E2-S3) |
| Create-if-missing only | The migration job must use a create-if-missing strategy; it must not drop or truncate existing tables (except as part of the explicitly approved S6 step) |

---

## H2 Profile (Development and CI)

In the H2 profile, each service initialises only its own table subset using `schema.sql` and `data.sql` in its own module. The migration job does not run in the H2 profile. Each service uses its own H2 in-memory instance; running both services against a single shared H2 instance is not supported (spec Assumptions).

| Service | H2 tables initialised |
|---------|-----------------------|
| Vets | `vets`, `specialties`, `vet_specialties` |
| Owners | `owners`, `pets`, `visits`, `types` |

---

## Database Role Grants

Three database principals are required (FR-020, E5-S3):

### Vets runtime role

| Permission | Tables | Granted |
|------------|--------|---------|
| SELECT | `vets`, `specialties`, `vet_specialties` | Yes |
| INSERT, UPDATE, DELETE | `vets`, `specialties`, `vet_specialties` | **No** — vet data is read-only from the application |
| SELECT, INSERT, UPDATE, DELETE | `owners`, `pets`, `visits`, `types` | **No** |

After S5, the Vets runtime role must also be denied any access to the old vet tables in the shared schema (if S5 uses a separate schema, this is enforced by schema-level isolation).

### Owners runtime role

| Permission | Tables | Granted |
|------------|--------|---------|
| SELECT, INSERT, UPDATE | `owners`, `pets`, `visits`, `types` | Yes |
| DELETE | `visits` | **No** — Visit records are append-only (FR-008) |
| DELETE | `owners`, `pets`, `types` | NEEDS CLARIFICATION (research item 9a — whether DELETE on these tables is needed must be confirmed; withhold by default unless proven necessary) |
| SELECT, INSERT, UPDATE, DELETE | `vets`, `specialties`, `vet_specialties` | **No** |

After S5, the Owners runtime role must be denied any access to the vet tables (FR-020).

### Migration principal

| Permission | Tables | Granted |
|------------|--------|---------|
| DDL (CREATE, ALTER, DROP) | All tables | Yes — during migration only |
| DML (INSERT, UPDATE, DELETE) | All tables | Yes — during S5 copy only |
| Runtime use | — | **No** — the migration principal must not be used by either service at runtime |

---

## Migration Stages

### Stage S2 — Multi-module build (no schema change)

- Schema is unchanged from the monolith
- `schema.sql` and `data.sql` are split per engine into vet and owner subsets by verbatim extraction (E2-S1)
- The union of the two subsets must equal the original script per engine (diff ignoring statement order)
- No DDL is applied to production at this stage

### Stage S3 — Route flip (no schema change)

- Schema is unchanged
- The migration job is not run at this stage
- The edge routing table change is the only production change

### Stage S4 — Vet code removal from Owners image (no schema change)

- Schema is unchanged
- The Owners image no longer contains vet package classes
- No DDL is applied at this stage

### Stage S5 — Optional vet schema copy (sponsor approval required)

This stage is optional and requires explicit sponsor approval (E1-S15). If the sponsor declines S5, this stage and S6 are skipped.

**Pre-conditions** (all must be met before the S5 switch; any failure blocks the switch):

| Pre-condition | Verification |
|---------------|--------------|
| Row counts for `vets`, `specialties`, `vet_specialties` are equal on source and target | Reconciliation tool output |
| Per-range checksums for all three tables are equal on source and target | Reconciliation tool output |
| No owner column or row value appears in any reconciliation report, dump, or log | Automated PII scan (SC-005) |
| The freeze window (manual DML suspended on vet tables) is 15 minutes or less | Rehearsal report per engine (SC-001) |
| A write to a vet table is detected after the copy completed | S5 rollback declared invalid; step stops for re-planning |

**S5 copy behaviour**:

| Rule | Detail |
|------|--------|
| Tables copied | `vets`, `specialties`, `vet_specialties` only |
| Tables not copied | `owners`, `pets`, `visits`, `types` — must not be touched |
| Owner data | Must not appear in any copy output, log, or report (FR-022) |
| Copy tool | NEEDS CLARIFICATION (research item 15a, resolved in E2-S5) |
| Separate schema vs. separate instance | NEEDS CLARIFICATION (research item 8b, resolved before E2-S5) |
| Reconciliation report | Stored as a CI artifact; contains only counts and hashes for owner tables (FR-022) |

**S5 rollback**:

- Redeploy the previous Vets configuration against the old vet tables (which must be intact by checksum)
- Valid only if no write to the vet tables has been detected after the copy completed
- Must complete within 10 minutes (E4-S8)

### Stage S6 — Optional table drop (sponsor approval required, separate from S5 approval)

S6 is blocked until all of the following pre-conditions are met (FR-023):

| Pre-condition | Verification |
|---------------|--------------|
| A backup of the old vet tables has been taken | Backup record |
| A restore test has succeeded | Restore test report |
| The sponsor has given explicit approval | Written approval record |
| At least 3 further clean releases have occurred since S5 | Deployment records |
| The old vet tables are intact by checksum | Checksum comparison against S5 reconciliation report |

The old vet tables must not be dropped until all five pre-conditions are met. The backup must be encrypted and temporary files must be removed after the restore test (E5-S7).

---

## Reconciliation Report Schema

The reconciliation report produced by the S5 reconciliation tool must conform to the following schema. It must not contain any owner field values (FR-022, SC-005).

```
reconciliation-report-{timestamp}.json
{
  "stage": "S5",
  "timestamp": "<ISO 8601 UTC>",
  "engine": "mysql" | "postgresql",
  "tables": [
    {
      "table_name": "vets" | "specialties" | "vet_specialties",
      "source_row_count": <integer>,
      "target_row_count": <integer>,
      "counts_match": true | false,
      "ranges": [
        {
          "range_start": <integer>,
          "range_end": <integer>,
          "source_checksum": "<hex string>",
          "target_checksum": "<hex string>",
          "checksums_match": true | false
        }
      ]
    }
  ],
  "owner_tables": [
    {
      "table_name": "owners" | "pets" | "visits" | "types",
      "row_count": <integer>,
      "checksum": "<hex string>"
    }
  ],
  "overall_result": "PASS" | "FAIL",
  "switch_permitted": true | false
}
```

**Invariants**:
- `switch_permitted` must be `false` if any `counts_match` or `checksums_match` field is `false`
- The `owner_tables` section contains only counts and hashes; no owner field values (name, address, telephone, or any other owner column value) may appear anywhere in the report
- The report must be stored as a CI artifact before the S5 switch is approved

---

## PII Protection Invariants

| Invariant | Enforcement |
|-----------|-------------|
| No owner column or row value in any Vets-side dump, copy, log, test fixture, or reconciliation report | Automated scan of all S5 artefacts before switch approval (SC-005, FR-022) |
| Reconciliation reports for owner tables contain only counts and hashes | Report schema above; automated scan |
| The Vets database role is denied SELECT on owner tables | Database role grant script (FR-020, E5-S3) |
| No owner last-name value in edge or application logs | Edge query-string masking (E5-S6) |

The automated PII scan must check for the presence of owner column names (`name`, `address`, `telephone`, `first_name`, `last_name`) and the table name `owners` in any output file produced by the S5 copy or reconciliation steps. A positive match blocks the switch.
