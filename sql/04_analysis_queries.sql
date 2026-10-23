-- ============================================================================
-- 04_analysis_queries.sql   |   Standalone analytical queries
-- ----------------------------------------------------------------------------
-- These answer concrete business questions and double as interview talking
-- points. Each can be run on its own. They rely only on the base tables
-- (so they work even if the views in 03_views.sql were not created).
-- ============================================================================

-- Q1. Headline KPIs (delivered orders only) ----------------------------------
--     Total revenue, total profit, orders, unique customers, AOV.
SELECT
    SUM(f.line_revenue)                                   AS total_revenue,
    SUM(f.line_revenue - p.unit_cost * f.quantity)        AS total_profit,
    COUNT(DISTINCT o.order_id)                            AS total_orders,
    COUNT(DISTINCT o.customer_id)                         AS active_customers,
    ROUND(SUM(f.line_revenue) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM fact_order_items f
JOIN orders      o ON o.order_id   = f.order_id
JOIN dim_product p ON p.product_id = f.product_id
WHERE o.status = 'Delivered';

-- Q2. Monthly revenue trend with month-over-month growth ---------------------
WITH monthly AS (
    SELECT TO_CHAR(o.order_date, 'YYYY-MM') AS year_month,
           SUM(f.line_revenue)              AS revenue
    FROM fact_order_items f
    JOIN orders o ON o.order_id = f.order_id
    WHERE o.status = 'Delivered'
    GROUP BY TO_CHAR(o.order_date, 'YYYY-MM')
)
SELECT
    year_month,
    revenue,
    LAG(revenue) OVER (ORDER BY year_month)                    AS prev_month,
    ROUND( (revenue - LAG(revenue) OVER (ORDER BY year_month))
           / NULLIF(LAG(revenue) OVER (ORDER BY year_month), 0) * 100, 1) AS mom_growth_pct
FROM monthly
ORDER BY year_month;

-- Q3. Top 10 products by revenue ---------------------------------------------
SELECT
    p.product_name,
    p.category,
    SUM(f.quantity)     AS units_sold,
    SUM(f.line_revenue) AS revenue
FROM fact_order_items f
JOIN orders      o ON o.order_id   = f.order_id
JOIN dim_product p ON p.product_id = f.product_id
WHERE o.status = 'Delivered'
GROUP BY p.product_name, p.category
ORDER BY revenue DESC
LIMIT 10;

-- Q4. Revenue and profit margin by category ----------------------------------
SELECT
    p.category,
    SUM(f.line_revenue)                                        AS revenue,
    SUM(f.line_revenue - p.unit_cost * f.quantity)             AS profit,
    ROUND( SUM(f.line_revenue - p.unit_cost * f.quantity)
           / NULLIF(SUM(f.line_revenue), 0) * 100, 1)          AS margin_pct
FROM fact_order_items f
JOIN orders      o ON o.order_id   = f.order_id
JOIN dim_product p ON p.product_id = f.product_id
WHERE o.status = 'Delivered'
GROUP BY p.category
ORDER BY revenue DESC;

-- Q5. New vs returning revenue by month --------------------------------------
--     A customer's first delivered order month is their "cohort"; any order in
--     a later month counts as returning revenue.
WITH first_month AS (
    SELECT customer_id,
           DATE_TRUNC('month', MIN(order_date)) AS cohort_month
    FROM orders WHERE status = 'Delivered'
    GROUP BY customer_id
)
SELECT
    DATE_TRUNC('month', o.order_date)::date AS order_month,
    CASE WHEN DATE_TRUNC('month', o.order_date) = fm.cohort_month
         THEN 'New' ELSE 'Returning' END    AS customer_type,
    SUM(f.line_revenue)                      AS revenue
FROM orders o
JOIN first_month fm      ON fm.customer_id = o.customer_id
JOIN fact_order_items f  ON f.order_id     = o.order_id
WHERE o.status = 'Delivered'
GROUP BY DATE_TRUNC('month', o.order_date), customer_type
ORDER BY order_month, customer_type;

-- Q6. Revenue by acquisition channel -----------------------------------------
SELECT
    c.acquisition_channel,
    COUNT(DISTINCT c.customer_id) AS customers,
    SUM(f.line_revenue)           AS revenue,
    ROUND(SUM(f.line_revenue) / COUNT(DISTINCT c.customer_id), 2) AS revenue_per_customer
FROM fact_order_items f
JOIN orders      o ON o.order_id   = f.order_id
JOIN dim_customer c ON c.customer_id = o.customer_id
WHERE o.status = 'Delivered'
GROUP BY c.acquisition_channel
ORDER BY revenue DESC;

-- Q7. Return rate by category ------------------------------------------------
SELECT
    p.category,
    COUNT(DISTINCT o.order_id)                                              AS total_orders,
    COUNT(DISTINCT o.order_id) FILTER (WHERE o.status = 'Returned')         AS returned_orders,
    ROUND( COUNT(DISTINCT o.order_id) FILTER (WHERE o.status = 'Returned')::numeric
           / NULLIF(COUNT(DISTINCT o.order_id), 0) * 100, 1)               AS return_rate_pct
FROM fact_order_items f
JOIN orders      o ON o.order_id   = f.order_id
JOIN dim_product p ON p.product_id = f.product_id
GROUP BY p.category
ORDER BY return_rate_pct DESC;

-- Q8. RFM segment sizes and their share of revenue ---------------------------
--     (Requires vw_customer_rfm from 03_views.sql.)
SELECT
    segment,
    COUNT(*)                                        AS customers,
    ROUND(AVG(monetary), 2)                         AS avg_spend,
    SUM(monetary)                                   AS segment_revenue,
    ROUND(SUM(monetary) / SUM(SUM(monetary)) OVER () * 100, 1) AS pct_of_revenue
FROM vw_customer_rfm
GROUP BY segment
ORDER BY segment_revenue DESC;
