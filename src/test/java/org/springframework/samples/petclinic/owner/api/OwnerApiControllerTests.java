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

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Test class for {@link OwnerApiController}.
 *
 * <p>Uses a @WebMvcTest slice with a mocked {@link OwnerRepository}. No database or
 * running server is required.
 */
@WebMvcTest(OwnerApiController.class)
@DisabledInNativeImage
@DisabledInAotMode
class OwnerApiControllerTests {

	private static final int KNOWN_ID = 1;

	private static final int UNKNOWN_ID = 99999;

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private OwnerRepository owners;

	private Owner syntheticOwner() {
		Owner owner = new Owner();
		owner.setId(KNOWN_ID);
		owner.setFirstName("FN-sentinel");
		owner.setLastName("LN-sentinel");
		owner.setAddress("ADDR-sentinel");
		owner.setCity("CITY-sentinel");
		owner.setTelephone("TEL-sentinel");
		return owner;
	}

	@Test
	void knownIdReturnsOwnerFields() throws Exception {
		given(this.owners.findById(KNOWN_ID)).willReturn(Optional.of(syntheticOwner()));

		mockMvc.perform(get("/api/owners/{id}", KNOWN_ID))
			.andExpect(status().isOk())
			.andExpect(content().contentType(MediaType.APPLICATION_JSON))
			.andExpect(jsonPath("$.firstName").value("FN-sentinel"))
			.andExpect(jsonPath("$.lastName").value("LN-sentinel"))
			.andExpect(jsonPath("$.address").value("ADDR-sentinel"))
			.andExpect(jsonPath("$.city").value("CITY-sentinel"))
			.andExpect(jsonPath("$.telephone").value("TEL-sentinel"))
			.andExpect(jsonPath("$.id").doesNotExist())
			.andExpect(jsonPath("$.pets").doesNotExist())
			.andExpect(jsonPath("$.*", hasSize(5)));
	}

	@Test
	void unknownIdReturns404WithMessage() throws Exception {
		given(this.owners.findById(UNKNOWN_ID)).willReturn(Optional.empty());

		mockMvc.perform(get("/api/owners/{id}", UNKNOWN_ID))
			.andExpect(status().isNotFound())
			.andExpect(content().contentType(MediaType.APPLICATION_JSON))
			.andExpect(jsonPath("$.message").value("Not found"))
			.andExpect(jsonPath("$.*", hasSize(1)))
			.andExpect(content().string(not(containsString(String.valueOf(UNKNOWN_ID)))));
	}

	@Test
	void postReturns405() throws Exception {
		mockMvc.perform(post("/api/owners/{id}", KNOWN_ID)).andExpect(status().isMethodNotAllowed());
	}

	@Test
	void putReturns405() throws Exception {
		mockMvc.perform(put("/api/owners/{id}", KNOWN_ID)).andExpect(status().isMethodNotAllowed());
	}

	@Test
	void patchReturns405() throws Exception {
		mockMvc.perform(patch("/api/owners/{id}", KNOWN_ID)).andExpect(status().isMethodNotAllowed());
	}

	@Test
	void deleteReturns405() throws Exception {
		mockMvc.perform(delete("/api/owners/{id}", KNOWN_ID)).andExpect(status().isMethodNotAllowed());
	}

	@Test
	void noCorsHeaderOnGetWithOrigin() throws Exception {
		given(this.owners.findById(KNOWN_ID)).willReturn(Optional.of(syntheticOwner()));

		mockMvc.perform(get("/api/owners/{id}", KNOWN_ID).header("Origin", "https://example.com"))
			.andExpect(header().doesNotExist("Access-Control-Allow-Origin"));
	}

	@Test
	void noCorsHeaderOnPreflightOptions() throws Exception {
		mockMvc
			.perform(options("/api/owners/{id}", KNOWN_ID).header("Origin", "https://example.com")
				.header("Access-Control-Request-Method", "GET"))
			.andExpect(header().doesNotExist("Access-Control-Allow-Origin"));
	}

}
