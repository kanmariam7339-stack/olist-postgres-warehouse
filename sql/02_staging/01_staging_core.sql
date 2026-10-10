DROP TABLE IF EXISTS staging.customers, staging.sellers, staging.orders,
  staging.order_items, staging.order_payments CASCADE;

CREATE TABLE staging.customers AS
SELECT customer_id,
       customer_unique_id,
       customer_zip_code_prefix AS zip_code_prefix,
       customer_city            AS city,
       customer_state           AS state
FROM raw.customers;

CREATE TABLE staging.sellers AS
SELECT seller_id,
       seller_zip_code_prefix AS zip_code_prefix,
       seller_city            AS city,
       seller_state           AS state
FROM raw.sellers;

CREATE TABLE staging.orders AS
SELECT order_id,
       customer_id,
       order_status,
       NULLIF(order_purchase_timestamp, '')::timestamp       AS purchase_ts,
       NULLIF(order_approved_at, '')::timestamp              AS approved_ts,
       NULLIF(order_delivered_carrier_date, '')::timestamp   AS delivered_carrier_ts,
       NULLIF(order_delivered_customer_date, '')::timestamp  AS delivered_customer_ts,
       NULLIF(order_estimated_delivery_date, '')::timestamp  AS estimated_delivery_ts
FROM raw.orders;

CREATE TABLE staging.order_items AS
SELECT order_id,
       NULLIF(order_item_id, '')::int              AS order_item_id,
       product_id,
       seller_id,
       NULLIF(shipping_limit_date, '')::timestamp  AS shipping_limit_ts,
       NULLIF(price, '')::numeric(10,2)            AS price,
       NULLIF(freight_value, '')::numeric(10,2)    AS freight_value
FROM raw.order_items;

CREATE TABLE staging.order_payments AS
SELECT order_id,
       NULLIF(payment_sequential, '')::int          AS payment_sequential,
       payment_type,
       NULLIF(payment_installments, '')::int        AS payment_installments,
       NULLIF(payment_value, '')::numeric(10,2)     AS payment_value
FROM raw.order_payments;