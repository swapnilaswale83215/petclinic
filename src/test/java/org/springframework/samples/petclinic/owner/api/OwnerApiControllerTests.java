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

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledInNativeImage;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.MediaType;
import org.springframework.samples.petclinic.owner.Owner;
import org.springframework.samples.petclinic.owner.OwnerRepository;
import org.springframework.test.context.aot.DisabledInAotMode;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
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

	private Owner makeOwner(String first, String last, String address, String city, String tel) {
		Owner o = new Owner();
		o.setFirstName(first);
		o.setLastName(last);
		o.setAddress(address);
		o.setCity(city);
		o.setTelephone(tel);
		return o;
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

	@Test
	void searchMissingLastNameReturns400() throws Exception {
		mockMvc.perform(get("/api/owners"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.message").value("lastName is required"))
			.andExpect(jsonPath("$.*", hasSize(1)));

		verifyNoInteractions(this.owners);
	}

	@Test
	void searchBlankLastNameReturns400() throws Exception {
		mockMvc.perform(get("/api/owners").param("lastName", "   "))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.message").value("lastName is required"))
			.andExpect(jsonPath("$.*", hasSize(1)));

		verifyNoInteractions(this.owners);
	}

	@Test
	void searchMissingLastNameWithPageZeroReturns400() throws Exception {
		mockMvc.perform(get("/api/owners").param("page", "0"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.message").value("lastName is required"))
			.andExpect(jsonPath("$.*", hasSize(1)));

		verifyNoInteractions(this.owners);
	}

	@Test
	void searchTrimsLastNameBeforeRepositoryCall() throws Exception {
		given(this.owners.findByLastNameStartingWith(any(String.class), any(Pageable.class)))
			.willReturn(new PageImpl<>(List.of(makeOwner("John", "Davis", "1 Main St", "Springfield", "1234567890"))));

		mockMvc.perform(get("/api/owners").param("lastName", "  Davis  "))
			.andExpect(status().isOk());

		ArgumentCaptor<String> captor = ArgumentCaptor.forClass(String.class);
		verify(this.owners).findByLastNameStartingWith(captor.capture(), any(Pageable.class));
		equals("Davis");
		assertEquals("Davis", captor.getValue());
	}

	@Test
	void searchPageableHasCorrectSortAndPageIndex() throws Exception {
		given(this.owners.findByLastNameStartingWith(any(String.class), any(Pageable.class)))
			.willReturn(new PageImpl<>(List.of(makeOwner("John", "Davis", "1 Main St", "Springfield", "1234567890"))));

		mockMvc.perform(get("/api/owners").param("lastName", "Davis").param("page", "2"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.page").value(2));

		ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);
		verify(this.owners).findByLastNameStartingWith(any(String.class), captor.capture());
		Pageable captured = captor.getValue();
		assertEquals(1, captured.getPageNumber());
		assertEquals(5, captured.getPageSize());
		assertTrue(captured.getSort().equals(Sort.by("lastName", "firstName", "id")));
	}

	@Test
	void searchDefaultPageGivesPageIndex0() throws Exception {
		given(this.owners.findByLastNameStartingWith(any(String.class), any(Pageable.class)))
			.willReturn(new PageImpl<>(List.of(makeOwner("John", "Davis", "1 Main St", "Springfield", "1234567890"))));

		mockMvc.perform(get("/api/owners").param("lastName", "Davis"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.page").value(1));

		ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);
		verify(this.owners).findByLastNameStartingWith(any(String.class), captor.capture());
		Pageable captured = captor.getValue();
		assertEquals(0, captured.getPageNumber());
		assertEquals(5, captured.getPageSize());
		assertTrue(captured.getSort().equals(Sort.by("lastName", "firstName", "id")));
	}

	@Test
	void searchPageBelowOneClampedToOne() throws Exception {
		given(this.owners.findByLastNameStartingWith(any(String.class), any(Pageable.class)))
			.willReturn(new PageImpl<>(List.of(makeOwner("John", "Davis", "1 Main St", "Springfield", "1234567890"))));

		mockMvc.perform(get("/api/owners").param("lastName", "Davis").param("page", "0"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.page").value(1));

		ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);
		verify(this.owners).findByLastNameStartingWith(any(String.class), captor.capture());
		assertEquals(0, captor.getValue().getPageNumber());
	}

	@Test
	void searchPagePastEndReturns200WithEmptyContentAndRealTotal() throws Exception {
		given(this.owners.findByLastNameStartingWith(any(String.class), any(Pageable.class)))
			.willReturn(new PageImpl<>(List.of(), PageRequest.of(98, 5), 7L));

		mockMvc.perform(get("/api/owners").param("lastName", "Davis").param("page", "99"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.content", hasSize(0)))
			.andExpect(jsonPath("$.total").value(7));
	}

	@Test
	void searchEnvelopeHasExactlyFourKeys() throws Exception {
		given(this.owners.findByLastNameStartingWith(any(String.class), any(Pageable.class)))
			.willReturn(new PageImpl<>(List.of(makeOwner("John", "Davis", "1 Main St", "Springfield", "1234567890"))));

		mockMvc.perform(get("/api/owners").param("lastName", "Davis"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.*", hasSize(4)))
			.andExpect(jsonPath("$.size").value(5));
	}

	@Test
	void searchContentItemHasExactlyFiveFields() throws Exception {
		given(this.owners.findByLastNameStartingWith(any(String.class), any(Pageable.class)))
			.willReturn(new PageImpl<>(List.of(makeOwner("John", "Davis", "1 Main St", "Springfield", "1234567890"))));

		mockMvc.perform(get("/api/owners").param("lastName", "Davis"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.content[0].*", hasSize(5)))
			.andExpect(jsonPath("$.content[0].id").doesNotExist())
			.andExpect(jsonPath("$.content[0].pets").doesNotExist());
	}

	@Test
	void searchIgnoresCallerSuppliedSize() throws Exception {
		given(this.owners.findByLastNameStartingWith(any(String.class), any(Pageable.class)))
			.willReturn(new PageImpl<>(List.of(makeOwner("John", "Davis", "1 Main St", "Springfield", "1234567890"))));

		mockMvc.perform(get("/api/owners").param("lastName", "Davis").param("size", "100"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.size").value(5));

		ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);
		verify(this.owners).findByLastNameStartingWith(any(String.class), captor.capture());
		assertEquals(5, captor.getValue().getPageSize());
	}

	@Test
	void searchOwnerPageRecordComponentNames() {
		var components = OwnerPage.class.getRecordComponents();
		assertEquals(4, components.length);
		assertEquals("content", components[0].getName());
		assertEquals("page", components[1].getName());
		assertEquals("size", components[2].getName());
		assertEquals("total", components[3].getName());
	}

}
