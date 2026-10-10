DROP TABLE IF EXISTS dwh.fact_order_items, dwh.dim_customer, dwh.dim_product,
  dwh.dim_seller, dwh.dim_date CASCADE;

-- DATE: one row per calendar day
CREATE TABLE dwh.dim_date (
  date_key    int PRIMARY KEY,          -- e.g. 20180317
  full_date   date NOT NULL,
  year        int, quarter int, month int, month_name text,
  day         int, day_of_week int, day_name text, is_weekend boolean
);
INSERT INTO dwh.dim_date
SELECT to_char(d, 'YYYYMMDD')::int, d::date,
       extract(year FROM d)::int, extract(quarter FROM d)::int,
       extract(month FROM d)::int, trim(to_char(d, 'Month')),
       extract(day FROM d)::int, extract(isodow FROM d)::int,
       trim(to_char(d, 'Day')), extract(isodow FROM d) IN (6, 7)
FROM generate_series('2016-01-01'::timestamp, '2018-12-31'::timestamp,
                     interval '1 day') AS d;

-- CUSTOMER: one row per real person, with their most recent location
CREATE TABLE dwh.dim_customer (
  customer_key       int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_unique_id text NOT NULL UNIQUE,
  zip_code_prefix    text, city text, state text
);
INSERT INTO dwh.dim_customer (customer_unique_id, zip_code_prefix, city, state)
SELECT DISTINCT ON (c.customer_unique_id)
       c.customer_unique_id, c.zip_code_prefix, c.city, c.state
FROM staging.customers c
JOIN staging.orders o USING (customer_id)
ORDER BY c.customer_unique_id, o.purchase_ts DESC;

-- PRODUCT
CREATE TABLE dwh.dim_product (
  product_key        int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_id         text NOT NULL UNIQUE,
  category_pt        text, category_en text,
  name_length        int, description_length int, photos_qty int,
  weight_g           numeric, length_cm numeric, height_cm numeric, width_cm numeric
);
INSERT INTO dwh.dim_product (product_id, category_pt, category_en, name_length,
  description_length, photos_qty, weight_g, length_cm, height_cm, width_cm)
SELECT product_id, category_pt, category_en, name_length,
       description_length, photos_qty, weight_g, length_cm, height_cm, width_cm
FROM staging.products ORDER BY product_id;

-- SELLER (SCD2-ready: Day 4 will add history)
CREATE TABLE dwh.dim_seller (
  seller_key      int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  seller_id       text NOT NULL,
  zip_code_prefix text, city text, state text,
  valid_from      date NOT NULL DEFAULT '1900-01-01',
  valid_to        date NOT NULL DEFAULT '9999-12-31',
  is_current      boolean NOT NULL DEFAULT true
);
INSERT INTO dwh.dim_seller (seller_id, zip_code_prefix, city, state)
SELECT seller_id, zip_code_prefix, city, state
FROM staging.sellers ORDER BY seller_id;