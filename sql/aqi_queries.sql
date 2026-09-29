-- NOTE: Update the file path in the LOAD DATA INFILE statements below to your
-- local air_quality_clean.csv location before running this script.

CREATE DATABASE AQIAnalysis;

USE AQIAnalysis;

TRUNCATE TABLE air_quality;

CREATE TABLE air_quality(
  id INT auto_increment PRIMARY KEY,
  country VARCHAR(100),
  city VARCHAR(100),
  aqi_value INT,
  aqi_category VARCHAR(50),
  co_aqi_value INT,
  co_aqi_category VARCHAR(50),
  ozone_aqi_value INT,
  ozone_aqi_category VARCHAR(50),
  no2_aqi_value INT,
  no2_aqi_category VARCHAR(50),
  pm25_aqi_value INT,
  pm25_aqi_category VARCHAR(50)
  );
  
  CREATE INDEX idx_country ON air_quality(country);
  CREATE INDEX idx_category ON air_quality(aqi_category);
  
  -- Load Data
  
  LOAD DATA LOCAL INFILE 'C:/Users/thaku/OneDrive/Desktop/air_quality_clean.csv'
  INTO TABLE air_quality
  FIELDS TERMINATED BY ',' ENCLOSED BY '"'
  LINES TERMINATED BY '\N'
  IGNORE 1 ROWS
  (country,city,aqi_value,aqi_category,co_aqi_value,co_aqi_category,
  ozone_aqi_value, ozone_aqi_category, no2_aqi_value, no2_aqi_category,
 pm25_aqi_value, pm25_aqi_category);
 
 LOAD DATA LOCAL INFILE 'C:/Users/thaku/OneDrive/Desktop/air_quality_clean.csv'
INTO TABLE air_quality
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    country,
    city,
    aqi_value,
    aqi_category,
    co_aqi_value,
    co_aqi_category,
    ozone_aqi_value,
    ozone_aqi_category,
    no2_aqi_value,
    no2_aqi_category,
    pm25_aqi_value,
    pm25_aqi_category
);
 
 SET GLOBAL local_infile = 1;
 
 SHOW VARIABLES LIKE 'local_infile';

SELECT COUNT(*) AS total_rows
FROM air_quality;

SHOW WARNINGS LIMIT 20;

SHOW COUNT(*) WARNINGS;

DESCRIBE air_quality;

SHOW CREATE TABLE air_quality;

-- Top 10 Most Polluted Countries
SELECT country, ROUND(AVG(aqi_value),2) AS avg_aqi, COUNT(*) AS city_count
FROM air_quality
WHERE country <> 'Unknown'
GROUP BY country
HAVING COUNT(*) >= 5
ORDER BY avg_aqi DESC
LIMIT 10;

-- City Count and % Share per AQI Category
SELECT aqi_category, COUNT(*) AS city_count,ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM air_quality), 2) AS pct_share
FROM air_quality
GROUP BY aqi_category
ORDER BY city_count DESC;

-- Countries with Highest % of Hazardous Cities
SELECT country,ROUND(SUM(CASE WHEN aqi_category='Hazardous' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS hazardous_pct,COUNT(*) AS total_cities
FROM air_quality
WHERE country <> 'Unknown'
GROUP BY country
HAVING COUNT(*) >= 5
ORDER BY hazardous_pct DESC
LIMIT 15;


-- Average Pollutant Sub-Index by Category
SELECT aqi_category,
       ROUND(AVG(co_aqi_value),1) AS avg_co,
       ROUND(AVG(ozone_aqi_value),1) AS avg_ozone,
       ROUND(AVG(no2_aqi_value),1) AS avg_no2,
       ROUND(AVG(pm25_aqi_value),1) AS avg_pm25
FROM air_quality
GROUP BY aqi_category
ORDER BY avg_co DESC;


-- Rank Cities Within Each Country
SELECT country, city, aqi_value,
       RANK() OVER (PARTITION BY country ORDER BY aqi_value DESC) AS rank_in_country
FROM air_quality
WHERE country <> 'Unknown';

-- ROW_NUMBER vs. RANK vs. DENSE_RANK
SELECT country, city, aqi_value,
       ROW_NUMBER() OVER (ORDER BY aqi_value DESC) AS row_num,
       RANK()       OVER (ORDER BY aqi_value DESC) AS rnk,
       DENSE_RANK() OVER (ORDER BY aqi_value DESC) AS dense_rnk
FROM air_quality
LIMIT 20;

-- Running (Cumulative) Average per Country
SELECT country, city, aqi_value,
       ROUND(AVG(aqi_value) OVER (
           PARTITION BY country ORDER BY aqi_value
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS running_avg
FROM air_quality
WHERE country <> 'Unknown';

-- LAG/LEAD Neighbor Comparison
SELECT country, city, aqi_value,
       LAG(aqi_value)  OVER (PARTITION BY country ORDER BY aqi_value) AS prev_city_aqi,
       LEAD(aqi_value) OVER (PARTITION BY country ORDER BY aqi_value) AS next_city_aqi
FROM air_quality
WHERE country <> 'Unknown';


-- Countries Above the Global Average (Subquery)
SELECT country, ROUND(AVG(aqi_value),2) AS avg_aqi
FROM air_quality
WHERE country <> 'Unknown'
GROUP BY country
HAVING AVG(aqi_value) > (SELECT AVG(aqi_value) FROM air_quality)
ORDER BY avg_aqi DESC;


-- Same Result Rewritten as a CTE
WITH country_avg AS (
    SELECT country, AVG(aqi_value) AS avg_aqi
    FROM air_quality
    WHERE country <> 'Unknown'
    GROUP BY country
),
global_avg AS (
    SELECT AVG(aqi_value) AS overall_avg FROM air_quality
)
SELECT c.country, ROUND(c.avg_aqi,2) AS avg_aqi
FROM country_avg c, global_avg g
WHERE c.avg_aqi > g.overall_avg
ORDER BY c.avg_aqi DESC;

-- EXISTS Pattern
SELECT DISTINCT a.country, a.city, a.aqi_value
FROM air_quality a
WHERE EXISTS (
    SELECT 1 FROM air_quality b
    WHERE b.country = a.country AND b.aqi_category = 'Hazardous'
)
AND a.country <> 'Unknown';

-- Dominant Pollutant per City
SELECT country, city, aqi_value,
       CASE GREATEST(co_aqi_value, ozone_aqi_value, no2_aqi_value, pm25_aqi_value)
           WHEN co_aqi_value THEN 'CO'
           WHEN ozone_aqi_value THEN 'Ozone'
           WHEN no2_aqi_value THEN 'NO2'
           ELSE 'PM2.5'
       END AS dominant_pollutant
FROM air_quality;


-- Self-Join — Best and Worst City per Country
SELECT worst.country,
       worst.city AS most_polluted_city, worst.aqi_value AS worst_aqi,
       best.city  AS cleanest_city,best.aqi_value  AS best_aqi
FROM (SELECT country, city, aqi_value,
	  RANK() OVER (PARTITION BY country ORDER BY aqi_value DESC) AS rnk
      FROM air_quality WHERE country <> 'Unknown') worst
JOIN (SELECT country, city, aqi_value,
	  RANK() OVER (PARTITION BY country ORDER BY aqi_value ASC) AS rnk
      FROM air_quality WHERE country <> 'Unknown') best
  ON worst.country = best.country
WHERE worst.rnk = 1 AND best.rnk = 1;

-- UNION — Combined Watchlist
SELECT country, city, aqi_value, 'WATCHLIST_HAZARD' AS list_type
FROM air_quality WHERE aqi_category = 'Hazardous'
UNION
SELECT country, city, aqi_value, 'WATCHLIST_CLEAN' AS list_type
FROM air_quality WHERE aqi_category = 'Good' AND aqi_value <= 20;


-- Reusable View — Country Summary
CREATE VIEW country_summary AS
SELECT country,
       COUNT(*) AS city_count,
       ROUND(AVG(aqi_value),2) AS avg_aqi,
       ROUND(SUM(CASE WHEN aqi_category='Hazardous' THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS hazardous_pct
FROM air_quality
WHERE country <> 'Unknown'
GROUP BY country;

SELECT * FROM country_summary ORDER BY avg_aqi DESC LIMIT 10;

-- Stored Procedure — Parameterized Top-N Countries
DELIMITER //
CREATE PROCEDURE GetTopPollutedCountries(IN min_cities INT, IN top_n INT)
BEGIN
    SELECT country, ROUND(AVG(aqi_value),2) AS avg_aqi, COUNT(*) AS city_count
    FROM air_quality
    WHERE country <> 'Unknown'
    GROUP BY country
    HAVING COUNT(*) >= min_cities
    ORDER BY avg_aqi DESC
    LIMIT top_n;
END //
DELIMITER ;

CALL GetTopPollutedCountries(5, 10);

-- GROUP BY with ROLLUP (Grand Total Row)
SELECT
    COALESCE(country, 'GRAND TOTAL') AS country,
    ROUND(AVG(aqi_value),2) AS avg_aqi,
    COUNT(*) AS city_count
FROM air_quality
WHERE country <> 'Unknown'
GROUP BY country WITH ROLLUP
ORDER BY country;



-- NTILE — Quartile Bucketing of Cities by AQI
SELECT country, city, aqi_value,
       NTILE(4) OVER (ORDER BY aqi_value) AS aqi_quartile
FROM air_quality
WHERE country <> 'Unknown';

-- Correlated Subquery — Cities Above Their Own Country’s Average
SELECT a.country, a.city, a.aqi_value
FROM air_quality a
WHERE a.aqi_value > (
    SELECT AVG(b.aqi_value)
    FROM air_quality b
    WHERE b.country = a.country
)
AND a.country <> 'Unknown'
ORDER BY a.country, a.aqi_value DESC;


-- Multi-Level CTE — Top-3 Countries’ Hazardous City Detail
WITH ranked_countries AS (
    SELECT country,
           ROUND(SUM(CASE WHEN aqi_category='Hazardous' THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS hazardous_pct,
           RANK() OVER (ORDER BY SUM(CASE WHEN aqi_category='Hazardous' THEN 1 ELSE 0 END)*100.0/COUNT(*) DESC) AS country_rank
    FROM air_quality
    WHERE country <> 'Unknown'
    GROUP BY country
    HAVING COUNT(*) >= 5
),
top3 AS (
    SELECT country, hazardous_pct FROM ranked_countries WHERE country_rank <= 3
)
SELECT t.country, t.hazardous_pct, a.city, a.aqi_value, a.aqi_category
FROM top3 t
JOIN air_quality a ON a.country = t.country
WHERE a.aqi_category IN ('Hazardous', 'Very Unhealthy')
ORDER BY t.hazardous_pct DESC, a.aqi_value DESC;


