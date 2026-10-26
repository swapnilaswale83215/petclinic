## Routing Table Change

<!-- REQUIRED: Do not remove or alter these two structured metadata fields.
     The CI metadata lint step validates their presence and exact values. -->

transformation: split-petclinic-into-microserv-bbbd6b99
plan-item: E3-S9 / GH-129

---

## Routing Table Version

<!-- Enter the version identifier introduced by this PR (format: split-petclinic-YYYYMMDD-NNN) -->

Version: 

---

## Change Type

- [ ] Flip (routes /vets and /vets.html to the vets microservice)
- [ ] Revert (routes /vets and /vets.html back to the monolith)

---

## Pre-Merge Checklist

### Routing Table Version
- [ ] The `version` field in `edge/routing-table.yml` is present and uses the `split-petclinic-YYYYMMDD-NNN` format
- [ ] The version identifier is unique — it does not appear in any previous routing table artefact in repository history
- [ ] The version identifier is lexicographically greater than the previous version

### Change Isolation (Flip PRs only)
- [ ] The CI diff gate (`routing-table-diff-gate`) has passed — only `/vets` and `/vets.html` entries are changed
- [ ] The diff output is attached to this PR as a CI artefact (`routing-table-diff`)
- [ ] No routing rule other than `/vets` and `/vets.html` has been modified

### Pre-Staging Gate (Flip PRs only)
- [ ] The revert PR exists and is linked here: <!-- link to revert PR -->
- [ ] The revert PR has at least one approving review
- [ ] The revert PR is in a mergeable state (no merge conflicts)
- [ ] The pre-staging gate CI check (`pre-staging-gate`) has passed

### Rehearsal Evidence (Rehearsal runs only)
- [ ] Flip timing artefact (`flip-timing`) is attached and non-empty
- [ ] Revert timing artefact (`revert-timing`) is attached and non-empty
- [ ] Owner request counts artefact (`owner-request-counts`) is attached and non-empty
- [ ] Golden-master diff artefact (`golden-master-diff`) is attached and non-empty
- [ ] Rehearsal fidelity checklist is completed and attached to the S3 approval gate document

### Commit Message
- [ ] The squash-merge commit message includes `transformation: split-petclinic-into-microserv-bbbd6b99`
- [ ] The squash-merge commit message includes `plan-item: E3-S9 / GH-129`

---

## Description

<!-- Describe the change being made and why. -->

---

## References

- Contract: `specs/009-split-petclinic-into-microserv-bbbd6b99/contracts/routing-table.md`
- Jira: GH-129 / E3-S9
- Spec: SPEC-INT-12
