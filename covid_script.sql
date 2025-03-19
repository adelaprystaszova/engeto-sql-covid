-- 1) KONTROLA PROMĚNNÝCH

-- a) kontrola proměnné country, pomocí které budu napojovat tabulky na tabulku lookup_table
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
-- v lookup_table chybí z covid19_tests 9 zemí, 7 z nich se vyskytuje pod jiným názvem
-- ostatní tabulky lze spolehlivě napojit přes název státu, případně přes kód ISO/ISO3

-- b) kontrola proměnné entity v covid19_tests;
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
-- 8 zemí, u kterých je více než jedna hodnota entity


-- 2) ÚPRAVA TABULEK

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
DELETE FROM covid19_tests2
WHERE 
	(country = 'France' AND entity = 'people tested')
	OR (country = 'India' AND entity = 'people tested')
	OR (country = 'Italy' AND entity = 'people tested')
	OR (country = 'Japan' AND entity = 'people tested (incl. non-PCR)')
	OR (country = 'Poland' AND entity = 'people tested')
	OR (country = 'Singapore' AND entity = 'people tested')
	OR (country = 'Sweden' AND entity = 'people tested')
	OR (country = 'United States' AND entity = 'units unclear (incl. non-PCR)')
;

-- c) vytvoření a úprava tabulky weather2 tak, aby v ní relevantní údaje byly bez jednotek a správného typu
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


-- 3) TVORBA VÝSLEDNÉ TABULKY

-- a)
CREATE OR REPLACE VIEW v1 AS
	SELECT 
		lt2.country AS stat, 
		lt2.iso3 AS iso3,
		cou.capital_city AS hlavni_mesto,
		eco.population AS populace_2019,
		cou.population_density AS hustota_zalidneni,
		eco.GDP AS HDP_2019,
		eco.gini AS giniho_koeficient_2019,
		eco.mortaliy_under5 AS detska_umrtnost_2019,
		cou.median_age_2018 AS median_veku_2018,
		le1965.life_expectancy AS nadeje_doziti_1965,
		le2015.life_expectancy AS nadeje_doziti_2015
	FROM lookup_table2 AS lt2
	LEFT JOIN countries AS cou
		ON lt2.iso3 = cou.iso3
	LEFT JOIN economies eco
		ON lt2.country = eco.country
		and eco.year = '2019'
	LEFT JOIN life_expectancy AS le1965
		ON lt2.country = le1965.country
		AND le1965.year = '1965'
	LEFT JOIN life_expectancy AS le2015
		ON lt2.country = le2015.country
		AND le2015.year = '2015';

-- b)
CREATE OR REPLACE VIEW v2 AS 
	SELECT 
		v1.*,	
		cbd.date AS datum,
		dayofweek(cbd.date) AS den_v_tydnu,
		MONTH(cbd.date) AS mesic,
		rel.religion AS nabozenstvi,
		rel.population AS nabozenstvi_populace,
		cbd.confirmed AS pocet_novych_pripadu
	FROM v1
	RIGHT JOIN religions AS rel
		ON v1.stat = rel.country
		AND rel.year = '2020'
	RIGHT JOIN covid19_basic_differences AS cbd
		ON v1.stat = cbd.country;

-- c)
CREATE OR REPLACE VIEW pocasi1 AS
	SELECT date, city, avg(temp) AS prumerna_denni_teplota
	FROM weather2
	WHERE time NOT IN ('00:00:00', '03:00:00')
	GROUP BY date, city;
CREATE OR REPLACE VIEW pocasi2 AS
	SELECT date, city, count(rain) AS pocet_h_s_destem
	FROM weather2
	WHERE rain > 0
	GROUP BY date, city;
CREATE OR REPLACE VIEW pocasi3 AS
	SELECT date, city, max(gust) AS max_naraz_vitr
	FROM weather2
	GROUP BY date, city;

-- d)
CREATE OR REPLACE VIEW v3 AS
	SELECT
		v2.*,
		ct2.tests_performed AS pocet_testu,
		po1.prumerna_denni_teplota,
		po2.pocet_h_s_destem,
		po3.max_naraz_vitr
	FROM v2
LEFT JOIN covid19_tests2 AS ct2
	ON v2.iso3 = ct2.iso
	AND v2.datum = ct2.date
LEFT JOIN pocasi1 AS po1
	ON v2.hlavni_mesto = po1.city
	AND v2.datum = po1.date
LEFT JOIN pocasi2 AS po2
	ON v2.hlavni_mesto = po2.city
	AND v2.datum = po2.date
LEFT JOIN pocasi3 AS po3
	ON v2.hlavni_mesto = po3.city
	AND v2.datum = po3.date;

-- e)
CREATE OR REPLACE TABLE t_adela_prystaszova_projekt_SQL_final AS
SELECT 
	stat,
	datum,
	pocet_novych_pripadu/populace_2019 AS mira_incidence,
	pocet_novych_pripadu/pocet_testu AS nove_pripady_ku_testum,
	CASE WHEN den_v_tydnu IN (5,6) THEN 1 ELSE 0 END AS vikend,
	CASE WHEN mesic IN (3,4,5) THEN '0'
		WHEN mesic IN (6,7,8) THEN '1'
		WHEN mesic IN (9,10,11) THEN '2'
		ELSE '3'
		END AS rocni_obdobi,
	hustota_zalidneni,
	HDP_2019/populace_2019 AS hdp_obyv_2019,
	giniho_koeficient_2019,
	detska_umrtnost_2019,
	nabozenstvi,
	(nabozenstvi_populace/populace_2019)*100 AS podil_nabozenstvi,
	nadeje_doziti_2015 - nadeje_doziti_1965 AS rozdil_e0_1965_2015,
	prumerna_denni_teplota,
	pocet_h_s_destem,
	max_naraz_vitr
FROM v3;

		
		
		
		


