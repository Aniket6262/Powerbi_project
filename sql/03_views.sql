-- ============================================================================
-- 03_views.sql   |   Reporting views consumed by Power BI
-- ----------------------------------------------------------------------------
-- These views pre-shape the warehouse into clean, BI-friendly tables.
-- In Power BI you can "Get Data -> PostgreSQL" and simply select these views,
-- keeping heavy aggregation in the database rather than in the report.
-- Returned / Cancelled orders are excluded from revenue views so that KPIs
-- reflect realised net sales (status = 'Delivered').
-- ============================================================================

-- ----------------------------------------------------------------------------
-- A wide, denormalised sales line view: the main fact feed for Power BI.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_sales_detail AS
SELECT
    f.order_item_id,
    f.order_id,
    o.order_date,
    dd.year,
    dd.quarter,
    dd.month,
    dd.month_name,
    o.status,
    c.customer_id,
    c.country,
    c.acquisition_channel,
    p.product_id,
    p.product_name,
    p.category,
    f.quantity,
    f.unit_price,
    f.discount,
    f.line_revenue,
    (p.unit_cost * f.quantity)                       AS line_cost,
    (f.line_revenue - p.unit_cost * f.quantity)      AS line_profit
FROM fact_order_items f
JOIN orders       o  ON o.order_id    = f.order_id
JOIN dim_customer c  ON c.customer_id = o.customer_id
JOIN dim_product  p  ON p.product_id  = f.product_id
JOIN dim_date     dd ON dd.date_key   = o.order_date;

-- ----------------------------------------------------------------------------
-- Monthly revenue trend (delivered only).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_monthly_revenue AS
SELECT
    dd.year,
    dd.month,
    TO_CHAR(o.order_date, 'YYYY-MM')          AS year_month,
    COUNT(DISTINCT o.order_id)                AS orders,
    SUM(f.line_revenue)                       AS revenue,
    SUM(f.line_revenue - p.unit_cost * f.quantity) AS profit
FROM fact_order_items f
JOIN orders      o ON o.order_id   = f.order_id
JOIN dim_product p ON p.product_id = f.product_id
JOIN dim_date    dd ON dd.date_key = o.order_date
WHERE o.status = 'Delivered'
GROUP BY dd.year, dd.month, TO_CHAR(o.order_date, 'YYYY-MM')
ORDER BY dd.year, dd.month;

-- ----------------------------------------------------------------------------
-- Category performance (delivered only).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_category_performance AS
SELECT
    p.category,
    COUNT(DISTINCT o.order_id)                     AS orders,
    SUM(f.quantity)                                AS units_sold,
    SUM(f.line_revenue)                            AS revenue,
    SUM(f.line_revenue - p.unit_cost * f.quantity) AS profit,
    ROUND(AVG(f.discount) * 100, 2)                AS avg_discount_pct
FROM fact_order_items f
JOIN orders      o ON o.order_id   = f.order_id
JOIN dim_product p ON p.product_id = f.product_id
WHERE o.status = 'Delivered'
GROUP BY p.category
ORDER BY revenue DESC;

-- ----------------------------------------------------------------------------
-- RFM customer segmentation.
-- Recency  = days since last order (relative to latest order in the data)
-- Frequency= number of delivered orders
-- Monetary = total delivered revenue
-- Each dimension is scored 1-4 with NTILE; segment is a simple rule on R/F/M.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_customer_rfm AS
WITH bounds AS (
    SELECT MAX(order_date) AS snapshot_date FROM orders
),
base AS (
    SELECT
        o.customer_id,
        (SELECT snapshot_date FROM bounds) - MAX(o.order_date) AS recency_days,
        COUNT(DISTINCT o.order_id)                             AS frequency,
        SUM(f.line_revenue)                                    AS monetary
    FROM orders o
    JOIN fact_order_items f ON f.order_id = o.order_id
    WHERE o.status = 'Delivered'
    GROUP BY o.customer_id
),
scored AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,  -- 4 = most recent
        NTILE(4) OVER (ORDER BY frequency)         AS f_score,  -- 4 = most frequent
        NTILE(4) OVER (ORDER BY monetary)          AS m_score   -- 4 = highest spend
    FROM base
)
SELECT
    s.*,
    CASE
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 2                  THEN 'Loyal'
        WHEN r_score >= 3 AND f_score = 1                   THEN 'New / Promising'
        WHEN r_score = 2                                    THEN 'At Risk'
        ELSE                                                     'Lapsed'
    END AS segment
FROM scored s;

-- ----------------------------------------------------------------------------
-- Monthly acquisition cohorts + retention.
-- cohort_month = month of the customer's FIRST delivered order
-- order_month  = month of each subsequent delivered order
-- month_number = months elapsed since the cohort month
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_cohort_retention AS
WITH first_order AS (
    SELECT customer_id,
           DATE_TRUNC('month', MIN(order_date))::date AS cohort_month
    FROM orders
    WHERE status = 'Delivered'
    GROUP BY customer_id
),
activity AS (
    SELECT DISTINCT
           o.customer_id,
           DATE_TRUNC('month', o.order_date)::date AS order_month
    FROM orders o
    WHERE o.status = 'Delivered'
)
SELECT
    fo.cohort_month,
    a.order_month,
    (EXTRACT(YEAR  FROM a.order_month) - EXTRACT(YEAR  FROM fo.cohort_month)) * 12
      + (EXTRACT(MONTH FROM a.order_month) - EXTRACT(MONTH FROM fo.cohort_month)) AS month_number,
    COUNT(DISTINCT a.customer_id) AS active_customers
FROM first_order fo
JOIN activity a ON a.customer_id = fo.customer_id
GROUP BY fo.cohort_month, a.order_month
ORDER BY fo.cohort_month, a.order_month;
