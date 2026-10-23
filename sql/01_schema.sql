-- ============================================================================
-- 01_schema.sql   |   E-Commerce Sales Analytics
-- ----------------------------------------------------------------------------
-- Creates a star-schema data warehouse in PostgreSQL:
--   * fact_order_items   grain = one row per product line within an order
--   * dim_customer       one row per customer
--   * dim_product        one row per product
--   * dim_date           one row per calendar day in the data range
--
-- Run order:  01_schema.sql -> 02_load_data.sql -> 03_views.sql -> 04_analysis_queries.sql
-- ============================================================================

DROP TABLE IF EXISTS fact_order_items CASCADE;
DROP TABLE IF EXISTS orders           CASCADE;
DROP TABLE IF EXISTS dim_customer     CASCADE;
DROP TABLE IF EXISTS dim_product      CASCADE;
DROP TABLE IF EXISTS dim_date         CASCADE;

-- ----------------------------------------------------------------------------
-- Dimension: customer
-- ----------------------------------------------------------------------------
CREATE TABLE dim_customer (
    customer_id         INTEGER      PRIMARY KEY,
    first_name          VARCHAR(50),
    last_name           VARCHAR(50),
    email               VARCHAR(120),
    country             VARCHAR(60),
    signup_date         DATE,
    acquisition_channel VARCHAR(40)
);

-- ----------------------------------------------------------------------------
-- Dimension: product
-- ----------------------------------------------------------------------------
CREATE TABLE dim_product (
    product_id   INTEGER        PRIMARY KEY,
    product_name VARCHAR(120),
    category     VARCHAR(60),
    unit_price   NUMERIC(10,2),
    unit_cost    NUMERIC(10,2)
);

-- ----------------------------------------------------------------------------
-- Dimension: date
-- ----------------------------------------------------------------------------
CREATE TABLE dim_date (
    date_key     DATE    PRIMARY KEY,
    day          INTEGER,
    month        INTEGER,
    month_name   VARCHAR(12),
    quarter      INTEGER,
    year         INTEGER,
    day_of_week  VARCHAR(12),
    is_weekend   BOOLEAN
);

-- ----------------------------------------------------------------------------
-- Order header (kept as a bridge so the fact table can join to order-level
-- attributes such as status while staying at line-item grain)
-- ----------------------------------------------------------------------------
CREATE TABLE orders (
    order_id     INTEGER       PRIMARY KEY,
    customer_id  INTEGER       REFERENCES dim_customer(customer_id),
    order_date   DATE          REFERENCES dim_date(date_key),
    status       VARCHAR(20),
    order_total  NUMERIC(12,2)
);

-- ----------------------------------------------------------------------------
-- Fact: order items (the analytical grain)
-- ----------------------------------------------------------------------------
CREATE TABLE fact_order_items (
    order_item_id INTEGER       PRIMARY KEY,
    order_id      INTEGER       REFERENCES orders(order_id),
    product_id    INTEGER       REFERENCES dim_product(product_id),
    quantity      INTEGER,
    unit_price    NUMERIC(10,2),
    discount      NUMERIC(4,2),
    line_revenue  NUMERIC(12,2)
);

-- ----------------------------------------------------------------------------
-- Indexes to speed up the analytical joins / group-bys
-- ----------------------------------------------------------------------------
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_date     ON orders(order_date);
CREATE INDEX idx_foi_order       ON fact_order_items(order_id);
CREATE INDEX idx_foi_product     ON fact_order_items(product_id);
