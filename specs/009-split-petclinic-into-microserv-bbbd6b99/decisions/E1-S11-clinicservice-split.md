# Decision Record: E1-S11 — ClinicServiceTests Split

**Date**: 2026-10-23
**Status**: Implemented
**Ticket**: GH-109

## Context

`ClinicServiceTests` contains 12 `@Test` methods that exercise both the Vets repository and the Owner/Pet/Visit repositories. As part of the petclinic microservices split (E1-S11, SPEC-APP-9), these methods must be redistributed verbatim into per-service test classes without modifying any method body, assertion, or expected value.

## Pre-Split Baseline

- **Total test methods in ClinicServiceTests**: 12
- **Failing-test count before split**: 0

## Method Assignment

### Vets Module → `src/test/java/org/springframework/samples/petclinic/vet/VetRepositoryTests.java`

| Method | Exercises |
|---|---|
| `shouldFindVets` | `VetRepository.findAll()` |

**Count**: 1

### Owners Module → `src/test/java/org/springframework/samples/petclinic/owner/OwnerRepositoryTests.java`

| Method | Exercises |
|---|---|
| `shouldFindOwnersByLastName` | `OwnerRepository.findByLastNameStartingWith` |
| `shouldFindSingleOwnerWithPet` | `OwnerRepository.findById` |
| `shouldInsertOwner` | `OwnerRepository.save` |
| `shouldUpdateOwner` | `OwnerRepository.save` |
| `shouldFindAllPetTypes` | `PetTypeRepository.findPetTypes` |
| `shouldInsertPetIntoDatabaseAndGenerateId` | `OwnerRepository.save` with `Pet` |
| `shouldUpdatePetName` | `OwnerRepository.save` with `Pet` |
| `shouldAddNewVisitForPet` | `OwnerRepository.save` with `Visit` |
| `shouldFindVisitsByPetId` | `Owner.getPet(id).getVisits()` |
| `shouldFailToInsertDuplicatePetNameForSameOwner` | `OwnerRepository.saveAndFlush` (UNIQUE constraint) |
| `shouldAllowSamePetNameForDifferentOwners` | `OwnerRepository.saveAndFlush` (cross-owner) |

**Count**: 11

## Post-Split Invariant

- **Total test methods after split**: 12 (1 + 11 = 12)
- **Net change in test coverage**: 0 (NFR-001 satisfied)

## Dependencies and Risks

- **EntityUtils dependency**: `EntityUtils.java` lives in `src/test/java/org/springframework/samples/petclinic/service/`. Both new test classes import it via `org.springframework.samples.petclinic.service.EntityUtils`. It remains on the test classpath.
- **`@AutoConfigureTestDatabase(replace = Replace.NONE)`**: Applied on both new classes exactly as on `ClinicServiceTests`, ensuring the real database profile is used when active.
- **UNIQUE constraint on `pets(owner_id, name)`**: Required by `shouldFailToInsertDuplicatePetNameForSameOwner`; must be present in the H2 schema.

## Outcome

`ClinicServiceTests` is emptied (no `@Test` methods remain). Both new per-service test classes pass with 0 failures.
