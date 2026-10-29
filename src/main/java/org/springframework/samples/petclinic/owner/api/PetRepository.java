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

import org.springframework.data.repository.Repository;
import org.springframework.samples.petclinic.owner.Pet;

/**
 * Read-only Spring Data repository for {@link Pet} entities. Declares only
 * {@code findById} so that no write method is inherited or available.
 */
interface PetRepository extends Repository<Pet, Integer> {

	Optional<Pet> findById(Integer id);

}
