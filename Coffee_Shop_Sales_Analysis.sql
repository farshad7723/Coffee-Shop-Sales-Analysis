-- Coffee Shop Sales Analysis
-- MySQL 8+ | January-June 2023 | Maven Analytics sample data
-- Extracted from Coffee_Shop_SQL_Guide.md.
-- Data is already imported: keep the LOAD DATA block commented out.
-- Local import path is a placeholder; CSV dates are assumed MM/DD/YYYY.

-- Create and select the project database.
CREATE DATABASE IF NOT EXISTS coffee_shop_sales;
USE coffee_shop_sales;
SELECT DATABASE();


-- Create the sales table if it does not already exist.
CREATE TABLE IF NOT EXISTS coffee_shop_sales.sales (
    transaction_id INT PRIMARY KEY,
    transaction_date DATE,
    transaction_time TIME,
    transaction_qty INT,
    store_id INT,
    store_location VARCHAR(50),
    product_id INT,
    unit_price DECIMAL(10,2),
    product_category VARCHAR(50),
    product_type VARCHAR(100),
    product_detail VARCHAR(150)
);

DESCRIBE coffee_shop_sales.sales;


-- Import the CSV into the existing sales table.
-- Already completed: do not rerun against the populated table.
/*
LOAD DATA LOCAL INFILE '/full/path/Coffee_Shop_Sales.csv'
INTO TABLE coffee_shop_sales.sales
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    transaction_id,
    @raw_date,
    transaction_time,
    transaction_qty,
    store_id,
    store_location,
    product_id,
    unit_price,
    product_category,
    product_type,
    @raw_detail
)
SET
    transaction_date = STR_TO_DATE(@raw_date, '%m/%d/%Y'),
    product_detail = TRIM(TRAILING '\r' FROM @raw_detail);
*/


-- Setup only; administrative permission may be required.
-- SET GLOBAL local_infile = ON;
SHOW GLOBAL VARIABLES LIKE 'local_infile';


-- Verify the imported row count, date range, and missing dates.
SELECT
    COUNT(*) AS total_rows,
    MIN(transaction_date) AS first_date,
    MAX(transaction_date) AS last_date,
    SUM(transaction_date IS NULL) AS missing_dates
FROM coffee_shop_sales.sales;

-- Findings:
-- Imported 149,116 rows.
-- Dates range from January 1 to June 30, 2023.
-- No missing transaction dates were found.


-- Check for missing, zero, or negative quantities and unit prices.
SELECT
    SUM(transaction_qty IS NULL) AS missing_quantity,
    SUM(unit_price IS NULL) AS missing_price,
    SUM(transaction_qty <= 0) AS non_positive_quantity,
    SUM(unit_price <= 0) AS non_positive_price
FROM coffee_shop_sales.sales;

-- Findings:
-- All four checks returned 0.
-- No corrections were needed based on these checks.
-- Other columns require separate quality checks.


-- Calculate total transactions, units sold, and sales.
-- Sales calculated as quantity multiplied by unit price.
SELECT
    COUNT(*) AS total_transactions,
    SUM(transaction_qty) AS total_units_sold,
    SUM(transaction_qty * unit_price) AS total_sales
FROM coffee_shop_sales.sales;

-- Findings: January-June 2023
-- Recorded 149,116 transactions and sold 214,470 units,
-- generating $698,812.33 in sales.


-- Compare transactions, units sold, and sales by store.
SELECT
    store_location,
    COUNT(*) AS total_transactions,
    SUM(transaction_qty) AS total_units_sold,
    SUM(transaction_qty * unit_price) AS total_sales
FROM coffee_shop_sales.sales
GROUP BY store_location
ORDER BY total_sales DESC;

-- Findings:
-- Hell's Kitchen generated the highest sales ($236,511.17)
-- and recorded the most transactions (50,735).
-- Lower Manhattan sold the most units (71,742),
-- but generated the lowest sales ($230,057.25).


-- Compare average transaction value and sales per unit by store.
SELECT
    store_location,
    ROUND(
        SUM(transaction_qty * unit_price) / COUNT(*),
        2
    ) AS avg_transaction_value,
    ROUND(
        SUM(transaction_qty * unit_price) / SUM(transaction_qty),
        2
    ) AS avg_sales_per_unit
FROM coffee_shop_sales.sales
GROUP BY store_location
ORDER BY avg_transaction_value DESC;

-- Findings:
-- Lower Manhattan had the highest average transaction value ($4.81)
-- but the lowest average sales per unit ($3.21).
-- Hell's Kitchen had the highest average sales per unit ($3.30).


-- Compare average units sold per transaction by store.
SELECT
    store_location,
    ROUND(
        SUM(transaction_qty) / COUNT(*),
        2
    ) AS avg_units_per_transaction
FROM coffee_shop_sales.sales
GROUP BY store_location
ORDER BY avg_units_per_transaction DESC;

-- Findings:
-- Lower Manhattan had the highest average units per transaction (1.50),
-- followed by Hell's Kitchen (1.41) and Astoria (1.40).


-- Compare units sold and sales by category across stores.
SELECT
    store_location,
    product_category,
    SUM(transaction_qty) AS total_units_sold,
    SUM(transaction_qty * unit_price) AS total_sales
FROM coffee_shop_sales.sales
GROUP BY store_location, product_category
ORDER BY store_location, total_units_sold DESC;

-- Findings:
-- Coffee and Tea were the top two categories by units sold
-- across all three stores.
-- Lower Manhattan sold the most Flavours units (4,709),
-- with average sales of $0.80 per unit.
-- Hell's Kitchen generated the highest Coffee beans sales
-- ($18,635.10) and sold the most units in that category (790).


-- Calculate each category's share of units sold within each store.
SELECT
    store_location,
    product_category,
    SUM(transaction_qty) AS category_units,
    ROUND(
        100.0 * SUM(transaction_qty)
        / SUM(SUM(transaction_qty)) OVER (
            PARTITION BY store_location
        ),
        2
    ) AS unit_share_pct
FROM coffee_shop_sales.sales
GROUP BY store_location, product_category
ORDER BY store_location, unit_share_pct DESC;

-- Findings:
-- Flavours accounted for 6.56% of units sold in Lower Manhattan,
-- compared with 5.01% in Hell's Kitchen and 3.11% in Astoria.
-- Hell's Kitchen had the highest Coffee beans unit share (1.10%).
-- Percentages represent unit shares, not revenue shares.


-- Summarize monthly sales and transactions.
SELECT
    DATE_FORMAT(transaction_date, '%Y-%m') AS sales_month,
    COUNT(*) AS total_transactions,
    SUM(transaction_qty * unit_price) AS total_sales
FROM coffee_shop_sales.sales
GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
ORDER BY sales_month;

-- Findings:
-- Sales declined in February, then increased each month
-- from March through June.
-- June had the highest sales ($166,485.88)
-- and the most transactions (35,352).


-- Identify the busiest hours by transaction count.
SELECT
    HOUR(transaction_time) AS sales_hour,
    COUNT(*) AS total_transactions,
    SUM(transaction_qty * unit_price) AS total_sales
FROM coffee_shop_sales.sales
GROUP BY HOUR(transaction_time)
ORDER BY total_transactions DESC;

-- Findings:
-- 10:00-10:59 AM had the most transactions (18,545)
-- and the highest sales ($88,673.39).
-- The three busiest hourly periods were between
-- 8:00 AM and 10:59 AM across all stores combined.


-- Identify the top 10 products by sales revenue.
SELECT
    product_id,
    product_detail,
    SUM(transaction_qty) AS total_units_sold,
    SUM(transaction_qty * unit_price) AS total_sales
FROM coffee_shop_sales.sales
GROUP BY product_id, product_detail
ORDER BY total_sales DESC
LIMIT 10;

-- Findings:
-- Sustainably Grown Organic Lg generated the highest
-- product sales revenue ($21,151.75).
-- Among the top 10 products by revenue, Dark chocolate Lg
-- had the most units sold (4,668).

