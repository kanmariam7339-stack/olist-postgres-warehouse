CREATE SCHEMA IF NOT EXISTS analytics;

-- 1. Monthly revenue, month-over-month growth, running total (LAG, SUM OVER)
DROP VIEW IF EXISTS analytics.v_monthly_revenue;
CREATE VIEW analytics.v_monthly_revenue AS
WITH monthly AS (
  SELECT make_date(d.year, d.month, 1) AS month_start,
         count(DISTINCT f.order_id)    AS orders,
         sum(f.price)                  AS revenue
  FROM dwh.fact_order_items f
  JOIN dwh.dim_date d ON d.date_key = f.purchase_date_key
  WHERE f.order_status = 'delivered'
  GROUP BY d.year, d.month
), with_prev AS (
  SELECT *, lag(revenue) OVER (ORDER BY month_start) AS prev_revenue
  FROM monthly
)
SELECT month_start, orders, revenue, prev_revenue,
       round(100.0 * (revenue - prev_revenue) / NULLIF(prev_revenue, 0), 1) AS growth_pct,
       sum(revenue) OVER (ORDER BY month_start) AS cumulative_revenue
FROM with_prev;

-- 2. Top 3 sellers per state (RANK, uses the SCD2 state at time of sale)
DROP VIEW IF EXISTS analytics.v_top_sellers_per_state;
CREATE VIEW analytics.v_top_sellers_per_state AS
WITH seller_rev AS (
  SELECT s.state, s.seller_id, count(*) AS items, sum(f.price) AS revenue
  FROM dwh.fact_order_items f
  JOIN dwh.dim_seller s ON s.seller_key = f.seller_key
  WHERE f.order_status = 'delivered'
  GROUP BY s.state, s.seller_id
), ranked AS (
  SELECT *, rank() OVER (PARTITION BY state ORDER BY revenue DESC) AS rnk
  FROM seller_rev
)
SELECT state, rnk, seller_id, items, revenue
FROM ranked WHERE rnk <= 3;

-- 3. Delivery delay vs review score (CTEs, CASE buckets; joins reviews at order level)
DROP VIEW IF EXISTS analytics.v_delivery_vs_review;
CREATE VIEW analytics.v_delivery_vs_review AS
WITH order_delivery AS (
  SELECT order_id, max(delivery_delay_days) AS delay_days
  FROM dwh.fact_order_items
  WHERE order_status = 'delivered' AND delivery_delay_days IS NOT NULL
  GROUP BY order_id
), order_review AS (
  SELECT order_id, avg(review_score) AS review_score
  FROM staging.order_reviews
  GROUP BY order_id
)
SELECT CASE WHEN d.delay_days <= 0 THEN '1 - on time or early'
            WHEN d.delay_days <= 7 THEN '2 - late 1 to 7 days'
            ELSE '3 - late 8+ days' END AS delivery_bucket,
       count(*) AS orders,
       round(avg(r.review_score), 2) AS avg_review_score
FROM order_delivery d
JOIN order_review r USING (order_id)
GROUP BY 1;

-- 4. Customer repeat rate (FILTER)
DROP VIEW IF EXISTS analytics.v_customer_repeat_rate;
CREATE VIEW analytics.v_customer_repeat_rate AS
WITH orders_per_customer AS (
  SELECT customer_key, count(DISTINCT order_id) AS orders
  FROM dwh.fact_order_items
  WHERE order_status = 'delivered'
  GROUP BY customer_key
)
SELECT count(*) AS customers,
       count(*) FILTER (WHERE orders >= 2) AS repeat_customers,
       round(100.0 * count(*) FILTER (WHERE orders >= 2) / count(*), 2) AS repeat_rate_pct
FROM orders_per_customer;

-- 5. Revenue by category with share of total (window over aggregate, RANK)
DROP VIEW IF EXISTS analytics.v_revenue_by_category;
CREATE VIEW analytics.v_revenue_by_category AS
WITH cat AS (
  SELECT p.category_en, count(*) AS items, sum(f.price) AS revenue
  FROM dwh.fact_order_items f
  JOIN dwh.dim_product p USING (product_key)
  WHERE f.order_status = 'delivered'
  GROUP BY p.category_en
)
SELECT category_en, items, revenue,
       round(100.0 * revenue / sum(revenue) OVER (), 2) AS share_pct,
       rank() OVER (ORDER BY revenue DESC) AS rnk
FROM cat;

-- 6. Payment mix (reads staging: payments are per order, not per item)
DROP VIEW IF EXISTS analytics.v_payment_mix;
CREATE VIEW analytics.v_payment_mix AS
SELECT payment_type,
       count(DISTINCT order_id) AS orders,
       sum(payment_value)       AS total_value,
       round(100.0 * sum(payment_value) / sum(sum(payment_value)) OVER (), 2) AS share_pct
FROM staging.order_payments
GROUP BY payment_type;

-- 7. Average delivery time by customer state (RANK over aggregate)
DROP VIEW IF EXISTS analytics.v_delivery_by_customer_state;
CREATE VIEW analytics.v_delivery_by_customer_state AS
SELECT c.state,
       count(DISTINCT f.order_id) AS orders,
       round(avg(f.delivery_days), 1) AS avg_delivery_days,
       rank() OVER (ORDER BY avg(f.delivery_days) DESC) AS slowest_rank
FROM dwh.fact_order_items f
JOIN dwh.dim_customer c USING (customer_key)
WHERE f.order_status = 'delivered' AND f.delivery_days IS NOT NULL
GROUP BY c.state;

-- 8. Best-selling product in each category (ROW_NUMBER)
DROP VIEW IF EXISTS analytics.v_top_product_per_category;
CREATE VIEW analytics.v_top_product_per_category AS
WITH prod AS (
  SELECT p.category_en, p.product_id, count(*) AS items, sum(f.price) AS revenue
  FROM dwh.fact_order_items f
  JOIN dwh.dim_product p USING (product_key)
  WHERE f.order_status = 'delivered'
  GROUP BY p.category_en, p.product_id
), ranked AS (
  SELECT *, row_number() OVER (PARTITION BY category_en ORDER BY revenue DESC, product_id) AS rn
  FROM prod
)
SELECT category_en, product_id, items, revenue
FROM ranked WHERE rn = 1;