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

package org.springframework.samples.petclinic.system;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

/**
 * Static contract-parsing test (Phase a — runnable without a live edge) that reads
 * {@code specs/009-split-petclinic-into-microserv-bbbd6b99/contracts/routing-table.md}
 * and asserts the declared path set matches the Routing Table Completeness Invariant
 * exactly (FR-011, FR-012, E5-S1).
 *
 * <p>This test MUST fail (and therefore fail the build) if any path outside the
 * 14-entry set is found in the routing table.
 */
class RouteInventoryTest {

	private static final String ROUTING_TABLE_PATH =
			"specs/009-split-petclinic-into-microserv-bbbd6b99/contracts/routing-table.md";

	private static final Set<String> EXPECTED_USER_FACING_PATHS = Set.of(
			"/",
			"/owners/find",
			"/owners",
			"/owners/new",
			"/owners/{ownerId}",
			"/owners/{ownerId}/edit",
			"/owners/{ownerId}/pets/new",
			"/owners/{ownerId}/pets/{petId}/edit",
			"/owners/{ownerId}/pets/{petId}/visits/new",
			"/oups",
			"/vets.html",
			"/vets",
			"/resources/**",
			"/webjars/**"
	);

	private static final Set<String> BLOCKED_OPERATIONAL_PATHS = Set.of(
			"/actuator",
			"/actuator/**",
			"/livez",
			"/readyz"
	);

	private Set<String> parseRoutingTablePaths() throws IOException {
		List<String> lines = Files.readAllLines(Path.of(ROUTING_TABLE_PATH));
		Pattern pathPattern = Pattern.compile("^\\|\\s*`(/[^`]*)`");
		Set<String> paths = new HashSet<>();
		for (String line : lines) {
			Matcher m = pathPattern.matcher(line);
			if (m.find()) {
				paths.add(m.group(1));
			}
		}
		return paths;
	}

	@Test
	void routeInventoryMatchesMonolithUserFacingRoutes() throws IOException {
		Set<String> parsedPaths = parseRoutingTablePaths();
		assertEquals(EXPECTED_USER_FACING_PATHS, parsedPaths,
				"Parsed paths from routing-table.md do not match the expected user-facing path set");
	}

	@Test
	void operationalPathsAreNotInRouteInventory() throws IOException {
		Set<String> parsedPaths = parseRoutingTablePaths();
		for (String blockedPath : BLOCKED_OPERATIONAL_PATHS) {
			assertFalse(parsedPaths.contains(blockedPath),
					"Operational path '" + blockedPath + "' must not appear in the route inventory");
		}
	}

}
