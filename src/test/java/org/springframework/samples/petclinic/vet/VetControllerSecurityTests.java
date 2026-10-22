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

package org.springframework.samples.petclinic.vet;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledInNativeImage;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.http.MediaType;
import org.springframework.test.context.aot.DisabledInAotMode;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Security tests for {@link VetController} verifying forged forwarding headers
 * do not appear in redirect Location headers (SPEC-SEC-1, E5-S1).
 */
@WebMvcTest(VetController.class)
@DisabledInNativeImage
@DisabledInAotMode
class VetControllerSecurityTests {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private VetRepository vets;

	@BeforeEach
	void setup() {
		Vet vet = new Vet();
		vet.setId(1);
		vet.setFirstName("James");
		vet.setLastName("Carter");
		given(this.vets.findAll(any(Pageable.class))).willReturn(new PageImpl<>(List.of(vet)));
		given(this.vets.findAll()).willReturn(List.of(vet));
	}

	@Test
	void testForgedXForwardedHostNotInLocationOnVetsRedirect() throws Exception {
		mockMvc
			.perform(get("/vets.html").param("page", "0").header("X-Forwarded-Host", "evil.example.com"))
			.andExpect(status().is3xxRedirection())
			.andExpect(header().string("Location", not(containsString("evil.example.com"))));
	}

	@Test
	void testForgedHostNotInLocationOnVetsRedirect() throws Exception {
		mockMvc
			.perform(get("/vets.html").param("page", "0").header("Host", "evil.example.com"))
			.andExpect(status().is3xxRedirection())
			.andExpect(header().string("Location", not(containsString("evil.example.com"))));
	}

	@Test
	void testAcceptHeaderPassesThroughOnVets() throws Exception {
		mockMvc
			.perform(get("/vets").header("Accept", "application/json")
				.header("X-Forwarded-Host", "attacker.internal"))
			.andExpect(status().isOk())
			.andExpect(content().contentType(MediaType.APPLICATION_JSON));
	}

}
