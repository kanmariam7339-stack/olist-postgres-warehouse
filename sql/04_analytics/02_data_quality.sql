DROP VIEW IF EXISTS analytics.v_data_quality;
CREATE VIEW analytics.v_data_quality AS
WITH checks AS (
  SELECT 'fact rows equal staging order_items' AS check_name,
         abs((SELECT count(*) FROM dwh.fact_order_items)
           - (SELECT count(*) FROM staging.order_items)) AS failing_rows,
         0 AS expected_rows
  UNION ALL SELECT 'fact revenue equals staging revenue',
         (CASE WHEN (SELECT sum(price) FROM dwh.fact_order_items)
                  = (SELECT sum(price) FROM staging.order_items) THEN 0 ELSE 1 END)::bigint, 0
  UNION ALL SELECT 'items with null or non-positive price',
         (SELECT count(*) FROM dwh.fact_order_items WHERE price IS NULL OR price <= 0), 0
  UNION ALL SELECT 'delivered orders with no delivery date (known, Issue 2)',
         (SELECT count(*) FROM staging.orders
          WHERE order_status = 'delivered' AND delivered_customer_ts IS NULL), 8
  UNION ALL SELECT 'orders delivered before they were purchased',
         (SELECT count(*) FROM staging.orders
          WHERE delivered_customer_ts < purchase_ts), 0
  UNION ALL SELECT 'review scores outside 1 to 5',
         (SELECT count(*) FROM staging.order_reviews
          WHERE review_score IS NULL OR review_score NOT BETWEEN 1 AND 5), 0
  UNION ALL SELECT 'sellers without exactly one current version',
         (SELECT count(*) FROM (SELECT seller_id FROM dwh.dim_seller
            GROUP BY seller_id
            HAVING count(*) FILTER (WHERE is_current) <> 1) x), 0
  UNION ALL SELECT 'overlapping seller versions',
         (SELECT count(*) FROM dwh.dim_seller a
          JOIN dwh.dim_seller b
            ON a.seller_id = b.seller_id AND a.seller_key < b.seller_key
           AND a.valid_from < b.valid_to AND b.valid_from < a.valid_to), 0
)
SELECT check_name, failing_rows, expected_rows,
       CASE WHEN failing_rows = expected_rows THEN 'OK' ELSE 'FAIL' END AS status
FROM checks;
