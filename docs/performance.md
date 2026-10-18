# Performance

Two queries were measured with `EXPLAIN (ANALYZE, BUFFERS)`, before and after adding indexes. The tables are small (112,650 fact rows, 99,224 reviews), so absolute times are in milliseconds. The number of pages read is the most reliable comparison, because execution times vary from run to run.

## Summary

| Query                            | Plan before                  | Time before | Plan after                           | Time after | Pages read before to after |
| -------------------------------- | ---------------------------- | ----------- | ------------------------------------ | ---------- | -------------------------- |
| A: monthly revenue of one seller | Seq Scan on fact_order_items | 9.248 ms    | Index Scan using ix_fact_seller_key  | 1.864 ms   | 1,743 to 38                |
| B: reviews of one order          | Seq Scan on order_reviews    | 10.749 ms   | Index Scan using ix_reviews_order_id | 0.064 ms   | 1,856 to 4                 |

## Method

- Before: no index on the filtered columns. One captured run per query is shown below; other runs ranged from about 7 to 12 ms.
- After: indexes created from `sql/04_analytics/03_indexes.sql`, then `ANALYZE`. Each query was run 3 times and the lowest time is reported.

## Query A: one seller's monthly revenue

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT d.year, d.month, sum(f.price) AS revenue
FROM dwh.fact_order_items f
JOIN dwh.dim_date d ON d.date_key = f.purchase_date_key
WHERE f.seller_key = 1825
GROUP BY d.year, d.month;
```

- **Before:** `Seq Scan on fact_order_items` with the filter `seller_key = 1825`. It removed 111,151 rows to keep 1,499, and read 1,743 pages. Execution time: 9.248 ms.
- **After:** `Index Scan using ix_fact_seller_key` returns the 1,499 rows directly. Runs: 1.864 ms, 1.989 ms, 2.061 ms. Pages read: 38.
- **Why:** PostgreSQL does not index foreign keys automatically (only primary keys), so `seller_key` had no index.
- `dim_date` stays a Seq Scan in both plans (1,096 rows, 11 pages): reading it whole is cheaper than using an index.

## Query B: reviews of one order

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT review_id, review_score
FROM staging.order_reviews
WHERE order_id = '339889810ba75dd015439b4ec6c33a5b';
```

- **Before:** `Seq Scan on order_reviews`. It removed 99,223 rows to keep 1 and read 1,856 pages. Execution time: 10.749 ms.
- **After:** `Index Scan using ix_reviews_order_id`. Runs: 0.494 ms, 0.130 ms, 0.064 ms. Pages read: 4.
- **Why:** the primary key is `(review_id, order_id)`. A composite index is only usable when the query filters on its **first** column, so a lookup by `order_id` alone could not use it.
- The first "after" run was slower because 3 pages came from disk (`read=3`). Later runs found them in memory (`hit=4`).

## Indexes created (`sql/04_analytics/03_indexes.sql`)

| Index                     | Table                 | Column            | Purpose                       |
| ------------------------- | --------------------- | ----------------- | ----------------------------- |
| ix_fact_seller_key        | dwh.fact_order_items  | seller_key        | seller filters and joins      |
| ix_fact_customer_key      | dwh.fact_order_items  | customer_key      | customer filters and joins    |
| ix_fact_product_key       | dwh.fact_order_items  | product_key       | product and category analysis |
| ix_fact_purchase_date_key | dwh.fact_order_items  | purchase_date_key | date range filters            |
| ix_reviews_order_id       | staging.order_reviews | order_id          | lookups by order              |

## Trade-offs

- **The absolute gain is small** because the tables are small. What matters is that the plan changed from reading the whole table to reading a few pages. The gap grows with table size: the same change on millions of rows is the difference between seconds and milliseconds.
- **Indexes cost disk space and slow down loads**, because every insert must also update them. That is why only foreign keys and lookup columns are indexed, not every column.
- **Rebuilding the warehouse drops the tables and their indexes.** The indexes are created by a script in the pipeline, so every rebuild recreates them.
- **Not everything needs an index:** the small `dim_date` table is cheaper to scan than to index.
