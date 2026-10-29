/*
 * Copyright 2012-2025 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.springframework.samples.petclinic.owner.api;

import java.util.Comparator;
import java.util.List;
import java.util.Optional;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.samples.petclinic.owner.Pet;
import org.springframework.samples.petclinic.owner.Visit;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST controller that exposes {@code GET /api/pets/{id}/visits}.
 *
 * <p>Uses a read-only {@link PetRepository} — no write method is available.
 * No {@code @CrossOrigin} and no {@code @ControllerAdvice} are added.
 */
@RestController
class PetApiController {

	private final PetRepository petRepository;

	PetApiController(PetRepository petRepository) {
		this.petRepository = petRepository;
	}

	@GetMapping("/api/pets/{id}/visits")
	ResponseEntity<?> getVisits(@PathVariable Integer id) {
		Optional<Pet> optionalPet = this.petRepository.findById(id);
		if (optionalPet.isEmpty()) {
			return ResponseEntity.status(HttpStatus.NOT_FOUND).body(new ApiMessage("Not found"));
		}
		Pet pet = optionalPet.get();
		List<VisitResponse> visits = pet.getVisits()
			.stream()
			.sorted(Comparator.comparing(Visit::getDate, Comparator.nullsLast(Comparator.naturalOrder()))
				.thenComparing(Visit::getId, Comparator.nullsLast(Comparator.naturalOrder())))
			.map(v -> new VisitResponse(v.getDate() != null ? v.getDate().toString() : null, v.getDescription()))
			.toList();
		return ResponseEntity.ok(visits);
	}

}
