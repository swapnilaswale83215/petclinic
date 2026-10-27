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

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.samples.petclinic.owner.OwnerRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(produces = MediaType.APPLICATION_JSON_VALUE)
class OwnerApiController {

	private final OwnerRepository owners;

	OwnerApiController(OwnerRepository owners) {
		this.owners = owners;
	}

	@GetMapping("/api/owners/{id}")
	ResponseEntity<?> getOwner(@PathVariable("id") Integer id) {
		return this.owners.findById(id)
			.<ResponseEntity<?>>map(o -> ResponseEntity.ok(new OwnerResponse(o.getFirstName(), o.getLastName(),
					o.getAddress(), o.getCity(), o.getTelephone())))
			.orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).body(new ApiMessage("Not found")));
	}

}
