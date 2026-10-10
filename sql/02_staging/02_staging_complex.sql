-- sql/02_staging/02_staging_complex.sql
-- Staging for the tables that need real cleaning: products, geolocation, order_reviews

DROP TABLE IF EXISTS staging.products, staging.geolocation,
  staging.order_reviews CASCADE;

-- 1) PRODUCTS: fix typos, fill missing categories, add English name
CREATE TABLE staging.products AS
SELECT p.product_id,
       COALESCE(NULLIF(p.product_category_name, ''), 'unknown') AS category_pt,
       COALESCE(t.product_category_name_english,
                NULLIF(p.product_category_name, ''),
                'unknown')                                       AS category_en,
       NULLIF(p.product_name_lenght, '')::numeric::int          AS name_length,
       NULLIF(p.product_description_lenght, '')::numeric::int   AS description_length,
       NULLIF(p.product_photos_qty, '')::numeric::int           AS photos_qty,
       NULLIF(p.product_weight_g, '')::numeric                  AS weight_g,
       NULLIF(p.product_length_cm, '')::numeric                 AS length_cm,
       NULLIF(p.product_height_cm, '')::numeric                 AS height_cm,
       NULLIF(p.product_width_cm, '')::numeric                  AS width_cm
FROM raw.products p
LEFT JOIN raw.category_translation t
       ON t.product_category_name = p.product_category_name;

-- 2) GEOLOCATION: one row per zip code
CREATE TABLE staging.geolocation AS
SELECT geolocation_zip_code_prefix                      AS zip_code_prefix,
       avg(NULLIF(geolocation_lat, '')::numeric)        AS lat,
       avg(NULLIF(geolocation_lng, '')::numeric)        AS lng,
       mode() WITHIN GROUP (ORDER BY geolocation_city)  AS city,
       mode() WITHIN GROUP (ORDER BY geolocation_state) AS state
FROM raw.geolocation
GROUP BY geolocation_zip_code_prefix;

-- 3) ORDER_REVIEWS: one row per (review_id, order_id), keep the latest answer
CREATE TABLE staging.order_reviews AS
SELECT DISTINCT ON (review_id, order_id)
       review_id,
       order_id,
       NULLIF(review_score, '')::int                  AS review_score,
       NULLIF(review_comment_title, '')               AS comment_title,
       NULLIF(review_comment_message, '')             AS comment_message,
       NULLIF(review_creation_date, '')::timestamp    AS creation_ts,
       NULLIF(review_answer_timestamp, '')::timestamp AS answer_ts
FROM raw.order_reviews
ORDER BY review_id,
         order_id,
         NULLIF(review_answer_timestamp, '')::timestamp DESC NULLS LAST;