DROP TABLE IF EXISTS dwh.fact_order_items;

CREATE TABLE dwh.fact_order_items (
  order_id            text NOT NULL,
  order_item_id       int  NOT NULL,
  customer_key        int  NOT NULL REFERENCES dwh.dim_customer,
  product_key         int  NOT NULL REFERENCES dwh.dim_product,
  seller_key          int  NOT NULL REFERENCES dwh.dim_seller,
  purchase_date_key   int  NOT NULL REFERENCES dwh.dim_date,
  delivered_date_key  int  REFERENCES dwh.dim_date,   -- NULL if not delivered
  estimated_date_key  int  REFERENCES dwh.dim_date,
  order_status        text,
  price               numeric(10,2),
  freight_value       numeric(10,2),
  delivery_days       int,   -- purchase to delivery
  delivery_delay_days int,   -- delivery minus estimate (positive = late)
  PRIMARY KEY (order_id, order_item_id)
);

INSERT INTO dwh.fact_order_items
SELECT oi.order_id, oi.order_item_id,
       dc.customer_key, dp.product_key, ds.seller_key,
       to_char(o.purchase_ts, 'YYYYMMDD')::int,
       to_char(o.delivered_customer_ts, 'YYYYMMDD')::int,
       to_char(o.estimated_delivery_ts, 'YYYYMMDD')::int,
       o.order_status, oi.price, oi.freight_value,
       o.delivered_customer_ts::date - o.purchase_ts::date,
       o.delivered_customer_ts::date - o.estimated_delivery_ts::date
FROM staging.order_items oi
JOIN staging.orders    o  ON o.order_id    = oi.order_id
JOIN staging.customers c  ON c.customer_id = o.customer_id
JOIN dwh.dim_customer  dc ON dc.customer_unique_id = c.customer_unique_id
JOIN dwh.dim_product   dp ON dp.product_id = oi.product_id
JOIN dwh.dim_seller    ds ON ds.seller_id  = oi.seller_id AND ds.is_current;