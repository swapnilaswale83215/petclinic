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

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledInNativeImage;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.samples.petclinic.owner.Owner;
import org.springframework.samples.petclinic.owner.OwnerRepository;
import org.springframework.test.context.aot.DisabledInAotMode;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Optional;

/**
 * Test class for {@link OwnerApiController}.
 *
 * @author Synapse Builder
 */
@WebMvcTest(OwnerApiController.class)
@DisabledInNativeImage
@DisabledInAotMode
class OwnerApiControllerTests {

	private static final int KNOWN_ID = 1;

	private static final int UNKNOWN_ID = 999;

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private OwnerRepository owners;

	@BeforeEach
	void setup() {
		Owner owner = new Owner();
		owner.setFirstName("George");
		owner.setLastName("Franklin");
		owner.setAddress("110 W. Liberty St.");
		owner.setCity("Madison");
		owner.setTelephone("6085551023");
		given(this.owners.findById(KNOWN_ID)).willReturn(Optional.of(owner));
		given(this.owners.findById(UNKNOWN_ID)).willReturn(Optional.empty());
	}

	@Test
	void getOwnerById_knownId_returns200WithFiveFields() throws Exception {
		mockMvc.perform(get("/api/owners/{id}", KNOWN_ID))
			.andExpect(status().isOk())
			.andExpect(content().contentType(MediaType.APPLICATION_JSON))
			.andExpect(jsonPath("$.firstName").value("George"))
			.andExpect(jsonPath("$.lastName").value("Franklin"))
			.andExpect(jsonPath("$.address").value("110 W. Liberty St."))
			.andExpect(jsonPath("$.city").value("Madison"))
			.andExpect(jsonPath("$.telephone").value("6085551023"));
	}

	@Test
	void getOwnerById_knownId_bodyHasExactlyFiveFields() throws Exception {
		mockMvc.perform(get("/api/owners/{id}", KNOWN_ID))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.id").doesNotExist())
			.andExpect(jsonPath("$.pets").doesNotExist())
			.andExpect(jsonPath("$.firstName").exists());
	}

	@Test
	void getOwnerById_unknownId_returns404WithMessage() throws Exception {
		mockMvc.perform(get("/api/owners/{id}", UNKNOWN_ID))
			.andExpect(status().isNotFound())
			.andExpect(content().contentType(MediaType.APPLICATION_JSON))
			.andExpect(jsonPath("$.message").value("Not found"));
	}

	@Test
	void getOwnerById_unknownId_bodyHasOnlyMessageKey() throws Exception {
		mockMvc.perform(get("/api/owners/{id}", UNKNOWN_ID))
			.andExpect(status().isNotFound())
			.andExpect(jsonPath("$.id").doesNotExist())
			.andExpect(jsonPath("$.message").value("Not found"))
			.andExpect(content().string(not(containsString("999"))));
	}

	@Test
	void postOwnerById_returns405() throws Exception {
		mockMvc.perform(post("/api/owners/{id}", KNOWN_ID)).andExpect(status().isMethodNotAllowed());
	}

	@Test
	void putOwnerById_returns405() throws Exception {
		mockMvc.perform(put("/api/owners/{id}", KNOWN_ID)).andExpect(status().isMethodNotAllowed());
	}

	@Test
	void getOwnerById_withOriginHeader_noCorsHeader() throws Exception {
		mockMvc.perform(get("/api/owners/{id}", KNOWN_ID).header("Origin", "https://evil.example.com"))
			.andExpect(status().isOk())
			.andExpect(header().doesNotExist("Access-Control-Allow-Origin"));
	}

	@Test
	void optionsOwnerById_preflight_noCorsHeader() throws Exception {
		mockMvc
			.perform(options("/api/owners/{id}", KNOWN_ID).header("Origin", "https://evil.example.com")
				.header("Access-Control-Request-Method", "GET"))
			.andExpect(header().doesNotExist("Access-Control-Allow-Origin"));
	}

}
