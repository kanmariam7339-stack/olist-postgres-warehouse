# Staging tests

Checks that the `staging` layer is correct. Each query was run in the PSQL Tool / pgAdmin Query Tool.

## Summary

| #   | Test                                                 | Expected                                             | Result                                                         | Status |
| --- | ---------------------------------------------------- | ---------------------------------------------------- | -------------------------------------------------------------- | ------ |
| 1   | Row counts match raw                                 | 99,441 / 3,095 / 99,441 / 112,650 / 103,886 / 32,951 | identical                                                      | Pass   |
| 2   | geolocation has one row per zip code                 | 19,015                                               | 19,015                                                         | Pass   |
| 3   | order_reviews keeps every (review_id, order_id) pair | equals raw distinct pairs                            | 99,224 = 99,224                                                | Pass   |
| 4   | Primary and foreign keys exist                       | 8 PK + 6 FK = 14                                     | 14                                                             | Pass   |
| 5   | Column types are correct                             | integer, numeric, timestamp                          | as expected                                                    | Pass   |
| 6   | Date range preserved                                 | 2016-09-04 to 2018-10-17                             | 2016-09-04 21:15:19 to 2018-10-17 17:30:18                     | Pass   |
| 7   | No data lost in casts                                | 2,965 NULL delivery dates                            | 2,965                                                          | Pass   |
| 8   | Totals match raw                                     | identical sums                                       | identical                                                      | Pass   |
| 9   | Products without category labeled `unknown`          | 610                                                  | 610                                                            | Pass   |
| 10  | Categories missing from the translation file         | 2 categories                                         | to pc_gamer and portateis_cozinha_e_preparadores_de_alimentos. | pass   |

## Queries and results

### Test 1: row counts

```sql
SELECT 'customers' AS tbl, count(*) FROM staging.customers
UNION ALL SELECT 'sellers', count(*) FROM staging.sellers
UNION ALL SELECT 'orders', count(*) FROM staging.orders
UNION ALL SELECT 'order_items', count(*) FROM staging.order_items
UNION ALL SELECT 'order_payments', count(*) FROM staging.order_payments
UNION ALL SELECT 'products', count(*) FROM staging.products;
```

Result: sellers 3,095, products 32,951, order_payments 103,886, customers 99,441, orders 99,441, order_items 112,650. All equal to raw.

### Test 2: geolocation

```sql
SELECT count(*) AS geolocation FROM staging.geolocation;
```

Result: 19,015 (down from 1,000,163 in raw, one row per zip code).

### Test 3: reviews

```sql
SELECT
  (SELECT count(*) FROM staging.order_reviews) AS staging_rows,
  (SELECT count(*) FROM (SELECT DISTINCT review_id, order_id
                         FROM raw.order_reviews) x) AS raw_distinct_pairs;
```

Result: staging_rows 99,224 and raw_distinct_pairs 99,224. See Finding 1.

### Test 4: keys

```sql
SELECT table_name, constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'staging'
  AND constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
ORDER BY table_name, constraint_type;
```

Result: 14 rows. Primary keys on all 8 tables, foreign keys on orders (1), order_items (3), order_payments (1) and order_reviews (1).

### Test 5: types

```sql
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'staging'
  AND table_name IN ('orders', 'order_items', 'order_payments')
ORDER BY table_name, ordinal_position;
```

Result: ids and status are `text`, item and payment sequence numbers and installments are `integer`, price, freight and payment value are `numeric`, all date columns are `timestamp without time zone`.

### Test 6: date range

```sql
SELECT min(purchase_ts), max(purchase_ts) FROM staging.orders;
```

Result: 2016-09-04 21:15:19 to 2018-10-17 17:30:18, same as raw.

### Test 7: NULLs after casting

```sql
SELECT count(*) FILTER (WHERE delivered_customer_ts IS NULL) AS null_delivery_dates
FROM staging.orders;
```

Result: 2,965, same as raw. No date was lost or invalidated by the cast.

### Test 8: totals

```sql
SELECT
  (SELECT sum(price::numeric) FROM raw.order_items)            AS raw_price,
  (SELECT sum(price) FROM staging.order_items)                 AS staging_price,
  (SELECT sum(payment_value::numeric) FROM raw.order_payments) AS raw_payments,
  (SELECT sum(payment_value) FROM staging.order_payments)      AS staging_payments;
```

Result: price 13,591,643.70 in both layers, payments 16,008,872.12 in both layers.

### Test 9: unknown category

```sql
SELECT count(*) FROM staging.products WHERE category_pt = 'unknown';
```

Result: 610, matching the 610 products without a category found in raw.

### Test 10: categories missing from the translation file

```sql
SELECT DISTINCT p.category_pt
FROM staging.products p
LEFT JOIN raw.category_translation t
       ON t.product_category_name = p.category_pt
WHERE t.product_category_name IS NULL
  AND p.category_pt <> 'unknown';
```

Result: pc_gamer and portateis_cozinha_e_preparadores_de_alimentos.

## Findings during staging

### Finding 1: duplicate review_id values are legitimate

- **Table:** order_reviews
- **Evidence:** raw has 99,224 rows and 99,224 distinct (review_id, order_id) pairs, so the 814 repeated `review_id` values are the same review linked to different orders.
- **Fix applied:** none needed. The primary key is the composite `(review_id, order_id)`, and no rows were removed. This corrects the planned fix in Issue 5 of `data_issues.md`.

### Finding 2: translation file is incomplete, and one test was misleading

- **Table:** products / category_translation
- **Evidence:** Test 10 (first version) returned 9 categories where the Portuguese and English names are identical. Most of them (for example `audio`, `pet_shop`) are listed in the translation file with the same word in both languages, so they are not missing. The corrected query isolates the real gaps.
- **Fix applied:** the staging script already falls back to the Portuguese name when no translation exists, so no category ends up empty.

### Finding 3: 8 delivered orders without delivery date remain in staging

- **Table:** orders
- **Evidence:** Test 7 confirms 2,965 NULL delivery dates, including the 8 `delivered` orders from Issue 2.
- **Fix applied:** none. The rows are kept. Analytics on delivery time must exclude NULL delivery dates.
