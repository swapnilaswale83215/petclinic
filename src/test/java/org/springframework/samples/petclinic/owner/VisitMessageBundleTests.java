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
package org.springframework.samples.petclinic.owner;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Properties;
import java.util.stream.Stream;

import org.junit.jupiter.api.Test;

class VisitMessageBundleTests {

	private static final String KEY = "Pattern.visit.description";

	@Test
	void everyBundleDefinesTheShortDescriptionMessage() throws IOException {
		Path dir = Paths.get("src/main/resources/messages");
		try (Stream<Path> files = Files.list(dir)) {
			for (Path file : files.filter(p -> !p.getFileName().toString().equals("messages_en.properties")).toList()) {
				Properties props = new Properties();
				try (InputStream in = Files.newInputStream(file)) {
					props.load(new InputStreamReader(in, StandardCharsets.UTF_8));
				}
				assertThat(props.getProperty(KEY)).as(file.getFileName().toString()).isNotBlank();
			}
		}
	}

}
