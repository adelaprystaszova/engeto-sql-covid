-- Vytvoření primární tabulky t_adela_prystaszova_projekt_SQL_final
-- klíče: country, date
/*vysvětlované proměnné: 
 * počet nově nakažených na 100 000 obyvatel
	 * = počet nově nakažených/počet obyvatel*100 000
 * podíl pozitivních testů
	 * = počet nově nakažených/počet testovaných
*/
/* vysvětlující proměnné:
 * 	časové
	 * 	víkend/pracovní den (binární)
	 * 	roční období (0–3)
 * 	specifické pro stát
	 * 	hustota zalidnění
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
 */
-- využité tabulky: countries, economies, life_expectancy, 
-- religions, covid19_basic_differences, covid19_tests, 
-- weather, lookup_table



-- 1) kontrola proměnné country:
SELECT country
FROM covid19_basic_differences
WHERE country NOT IN (
	SELECT country
	FROM lookup_table
	)
GROUP BY country
;
-- v lookup_table nechybí žádná země z covid19_basic_differences 
SELECT country
FROM covid19_tests
WHERE country NOT IN (
	SELECT country
	FROM lookup_table
	)
GROUP BY country
;
-- v lookup_table chybí z covid19_tests:
/*
Czech Republic
Democratic Republic of Congo
Hong Kong
Macedonia
Myanmar
Palestine
South Korea
Taiwan
United States
*/

WITH country_diff AS (
	SELECT country
	FROM covid19_tests
	GROUP BY country)
SELECT country
FROM covid19_basic_differences
WHERE country NOT IN (
	SELECT country
	FROM country_diff)
GROUP BY country
;
-- z covid19_basic_differences chybí v covid19_tests 91 zemí

SELECT country
FROM covid19_tests
WHERE country NOT IN (
	SELECT country
	FROM covid19_basic_differences
	)
GROUP BY country
;
-- z covid19_tests chybí v covid19_basic_differences 12 zemí
/*Australia
Canada
China
Czech Republic
Democratic Republic of Congo
Hong Kong
Macedonia
Myanmar
Palestine
South Korea
Taiwan
United States
*/


-- 2) kontrola proměnné date
	-- covid19_basic_differences: 22.1.2020–23.5.2021
	-- covid_19_tests: 29.1.2020–21.11.2020


-- x) tvorba primární tabulky
CREATE OR REPLACE TABLE t_adela_prystaszova_projekt_SQL_final
SELECT country
FROM 