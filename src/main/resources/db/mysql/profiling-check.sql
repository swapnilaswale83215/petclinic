-- Pre-cutover profiling script (SPEC-APP-9 NFR-003)
-- Run each query before MySQL cutover. A non-zero result from any query blocks cutover.
-- All limits are derived from Owner.java @Size/@Pattern annotations.

-- (1) owners.address: max 255 characters (@Size(max=255) in Owner.java)
SELECT COUNT(*) AS address_violations FROM owners WHERE LENGTH(address) > 255;

-- (2) owners.city: max 80 characters (@Size(max=80) in Owner.java)
SELECT COUNT(*) AS city_violations FROM owners WHERE LENGTH(city) > 80;

-- (3) owners.telephone: must be exactly 10 digits (@Pattern(regexp='\d{10}') in Owner.java)
SELECT COUNT(*) AS telephone_violations FROM owners WHERE LENGTH(telephone) <> 10 OR telephone NOT REGEXP '^[0-9]{10}$';

-- (4) owners.first_name: max 30 characters (VARCHAR(30) in schema.sql)
SELECT COUNT(*) AS first_name_violations FROM owners WHERE LENGTH(first_name) > 30;

-- (5) owners.last_name: max 30 characters (VARCHAR(30) in schema.sql)
SELECT COUNT(*) AS last_name_violations FROM owners WHERE LENGTH(last_name) > 30;

-- (6) pets.name: max 30 characters (VARCHAR(30) in schema.sql)
SELECT COUNT(*) AS pet_name_violations FROM pets WHERE LENGTH(name) > 30;
