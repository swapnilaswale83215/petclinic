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

import java.lang.reflect.Method;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledInNativeImage;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.repository.CrudRepository;
import org.springframework.http.MediaType;
import org.springframework.samples.petclinic.owner.Pet;
import org.springframework.samples.petclinic.owner.Visit;
import org.springframework.test.context.aot.DisabledInAotMode;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.hasSize;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Test class for {@link PetApiController}.
 *
 * <p>Uses a @WebMvcTest slice with a mocked {@link PetRepository}. No database or
 * running server is required.
 */
@WebMvcTest(PetApiController.class)
@DisabledInNativeImage
@DisabledInAotMode
class PetApiControllerTests {

	private static final int KNOWN_ID = 1;

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private PetRepository petRepository;

	private Visit makeVisit(Integer id, LocalDate date, String description) {
		Visit visit = new Visit();
		visit.setId(id);
		visit.setDate(date);
		visit.setDescription(description);
		return visit;
	}

	private Pet makePetWithVisits(Visit... visits) {
		Pet pet = new Pet();
		pet.setId(KNOWN_ID);
		for (Visit v : visits) {
			pet.getVisits().add(v);
		}
		return pet;
	}

	@Test
	void knownPetReturnsVisitsOldestFirst() throws Exception {
		Visit v1 = makeVisit(3, LocalDate.of(2015, 1, 4), "desc-2015");
		Visit v2 = makeVisit(1, LocalDate.of(2013, 1, 4), "desc-2013");
		Visit v3 = makeVisit(5, null, "desc-null");
		Pet pet = makePetWithVisits(v1, v2, v3);
		given(this.petRepository.findById(KNOWN_ID)).willReturn(Optional.of(pet));

		this.mockMvc.perform(get("/api/pets/{id}/visits", KNOWN_ID))
			.andExpect(status().isOk())
			.andExpect(content().contentType(MediaType.APPLICATION_JSON))
			.andExpect(jsonPath("$", hasSize(3)))
			.andExpect(jsonPath("$[0].date").value("2013-01-04"))
			.andExpect(jsonPath("$[1].date").value("2015-01-04"))
			.andExpect(jsonPath("$[2].date").value((Object) null));

		verify(this.petRepository).findById(KNOWN_ID);
		verifyNoMoreInteractions(this.petRepository);
	}

	@Test
	void sameDateVisitsOrderedByIdNullIdLast() throws Exception {
		Visit v1 = makeVisit(5, LocalDate.of(2013, 1, 4), "desc-id5");
		Visit v2 = makeVisit(2, LocalDate.of(2013, 1, 4), "desc-id2");
		Visit v3 = makeVisit(null, LocalDate.of(2013, 1, 4), "desc-null-id");
		Pet pet = makePetWithVisits(v1, v2, v3);
		given(this.petRepository.findById(KNOWN_ID)).willReturn(Optional.of(pet));

		this.mockMvc.perform(get("/api/pets/{id}/visits", KNOWN_ID))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$", hasSize(3)))
			.andExpect(jsonPath("$[0].description").value("desc-id2"))
			.andExpect(jsonPath("$[1].description").value("desc-id5"))
			.andExpect(jsonPath("$[2].description").value("desc-null-id"));
	}

	@Test
	void unknownPetReturns404WithMessage() throws Exception {
		given(this.petRepository.findById(99999)).willReturn(Optional.empty());

		this.mockMvc.perform(get("/api/pets/{id}/visits", 99999))
			.andExpect(status().isNotFound())
			.andExpect(content().contentType(MediaType.APPLICATION_JSON))
			.andExpect(jsonPath("$.message").value("Not found"))
			.andExpect(jsonPath("$.*", hasSize(1)));
	}

	@Test
	void petWithNoVisitsReturns200EmptyArray() throws Exception {
		Pet pet = new Pet();
		pet.setId(KNOWN_ID);
		given(this.petRepository.findById(KNOWN_ID)).willReturn(Optional.of(pet));

		this.mockMvc.perform(get("/api/pets/{id}/visits", KNOWN_ID))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$", hasSize(0)));
	}

	@Test
	void postReturns405() throws Exception {
		this.mockMvc.perform(post("/api/pets/{id}/visits", KNOWN_ID)).andExpect(status().isMethodNotAllowed());
	}

	@Test
	void putReturns405() throws Exception {
		this.mockMvc.perform(put("/api/pets/{id}/visits", KNOWN_ID)).andExpect(status().isMethodNotAllowed());
	}

	@Test
	void patchReturns405() throws Exception {
		this.mockMvc.perform(patch("/api/pets/{id}/visits", KNOWN_ID)).andExpect(status().isMethodNotAllowed());
	}

	@Test
	void deleteReturns405() throws Exception {
		this.mockMvc.perform(delete("/api/pets/{id}/visits", KNOWN_ID)).andExpect(status().isMethodNotAllowed());
	}

	@Test
	void noCorsHeaderOnGetWithOrigin() throws Exception {
		Pet pet = new Pet();
		pet.setId(KNOWN_ID);
		given(this.petRepository.findById(KNOWN_ID)).willReturn(Optional.of(pet));

		this.mockMvc
			.perform(get("/api/pets/{id}/visits", KNOWN_ID).header("Origin", "https://example.com"))
			.andExpect(header().doesNotExist("Access-Control-Allow-Origin"));
	}

	@Test
	void petRepositoryReflectionTest() {
		List<Method> methods = Arrays.stream(PetRepository.class.getMethods())
			.filter(m -> !m.getDeclaringClass().equals(Object.class))
			.collect(Collectors.toList());
		assertEquals(1, methods.size());
		assertEquals("findById", methods.get(0).getName());
		assertEquals(Integer.class, methods.get(0).getParameterTypes()[0]);
		assertFalse(CrudRepository.class.isAssignableFrom(PetRepository.class));
		assertFalse(JpaRepository.class.isAssignableFrom(PetRepository.class));
	}

	@Test
	void visitItemHasExactlyTwoFieldsNoIdNoPet() throws Exception {
		Visit v = makeVisit(1, LocalDate.of(2020, 6, 15), "checkup");
		Pet pet = makePetWithVisits(v);
		given(this.petRepository.findById(KNOWN_ID)).willReturn(Optional.of(pet));

		this.mockMvc.perform(get("/api/pets/{id}/visits", KNOWN_ID))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$[0].*", hasSize(2)))
			.andExpect(jsonPath("$[0].id").doesNotExist())
			.andExpect(jsonPath("$[0].pet").doesNotExist());
	}

	@Test
	void fieldByFieldReconciliation() throws Exception {
		Visit v = makeVisit(1, LocalDate.of(2020, 6, 15), "annual checkup");
		Pet pet = makePetWithVisits(v);
		given(this.petRepository.findById(KNOWN_ID)).willReturn(Optional.of(pet));

		this.mockMvc.perform(get("/api/pets/{id}/visits", KNOWN_ID))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$[0].date").value("2020-06-15"))
			.andExpect(jsonPath("$[0].description").value("annual checkup"));
	}

}
