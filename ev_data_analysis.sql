CREATE DATABASE ev_charging;
USE ev_charging;

CREATE TABLE charging_records (
    UserID INT,
    ChargerID INT,
    ChargerCompany INT,
    Location VARCHAR(50),
    ChargerType INT,
    StartDay DATE,
    StartTime TIME,
    EndDay DATE,
    EndTime TIME,
    StartDatetime DATETIME,
    EndDatetime DATETIME,
    Duration INT,
    Demand DECIMAL(10,2)
);

SELECT COUNT(*) AS total_sessions
FROM charging_records;

SELECT COUNT(DISTINCT UserID) AS total_users
FROM charging_records;

SELECT COUNT(DISTINCT ChargerID) AS total_chargers
FROM charging_records;

# 1. high demand chargers
SELECT
    ChargerID,
    COUNT(*) AS sessions,
    ROUND(AVG(Demand), 2) AS avg_demand,
    ROUND(SUM(Demand), 2) AS total_demand
FROM charging_records
GROUP BY ChargerID
HAVING COUNT(*) >= 30
ORDER BY avg_demand DESC, sessions DESC
LIMIT 15;

# 2. Demand based on location

SELECT
    Location,
    ROUND(SUM(Demand), 2) AS location_demand,
    ROUND(
        100 * SUM(Demand) / (SELECT SUM(Demand) FROM charging_records),
        2
    ) AS demand_share_pct
FROM charging_records
GROUP BY Location
ORDER BY demand_share_pct DESC;

# 3. users responsible for the largest share of demand

WITH user_demand AS (
    SELECT
        UserID,
        SUM(Demand) AS total_demand
    FROM charging_records
    GROUP BY UserID
)
SELECT
    UserID,
    ROUND(total_demand, 2) AS total_demand,
    ROUND(
        100 * total_demand / SUM(total_demand) OVER (),
        2
    ) AS demand_share_pct,
    RANK() OVER (ORDER BY total_demand DESC) AS demand_rank
FROM user_demand
ORDER BY total_demand DESC
LIMIT 20;

# 4. Peak vs off-peak demand

SELECT
    CASE
        WHEN HOUR(StartTime) BETWEEN 7 AND 10 THEN 'Morning Peak'
        WHEN HOUR(StartTime) BETWEEN 17 AND 21 THEN 'Evening Peak'
        ELSE 'Off-Peak'
    END AS period,
    COUNT(*) AS sessions,
    ROUND(AVG(Demand), 2) AS avg_demand,
    ROUND(SUM(Demand), 2) AS total_demand
FROM charging_records
GROUP BY period
ORDER BY total_demand DESC;

# 5. Monthly demand trend

SELECT
    YEAR(StartDay) AS year,
    MONTH(StartDay) AS month,
    COUNT(*) AS sessions,
    ROUND(SUM(Demand), 2) AS total_demand,
    ROUND(AVG(Demand), 2) AS avg_demand
FROM charging_records
GROUP BY YEAR(StartDay), MONTH(StartDay)
ORDER BY year, month;

# 6. Charger performance ranking

SELECT Location, ChargerID,
COUNT(*) AS sessions,
ROUND(SUM(Demand), 2) AS total_demand,
RANK() OVER (
PARTITION BY Location
ORDER BY SUM(Demand) DESC) 
AS charger_rank
FROM charging_records
GROUP BY Location, ChargerID
ORDER BY Location, charger_rank;

# 7. User activity trend 

WITH monthly_activity AS (
    SELECT
        UserID,
        DATE_FORMAT(StartDay, '%Y-%m') AS month,
        COUNT(*) AS sessions
    FROM charging_records
    GROUP BY UserID, DATE_FORMAT(StartDay, '%Y-%m')
),
activity_change AS (
    SELECT
        UserID,
        month,
        sessions,
        LAG(sessions) OVER (
            PARTITION BY UserID
            ORDER BY month
        ) AS previous_month_sessions
    FROM monthly_activity
)
SELECT UserID, month, sessions, previous_month_sessions, sessions - previous_month_sessions AS change_in_sessions
FROM activity_change
WHERE previous_month_sessions IS NOT NULL
ORDER BY change_in_sessions DESC;

# 8. Top users contribution to total demand

WITH user_demand AS (
    SELECT
        UserID,
        SUM(Demand) AS total_demand
    FROM charging_records
    GROUP BY UserID
),
ranked_users AS (
    SELECT
        UserID,
        total_demand,
        NTILE(10) OVER (ORDER BY total_demand DESC) AS demand_decile
    FROM user_demand
)
SELECT
    demand_decile,
    COUNT(*) AS users,
    ROUND(SUM(total_demand), 2) AS total_demand,
    ROUND(
        100 * SUM(total_demand) / (SELECT SUM(total_demand) FROM user_demand),
        2
    ) AS demand_share_pct
FROM ranked_users
GROUP BY demand_decile
ORDER BY demand_decile;