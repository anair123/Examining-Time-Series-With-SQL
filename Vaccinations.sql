-- Preview OF DATASET
SELECT TOP(5)
	country,
	date,
	daily_vaccinations
FROM
	Vaccinations.dbo.Vaccinations

-- Create temp table that shows vaccinations of UK countries on a monthly levels
DROP TABLE IF EXISTS #Monthly_Vaccinations
CREATE TABLE #Monthly_Vaccinations(
Country varchar(50),
Year int,
Month int,
num_vaccinations float)

INSERT INTO #Monthly_Vaccinations
SELECT 
	country As Country,
	YEAR(date) AS Year,
	MONTH(date) AS Month,
	SUM(daily_vaccinations) AS Num_vaccinations
FROM 
	Vaccinations.dbo.Vaccinations
WHERE 
	-- keep countries in the UK
	country IN ('England', 'Northern Ireland', 'Scotland', 'Wales')
GROUP BY 
	country, YEAR(date), MONTH(date)
ORDER BY country, YEAR(date), MONTH(date)

-- preview of temp table
SELECT *
FROM #Monthly_Vaccinations



-- 1. What is the cummulative (running total) vaccinations for each country?
SELECT 
	Country,
	Year,
	Month,
	Num_vaccinations,
	SUM(num_vaccinations) OVER(PARTITION BY country ORDER BY Month) AS Total_vaccinations
FROM 
	#Monthly_Vaccinations

-- Create table that shows population of each country
DROP TABLE IF EXISTS Population
CREATE TABLE Population(
Country varchar(50),
Population int)

INSERT INTO Population 
VALUES 
	('England', 56286961),
	('Northern Ireland', 1893667),
	('Scotland', 5463300),
	('Wales', 3152879);

-- preview of Population table
SELECT *
FROM Population

-- 1. Which country has been the most successful in administering vaccines?

-- CTE for storing running total
WITH running_total AS(
SELECT 
	country,
	Year,
	Month,
	num_vaccinations,
	-- find the running total vaccinations
	SUM(num_vaccinations) OVER(PARTITION BY country ORDER BY Month) AS total_vaccinations
FROM 
	#Monthly_Vaccinations),

-- CTE for storing vaccinations per capita
vaccinations_per_capita AS (
SELECT R.Country,
	R.Year,
	R.Month,
	R.num_vaccinations,
	P.Population,
	-- compute vaccinations per 100k capira
	ROUND((R.num_vaccinations/P.Population)*100000,0) AS Vaccinations_per_100k_capita
FROM 
	running_total R
INNER JOIN Population P
	ON R.Country = p.Country)

SELECT Country, 
	Year,
	Month,
	Vaccinations_per_100k_capita
FROM 
	vaccinations_per_capita 
WHERE 
	-- Select records from the latest month
	Month = 
	(SELECT MAX(Month)
	FROM #Monthly_Vaccinations)
ORDER BY 
	Vaccinations_per_100k_capita DESC

-- 2. What is the running total vaccinations for each country?

WITH running_total AS(
SELECT 
	country,
	Year,
	Month,
	num_vaccinations,
  -- find the running total vaccinations
	SUM(num_vaccinations) OVER(PARTITION BY country ORDER BY Month) AS total_vaccinations
FROM 
	#Monthly_Vaccinations)
  
SELECT R.Country,
	R.Year,
	R.Month,
	R.num_vaccinations,
	P.Population,
	-- compute vaccinations per 100k capita
	ROUND((R.num_vaccinations/P.Population)*100000,0) AS Vaccinations_per_100k_capita
FROM running_total R
INNER JOIN Population P
	ON R.Country = p.Country

-- 3. What is the percent change in vaccinations from month to month?
WITH prev_count AS(
SELECT *,
	ISNULL(LAG(num_vaccinations) OVER(PARTITION BY Country ORDER BY Month),0) AS prev_vaccination
FROM #Monthly_Vaccinations)

SELECT *,
	ROUND((num_vaccinations - prev_vaccination)/ num_vaccinations *100,2) AS pct_change
FROM prev_count


-- 4. Which months registered the fewest vaccinations for each country (Worst 3 months)?
WITH vaccinations_ranked AS(
SELECT *,
	RANK() OVER(PARTITION BY Country ORDER BY num_vaccinations) as rk
FROM 
	#Monthly_Vaccinations)

SELECT Country,
	Year,
	Month,
	num_vaccinations
FROM 
	vaccinations_ranked
WHERE 
	-- select only the 3 highest ranking records 
	rk <=3



-- 5. What is the 3 month moving average vaccination for each country?
SELECT *,
  ROUND(AVG(num_vaccinations) OVER(PARTITION BY Country ORDER BY Month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW ),0)
   AS moving_average
FROM #Monthly_Vaccinations
