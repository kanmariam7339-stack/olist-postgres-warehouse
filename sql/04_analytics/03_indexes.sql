CREATE INDEX IF NOT EXISTS ix_fact_seller_key        ON dwh.fact_order_items (seller_key);
CREATE INDEX IF NOT EXISTS ix_fact_customer_key      ON dwh.fact_order_items (customer_key);
CREATE INDEX IF NOT EXISTS ix_fact_product_key       ON dwh.fact_order_items (product_key);
CREATE INDEX IF NOT EXISTS ix_fact_purchase_date_key ON dwh.fact_order_items (purchase_date_key);

CREATE INDEX IF NOT EXISTS ix_reviews_order_id       ON staging.order_reviews (order_id);

ANALYZE dwh.fact_order_items;
ANALYZE staging.order_reviews;