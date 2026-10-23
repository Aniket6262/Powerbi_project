-- ============================================================================
-- 02_load_data.sql   |   Load the generated CSVs into the warehouse
-- ----------------------------------------------------------------------------
-- Uses PostgreSQL's \copy (client-side, no superuser needed).
-- Run this from the project root with psql, e.g.:
--
--     psql -d ecommerce -f sql/02_load_data.sql
--
-- \copy resolves paths relative to where psql is launched, so launch it
-- from the repository root (the folder that contains the data/ directory).
--
-- dim_date is populated with a generate_series() call rather than from a CSV.
-- ============================================================================

-- 1) Dimensions with CSV data ------------------------------------------------
\copy dim_customer(customer_id, first_name, last_name, email, country, signup_date, acquisition_channel) FROM 'data/customers.csv' WITH (FORMAT csv, HEADER true);

\copy dim_product(product_id, product_name, category, unit_price, unit_cost) FROM 'data/products.csv' WITH (FORMAT csv, HEADER true);

-- 2) dim_date: generate one row per day across the data range -----------------
INSERT INTO dim_date (date_key, day, month, month_name, quarter, year, day_of_week, is_weekend)
SELECT
    d::date                                        AS date_key,
    EXTRACT(DAY   FROM d)::int                     AS day,
    EXTRACT(MONTH FROM d)::int                     AS month,
    TO_CHAR(d, 'Mon')                              AS month_name,
    EXTRACT(QUARTER FROM d)::int                   AS quarter,
    EXTRACT(YEAR  FROM d)::int                      AS year,
    TRIM(TO_CHAR(d, 'Day'))                        AS day_of_week,
    (EXTRACT(ISODOW FROM d) IN (6, 7))             AS is_weekend
FROM generate_series('2023-01-01'::date, '2024-12-31'::date, interval '1 day') AS d;

-- 3) Fact-adjacent header + fact ---------------------------------------------
\copy orders(order_id, customer_id, order_date, status, order_total) FROM 'data/orders.csv' WITH (FORMAT csv, HEADER true);

\copy fact_order_items(order_item_id, order_id, product_id, quantity, unit_price, discount, line_revenue) FROM 'data/order_items.csv' WITH (FORMAT csv, HEADER true);

-- 4) Quick sanity counts ------------------------------------------------------
SELECT 'dim_customer'     AS table_name, COUNT(*) AS rows FROM dim_customer
UNION ALL SELECT 'dim_product',      COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_date',         COUNT(*) FROM dim_date
UNION ALL SELECT 'orders',           COUNT(*) FROM orders
UNION ALL SELECT 'fact_order_items', COUNT(*) FROM fact_order_items;
