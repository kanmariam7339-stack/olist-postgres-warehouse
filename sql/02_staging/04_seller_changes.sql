DROP TABLE IF EXISTS staging.seller_changes;

CREATE TABLE staging.seller_changes AS
WITH activity AS (
  SELECT oi.seller_id,
         count(*) FILTER (WHERE o.purchase_ts <  '2018-01-01') AS before_cnt,
         count(*) FILTER (WHERE o.purchase_ts >= '2018-01-01') AS after_cnt
  FROM staging.order_items oi
  JOIN staging.orders o USING (order_id)
  GROUP BY oi.seller_id
)
SELECT s.seller_id,
       '20000'::text          AS new_zip_code_prefix,
       'rio de janeiro'::text AS new_city,
       'RJ'::text             AS new_state,
       DATE '2018-01-01'      AS change_date
FROM activity a
JOIN staging.sellers s USING (seller_id)
WHERE a.before_cnt >= 10 AND a.after_cnt >= 10 AND s.state <> 'RJ'
ORDER BY a.before_cnt + a.after_cnt DESC, s.seller_id
LIMIT 5;