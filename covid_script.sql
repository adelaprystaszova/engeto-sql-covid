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

-- c) Vytvoření a úprava tabulky weather2 tak, aby v ní relevantní údaje byly vez jednotek
CREATE OR REPLACE TABLE weather2
SELECT *
FROM weather;
UPDATE weather2
SET temp = REPLACE(temp, ' °c', '');
UPDATE weather2
SET rain = REPLACE(rain, ' mm', '');
UPDATE weather2
SET gust = REPLACE(gust, ' km/h', '');


-- TVORBA VÝSLEDNÉ
/*Napojuji na lookup_table2 na proměnnou country/iso3 tabulky countries,
 * economies, life_expectancy, religion
 */
WITH pocasi1 AS (
	SELECT avg(temp)
	FROM weather2
	WHERE time NOT IN (00:00, 03:00)
	GROUP BY date, city),
pocasi2 AS (
	SELECT count(rain)
	FROM weather2
	WHERE rain > 0
	GROUP BY date, city),
pocasi3 AS (
	SELECT max(gust)
	FROM weather2
	GROUP BY date, city)


-- je potřeba překodovat rain, temp, gust na čiselne hodnoty, pak napojit

CREATE OR REPLACE TABLE t_adela_prystaszova_projekt_SQL_1
	SELECT 
		lt2.country AS stat, 
		lt2.iso3 AS iso3,
		lt2.population AS populace,
		cou.population_density AS hustota_zalidneni,
		cou.median_age_2018 AS median_veku_2018,
		eco.GDP AS GDP_2020 AS HDP_2020,
		eco.population AS populace_2020,
		le1965.life_expectancy AS nadeje_doziti_1965,
		le2015.life_expectancy AS nadeje_doziti_2015,
		rel.religion,
		rel.population AS religion_population
	FROM lookup_table2 AS lt2
	LEFT JOIN countries AS cou
		ON lt2.iso3 = cou.iso3
	LEFT JOIN economies eco
		ON lt2.country = eco.country
		WHERE eco.year = '2020'
	LEFT JOIN life_expectancy AS le1965
		ON lt2.country = le1965.country
		WHERE le1965.YEAR = '1965'
	LEFT JOIN life_expectancy AS le2015
		ON lt2.country = le2015.country
		WHERE le1965.YEAR = '2015'
	RIGHT JOIN religions AS rel
		ON lt2.country = rel.country
		WHERE rel.YEAR = '2020'
