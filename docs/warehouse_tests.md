# Warehouse tests

## Summary

| #   | Test                                      | Expected                                       | Result    | Status |
| --- | ----------------------------------------- | ---------------------------------------------- | --------- | ------ |
| 1   | dim_customer row count                    | 96,096 (99,441 minus 3,345 repeated customers) | 96,096    | Pass   |
| 2   | dim_product row count                     | 32,951                                         | 32,951    | Pass   |
| 3   | dim_seller row count                      | 3,095                                          | 3,095     | Pass   |
| 4   | dim_date row count                        | 1,096 days (2016-01-01 to 2018-12-31)          | 1,096     | Pass   |
| 5   | fact_order_items row count equals staging | 112,650                                        | 112,650   | Pass   |
| 6   | Sums of price and freight match staging   | identical                                      | identical | Pass   |
| 7   | No orphan keys in the fact table          | 0                                              | 0         | Pass   |
| 8   | Delivered rows always have delivery_days  | 0 missing                                      | 0         | Pass   |

## Queries and results

### Tests 1 to 5: row counts

```sql
SELECT 'dim_customer' AS tbl, count(*) FROM dwh.dim_customer
UNION ALL SELECT 'dim_product', count(*) FROM dwh.dim_product
UNION ALL SELECT 'dim_seller', count(*) FROM dwh.dim_seller
UNION ALL SELECT 'dim_date', count(*) FROM dwh.dim_date
UNION ALL SELECT 'fact_order_items', count(*) FROM dwh.fact_order_items;
```

Result: dim_date 1,096, dim_seller 3,095, dim_product 32,951, dim_customer 96,096, fact_order_items 112,650.

### Test 6: totals match staging

```sql
SELECT (SELECT sum(price) FROM staging.order_items)          AS stg_price,
       (SELECT sum(price) FROM dwh.fact_order_items)         AS dwh_price,
       (SELECT sum(freight_value) FROM staging.order_items)  AS stg_freight,
       (SELECT sum(freight_value) FROM dwh.fact_order_items) AS dwh_freight;
```

Result: price 13,591,643.70 in both layers, freight 2,251,909.54 in both layers.

### Test 7: orphan keys

```sql
SELECT count(*) FROM dwh.fact_order_items f
LEFT JOIN dwh.dim_customer c USING (customer_key)
LEFT JOIN dwh.dim_product  p USING (product_key)
LEFT JOIN dwh.dim_seller   s USING (seller_key)
LEFT JOIN dwh.dim_date     d ON d.date_key = f.purchase_date_key
WHERE c.customer_key IS NULL OR p.product_key IS NULL
   OR s.seller_key IS NULL OR d.date_key IS NULL;
```

Result: 0. Every fact row finds its customer, product, seller and purchase date.

### Test 8: delivery_days calculated

```sql
SELECT count(*) FROM dwh.fact_order_items
WHERE delivered_date_key IS NOT NULL AND delivery_days IS NULL;
```

Result: 0.

## Design decisions

- **Grain:** one row per order item. Payments and reviews are per order, so joining them here would duplicate amounts. They are handled as separate views in the analytics layer (Day 5).
- **Customer key:** `dim_customer` has one row per `customer_unique_id` (96,096 rows), using the location from the customer's most recent order. This fixes Issue 4 from `data_issues.md`.
- **Role-playing dimension:** `dim_date` is used three times by the fact table (`purchase_date_key`, `delivered_date_key`, `estimated_date_key`). One calendar table plays three roles, so there are no redundant copies of the calendar.
- **Nullable delivery date:** `delivered_date_key` is NULL for orders not yet delivered (including the 8 `delivered` orders without a date, see Issue 2). Analytics on delivery time must exclude these rows.
- **SCD2-ready seller dimension:** `dim_seller` already has `valid_from`, `valid_to` and `is_current`. `seller_id` is not unique on purpose, so Day 4 can add history without restructuring.

## Findings during the warehouse build

None unexpected. All tests passed on the first run.
