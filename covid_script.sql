/* Vytvoření primární tabulky t_adela_prystaszova_projekt_SQL_final
* klíče: country, date
* vysvětlované proměnné: 
 * počet nově nakažených na 100 000 obyvatel
	 * = počet nově nakažených/počet obyvatel*100 000
 * podíl pozitivních testů
	 * = počet nově nakažených/počet testovaných
* vysvětlující proměnné:
 * 	časové
	 * víkend/pracovní den (binární)
	 * roční období (0–3)
 * 	specifické pro stát
	 * hustota zalidnění
	 * HDP/obyv.
	 * Giniho koeficient
	 * dětská úmrtnost
	 * medián věku 2018
	 * podíl každého náboženství na obyvatelstvu
	 * rozdíl naděje dožití ve věku 0 mezi 1965 a 2015
 * 	počasí
	 * průměrná denní teplota
	 * počet hodin s nenulovými srážkami v daném dni
	 * max. síla větru v nárazech v daném dni
* využité tabulky: countries, economies, life_expectancy, 
* religions, covid19_basic_differences, covid19_tests, 
* weather, lookup_table
*/


-- 1) KONTROLA PROMĚNNÝCH

-- a) kontrola proměnné country, pomocí které budu napojovat tabulky na tabulky lookup_table
-- lookup_table x covid19_basic_differences:
SELECT country
FROM covid19_basic_differences
WHERE country NOT IN (
	SELECT country
	FROM lookup_table2
	)
GROUP BY country;
-- v lookup_table nechybí žádná země z covid19_basic_differences 
-- lookup_table x covid19_tests:
SELECT country
FROM covid19_tests
WHERE country NOT IN (
	SELECT country
	FROM lookup_table
	)
GROUP BY country;
-- v lookup_table chybí z covid19_tests:
/*
Czech Republic (v lookup_table jako Czechia)
Democratic Republic of Congo (v lookup_table jako Congo (Kinshasa))
Hong Kong (v lookup_table jako -)
Macedonia (v lookup_table jako North Macedonia)
Myanmar (v lookup_table jako Burma)
Palestine (v lookup_table jako -)
South Korea (v lookup_table jako Korea, South)
Taiwan (v lookup_table jako Taiwan*)
United States (v lookup_table jako US)
*/
-- ostatní tabulky lze spolehlivě napojit přes název státu, případně přes kód ISO/ISO3

-- b) kontrola proměnné date
	-- covid19_basic_differences: 22.1.2020–23.5.2021
	-- covid_19_tests: 29.1.2020–21.11.2020

-- kontrola proměnné entity v covid19_tests;
SELECT country, entity, count(entity) AS počet
FROM covid19_tests
GROUP BY country, entity
ORDER BY country;
-- u zemí jsou různé hodnoty entity, většinou ale u jedné země pouze jedna
SELECT country, entity, count(entity) AS počet
FROM covid19_tests
GROUP BY country, entity
HAVING country IN (
	SELECT country
	FROM covid19_tests
	GROUP BY country
	HAVING count(DISTINCT entity) > 1)
ORDER BY country;
-- u každé země kromě osmi je jen jedna hodnota entity, u těch 8 je níž upraveno


-- ÚPRAVA TABULEK

-- a) vytvoření tabulky lookup_table2 pouze za státy, ne za provincie:
CREATE OR REPLACE TABLE lookup_table2 AS 
SELECT *
FROM lookup_table
WHERE province IS NULL;

-- b) vytvoření a úprava tabulky covid19_tests2, aby názvy států v ní seděly s názvy v tabulce lookup_table 
CREATE OR REPLACE TABLE covid19_tests2 AS
SELECT *
FROM covid19_tests;
UPDATE covid19_tests2
SET country = 
	CASE WHEN country = 'Czech Republic' THEN 'Czechia'
    WHEN country = 'Democratic Republic of Congo' THEN 'Congo (Kinshasa)'
    WHEN country = 'Macedonia' THEN 'North Macedonia'
    WHEN country = 'Myanmar' THEN 'Burma'
    WHEN country = 'South Korea' THEN 'Korea, South'
    WHEN country = 'Taiwan' THEN 'Taiwan*'
    WHEN country = 'United States' THEN 'US'
    ELSE country
END;

-- c) Vytvoření a úprava tabulky weather2 tak, aby v ní relevantní údaje byly bez jednotek a správného typu
CREATE OR REPLACE TABLE weather2
SELECT *
FROM weather;
UPDATE weather2
SET temp = REPLACE(temp, ' °c', '');
UPDATE weather2
SET rain = REPLACE(rain, ' mm', '');
UPDATE weather2
SET gust = REPLACE(gust, ' km/h', '');
ALTER TABLE weather2 MODIFY COLUMN `time` TIME DEFAULT NULL NULL;
ALTER TABLE weather2 MODIFY COLUMN temp INTEGER DEFAULT NULL NULL;
ALTER TABLE weather2 MODIFY COLUMN gust INTEGER DEFAULT NULL NULL;
ALTER TABLE weather2 MODIFY COLUMN rain FLOAT DEFAULT NULL NULL;
ALTER TABLE weather2 MODIFY COLUMN `date` DATE DEFAULT NULL NULL;

-- d) vytvoření a úprava tabulky covid19_tests2 obsahující jen jednu hodnotu entity
CREATE OR REPLACE TABLE covid19_tests2
SELECT *
FROM covid19_tests;
DELETE FROM covid19_tests2
WHERE 
	(country = "France" AND entity = "people tested")
	OR (country = "India" AND entity = "people tested")
	OR (country = "Italy" AND entity = "people tested")
	OR (country = "Japan" AND entity = "people tested (incl. non-PCR)")
	OR (country = "Poland" AND entity = "people tested")
	OR (country = "Singapore" AND entity = "people tested")
	OR (country = "Sweden" AND entity = "people tested")
	OR (country = "United States" AND entity = "units unclear (incl. non-PCR)")
;


-- TVORBA VÝSLEDNÉ TABULKY
/*Napojuji na lookup_table2 na proměnnou country/iso3 tabulky countries,
 * economies, life_expectancy, religion, weather2 (pomocí CTE)
 */

CREATE OR REPLACE TABLE t1
	SELECT 
		lt2.country AS stat, 
		lt2.iso3 AS iso3,
		cbd.date AS datum,
		cou.capital_city AS hlavni_mesto,
		lt2.population AS populace,
		cou.population_density AS hustota_zalidneni,
		cou.median_age_2018 AS median_veku_2018,
		eco.GDP AS HDP_2020,
		eco.population AS populace_2020,
		le1965.life_expectancy AS nadeje_doziti_1965,
		le2015.life_expectancy AS nadeje_doziti_2015,
		rel.religion AS nabozenstvi,
		rel.population AS nabozenstvi_populace,
		cbd.confirmed AS pocet_novych_pripadu,
		ct.tests_performed AS pocet_testu
	FROM lookup_table2 AS lt2
	LEFT JOIN countries AS cou
		ON lt2.iso3 = cou.iso3
	LEFT JOIN economies eco
		ON lt2.country = eco.country
		WHERE eco.year = '2020'
	LEFT JOIN life_expectancy AS le1965
		ON lt2.country = le1965.country
		WHERE le1965.year = '1965'
	LEFT JOIN life_expectancy AS le2015
		ON lt2.country = le2015.country
		WHERE le1965.year = '2015'
	RIGHT JOIN religions AS rel
		ON lt2.country = rel.country
		WHERE rel.year = '2020'
	RIGHT JOIN covid19_basic_differences AS cbd
		ON lt2.country = cbd.country
	LEFT JOIN covid19_tests2 AS ct
		ON lt2.iso3 = ct.iso
		AND cbd.date = ct.date;
		
		
		
		
		
WITH pocasi1 AS (
	SELECT date, city, avg(temp) AS prumerna_denni_teplota
	FROM weather2
	WHERE time NOT IN (00:00:00, 03:00:00)
	GROUP BY date, city),
pocasi2 AS (
	SELECT date, city, count(rain) AS hodiny_s_destem
	FROM weather2
	WHERE rain > 0
	GROUP BY date, city),
pocasi3 AS (
	SELECT date, city, max(gust) AS max_naraz_vitr
	FROM weather2
	GROUP BY date, city)

	
	LEFT JOIN pocasi1
		ON cou.capital_city = pocasi1.city