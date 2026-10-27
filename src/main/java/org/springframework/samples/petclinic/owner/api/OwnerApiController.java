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

import java.util.Optional;

import org.springframework.http.ResponseEntity;
import org.springframework.samples.petclinic.owner.Owner;
import org.springframework.samples.petclinic.owner.OwnerRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST controller for the owner read API (Story 1).
 *
 * <p>GET /api/owners/{id} returns 200 with exactly five owner fields, or 404 with
 * {"message":"Not found"}. No other HTTP method is mapped. No CORS annotation is
 * present. No @ControllerAdvice is used.
 */
@RestController
class OwnerApiController {

	private final OwnerRepository owners;

	OwnerApiController(OwnerRepository owners) {
		this.owners = owners;
	}

	@GetMapping("/api/owners/{id}")
	ResponseEntity<?> getOwner(@PathVariable("id") int id) {
		Optional<Owner> optionalOwner = this.owners.findById(id);
		if (optionalOwner.isEmpty()) {
			return ResponseEntity.status(404).body(new ApiMessage("Not found"));
		}
		Owner owner = optionalOwner.get();
		return ResponseEntity
			.ok(new OwnerResponse(owner.getFirstName(), owner.getLastName(), owner.getAddress(), owner.getCity(),
					owner.getTelephone()));
	}

}
