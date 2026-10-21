# Contract: CI Import Boundary Check

**Component**: CI pipeline — pr-verify workflow
**Version**: 1.0.0
**Status**: New contract — introduces the build-time enforcement of the vet/owner package boundary required by FR-002 and SC-004
**Feature**: 009-split-petclinic-into-microserv-bbbd6b99
**Date**: 2026-10-19
**References**: FR-001, FR-002, SC-004, SPEC-APP-7, SPEC-PLAT-2, E1-S4, E4-S3

---

## Scope

This contract defines the rules that the CI import boundary check must enforce on every pull request and every push to the main branch. The check is a required gate in `pr-verify`. A violation must fail the build immediately and report the offending import in the PR check output.

---

## Boundary Rules

The following import directions are prohibited. A class in the `vet` package must not import any class from the `owner` package. A class in the `owner` package must not import any class from the `vet` package. These rules apply to all classes in both service modules, including test classes.

| Prohibited import direction | Scope |
|-----------------------------|-------|
| `org.springframework.samples.petclinic.vet.*` → `org.springframework.samples.petclinic.owner.*` | All source and test classes in the `vets` module |
| `org.springframework.samples.petclinic.owner.*` → `org.springframework.samples.petclinic.vet.*` | All source and test classes in the `owners` module |

The `system` package (containing `CacheConfiguration`, `WebConfiguration`, `CrashController`) is internal to each module and must not be imported across modules either.

---

## Enforcement Mechanism

The check is implemented as an ArchUnit test (preferred) or an equivalent bytecode-level scan. The exact test class location in the multi-module layout is NEEDS CLARIFICATION (research item 2a, resolved in E1-S4). Candidate locations:

| Option | Description | Trade-off |
|--------|-------------|-----------|
| Per-module ArchUnit test | Each module contains a test that checks only its own outbound imports | Runs as part of the normal test phase per module; cannot check cross-module transitive dependencies |
| Dedicated `build-checks` module | A separate module that depends on both compiled outputs and runs a single ArchUnit test | Catches transitive violations; requires an additional module in the root POM |
| Root-level test | A test at the root POM level that scans both modules | Runs only at the root build; not enforced on per-module builds |

Until research item 2a is resolved, this contract specifies the required behaviour regardless of implementation location.

---

## Required Check Behaviour

| Condition | Required outcome |
|-----------|-----------------|
| A class in the `vet` package imports a class from the `owner` package | Build fails; violation reported in PR check output with the offending class name and import |
| A class in the `owner` package imports a class from the `vet` package | Build fails; violation reported in PR check output with the offending class name and import |
| No cross-package import exists | Build passes; check reports 0 violations |
| The check itself fails to run (e.g., classpath error) | Build fails; the check must not silently pass on error |

---

## Artifact Boundary Verification

In addition to the import check, the CI pipeline must verify that the compiled Vets artifact contains no `.class` files from the `owner` package, and the compiled Owners artifact contains no `.class` files from the `vet` package (SC-004). This verification runs as part of `pr-verify` and as part of each deploy workflow before the image is pushed.

| Check | Tool | Failure condition |
|-------|------|-------------------|
| Vets JAR contains no `owner` package classes | `jar tf` + grep, or ArchUnit | Any `.class` file under `…/owner/` found in the Vets JAR |
| Owners JAR contains no `vet` package classes | `jar tf` + grep, or ArchUnit | Any `.class` file under `…/vet/` found in the Owners JAR |

---

## Path Filter Rules for Deploy Workflows

The following path filter rules determine which deploy workflow is triggered by a given commit. These rules are part of the import boundary contract because they are the mechanism by which KPI-1 is enforced at the CI level (FR-002).

| Changed path pattern | Workflow triggered |
|----------------------|--------------------|
| `vets/**` only | `deploy-vets.yml` only |
| `owners/**` only | `deploy-owners.yml` only |
| `petclinic-ui/**` | Both `deploy-vets.yml` and `deploy-owners.yml` (coordinated UI release; excluded from KPI-1 count per the rule decided in E4-S1) |
| `edge/**` | `deploy-edge.yml` only |
| Root POM (`pom.xml`) | Both deploy workflows (root POM change affects both services) |
| `.github/workflows/**` | NEEDS CLARIFICATION — must be decided in E4-S3; a workflow change may need to trigger both deploys or neither |
| `migration/**` | Neither deploy workflow; migration job has its own trigger |

The exact path filter patterns must be confirmed and recorded in E4-S3 (research item 6a). The patterns above are the required logical behaviour; the implementation in GitHub Actions `paths:` syntax must match them exactly.

---

## PR Check Output Requirements

When the import check fails, the PR check output must include:

1. The name of the offending class (fully qualified)
2. The prohibited import statement
3. The module in which the violation was found
4. A reference to this contract (`contracts/ci-import-check.md`) so that the author understands the rule

Example failure message (format is illustrative):

```
IMPORT BOUNDARY VIOLATION
Module: owners
Class: org.springframework.samples.petclinic.owner.OwnerController
Prohibited import: org.springframework.samples.petclinic.vet.VetRepository
Rule: No class in the owner package may import from the vet package.
See: contracts/ci-import-check.md
```
