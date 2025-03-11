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
SET country = 'Czechia'
WHERE country = 'Czech Republic';
UPDATE covid19_tests2 
SET country = 'Congo (Kinshasa)'
WHERE country = 'Democratic Republic of Congo';
UPDATE covid19_tests2 
SET country = 'North Macedonia'
WHERE country = 'Macedonia';
UPDATE covid19_tests2 
SET country = 'Burma'
WHERE country = 'Myanmar';
UPDATE covid19_tests2 
SET country = 'Korea, South'
WHERE country = 'South Korea';
UPDATE covid19_tests2 
SET country = 'Taiwan*'
WHERE country = 'Taiwan';
UPDATE covid19_tests2 
SET country = 'US'
WHERE country = 'United States';
-- dokončit


-- TVORBA PRIMÁRNÍ TABULKY
CREATE OR REPLACE TABLE t_adela_prystaszova_projekt_SQL_final
SELECT country
FROM 