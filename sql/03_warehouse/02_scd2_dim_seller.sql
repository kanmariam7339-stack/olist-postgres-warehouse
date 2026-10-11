BEGIN;

-- A) Close the current version of every seller whose attributes changed
UPDATE dwh.dim_seller s
SET valid_to   = c.change_date,
    is_current = false
FROM staging.seller_changes c
WHERE s.seller_id = c.seller_id
  AND s.is_current
  AND (s.city, s.state) IS DISTINCT FROM (c.new_city, c.new_state);

-- B) Insert the new version (skipped if it already exists)
INSERT INTO dwh.dim_seller
       (seller_id, zip_code_prefix, city, state, valid_from, valid_to, is_current)
SELECT c.seller_id, c.new_zip_code_prefix, c.new_city, c.new_state,
       c.change_date, DATE '9999-12-31', true
FROM staging.seller_changes c
WHERE NOT EXISTS (
  SELECT 1 FROM dwh.dim_seller s
  WHERE s.seller_id = c.seller_id
    AND s.is_current
    AND (s.city, s.state) = (c.new_city, c.new_state)
);

COMMIT;