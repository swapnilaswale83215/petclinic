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

import static org.assertj.core.api.Assertions.assertThat;
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

/**
 * Test class for {@link OwnerApiController}.
 */
@WebMvcTest(OwnerApiController.class)
@DisabledInNativeImage
@DisabledInAotMode
class OwnerApiControllerTests {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private OwnerRepository owners;

	private Owner george() {
		Owner george = new Owner();
		george.setId(1);
		george.setFirstName("George");
		george.setLastName("Franklin");
		george.setAddress("110 W. Liberty St.");
		george.setCity("Madison");
		george.setTelephone("6085551023");
		return george;
	}

	@Test
	void getOwnerById_knownId_returns200WithFiveFields() throws Exception {
		given(this.owners.findById(1)).willReturn(Optional.of(george()));

		this.mockMvc.perform(get("/api/owners/1"))
			.andExpect(status().isOk())
			.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
			.andExpect(jsonPath("$.firstName").value("George"))
			.andExpect(jsonPath("$.lastName").value("Franklin"))
			.andExpect(jsonPath("$.address").value("110 W. Liberty St."))
			.andExpect(jsonPath("$.city").value("Madison"))
			.andExpect(jsonPath("$.telephone").value("6085551023"))
			.andExpect(jsonPath("$.id").doesNotExist())
			.andExpect(jsonPath("$.pets").doesNotExist());
	}

	@Test
	void getOwnerById_unknownId_returns404WithExactMessage() throws Exception {
		given(this.owners.findById(99999)).willReturn(Optional.empty());

		this.mockMvc.perform(get("/api/owners/99999"))
			.andExpect(status().isNotFound())
			.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
			.andExpect(content().json("{\"message\":\"Not found\"}", true))
			.andExpect(jsonPath("$.message").value("Not found"));

		String body = this.mockMvc.perform(get("/api/owners/99999"))
			.andReturn()
			.getResponse()
			.getContentAsString();
		assertThat(body).doesNotContain("99999");
	}

	@Test
	void postOwnerById_returns405() throws Exception {
		this.mockMvc.perform(post("/api/owners/1")).andExpect(status().isMethodNotAllowed());
	}

	@Test
	void putOwnerById_returns405() throws Exception {
		this.mockMvc.perform(put("/api/owners/1")).andExpect(status().isMethodNotAllowed());
	}

	@Test
	void patchOwnerById_returns405() throws Exception {
		this.mockMvc.perform(patch("/api/owners/1")).andExpect(status().isMethodNotAllowed());
	}

	@Test
	void deleteOwnerById_returns405() throws Exception {
		this.mockMvc.perform(delete("/api/owners/1")).andExpect(status().isMethodNotAllowed());
	}

	@Test
	void getOwnerById_withOriginHeader_returnsNoCorsHeader() throws Exception {
		given(this.owners.findById(1)).willReturn(Optional.of(george()));

		this.mockMvc.perform(get("/api/owners/1").header("Origin", "https://evil.example.com"))
			.andExpect(status().isOk())
			.andExpect(header().doesNotExist("Access-Control-Allow-Origin"));
	}

	@Test
	void optionsOwnerById_preflight_returnsNoCorsHeader() throws Exception {
		this.mockMvc
			.perform(options("/api/owners/1").header("Origin", "https://evil.example.com")
				.header("Access-Control-Request-Method", "GET"))
			.andExpect(header().doesNotExist("Access-Control-Allow-Origin"));
	}

	@Test
	void reflectionCheck_ownerResponseAndApiMessageHaveExactComponents() {
		java.lang.reflect.RecordComponent[] ownerComponents = OwnerResponse.class.getRecordComponents();
		assertThat(ownerComponents).hasSize(5);
		assertThat(ownerComponents[0].getName()).isEqualTo("firstName");
		assertThat(ownerComponents[1].getName()).isEqualTo("lastName");
		assertThat(ownerComponents[2].getName()).isEqualTo("address");
		assertThat(ownerComponents[3].getName()).isEqualTo("city");
		assertThat(ownerComponents[4].getName()).isEqualTo("telephone");

		java.lang.reflect.RecordComponent[] messageComponents = ApiMessage.class.getRecordComponents();
		assertThat(messageComponents).hasSize(1);
		assertThat(messageComponents[0].getName()).isEqualTo("message");
	}

}
