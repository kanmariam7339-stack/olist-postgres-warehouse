# SCD2 tests

Checks that the Slowly Changing Dimension Type 2 on `dwh.dim_seller` is correct, and that the pipeline is repeatable. Each query was run in the pgAdmin Query Tool.

## Summary

| #   | Test                                          | Expected                                        | Result                                 | Status           |
| --- | --------------------------------------------- | ----------------------------------------------- | -------------------------------------- | ---------------- |
| 1   | Simulated changes in `staging.seller_changes` | 5 sellers moved to Rio de Janeiro on 2018-01-01 | 5                                      | Pass             |
| 2   | `dim_seller` row count                        | 3,100 (3,095 + 5 new versions)                  | 3,100                                  | Pass             |
| 3   | Sellers whose number of current rows is not 1 | 0 rows                                          | 0 rows                                 | Pass             |
| 4   | Overlapping versions of the same seller       | 0                                               | 0                                      | Pass             |
| 5   | `fact_order_items` row count                  | 112,650                                         | 112,650                                | Pass             |
| 6   | Sum of price equals staging                   | 13,591,643.70                                   | 13,591,643.70                          | Pass             |
| 7   | Demo: old orders keep the old city            | 10 rows (2 per changed seller)                  | 5 rows on first run, 10 after fix      | Pass (after fix) |
| 8   | Pipeline run twice gives identical results    | identical counts                                | identical after 2 runs (44 s and 49 s) | Pass             |

## Queries and results

### Test 1: simulated changes

```sql
SELECT * FROM staging.seller_changes;
```

Result: 5 rows. All 5 sellers get `new_zip_code_prefix = 20000`, `new_city = rio de janeiro`, `new_state = RJ` and `change_date = 2018-01-01`.

| Seller (first characters) | Items before + after change |
| ------------------------- | --------------------------- |
| 6560211...                | 2,033                       |
| 4a3ca9...                 | 1,987                       |
| 1f50f9...                 | 1,931                       |
| cc419e...                 | 1,775                       |
| da8622...                 | 1,551                       |

The order matches the script's `ORDER BY` (busiest sellers first), so the selection is deterministic: every rebuild picks the same 5 sellers.

### Tests 2 and 5: row counts

```sql
SELECT (SELECT count(*) FROM staging.seller_changes) AS changes,
       (SELECT count(*) FROM dwh.dim_seller)         AS dim_seller_rows,
       (SELECT count(*) FROM dwh.fact_order_items)   AS fact_rows;
```

Result: changes 5, dim_seller_rows 3,100, fact_rows 112,650.

### Test 3: exactly one current version per seller

```sql
SELECT seller_id FROM dwh.dim_seller
GROUP BY seller_id HAVING count(*) FILTER (WHERE is_current) <> 1;
```

Result: 0 rows.

### Test 4: no overlapping versions

```sql
SELECT count(*) FROM dwh.dim_seller a
JOIN dwh.dim_seller b
  ON a.seller_id = b.seller_id AND a.seller_key < b.seller_key
 AND a.valid_from < b.valid_to AND b.valid_from < a.valid_to;
```

Result: 0.

### Test 6: totals match staging

```sql
SELECT (SELECT sum(price) FROM staging.order_items)  AS stg_price,
       (SELECT sum(price) FROM dwh.fact_order_items) AS dwh_price;
```

Result: 13,591,643.70 in both layers.

### Test 7: before/after demo

```sql
SELECT s.seller_id, s.city, s.valid_from, s.valid_to, s.is_current,
       count(*) AS items,
       min(d.full_date) AS first_order, max(d.full_date) AS last_order
FROM dwh.fact_order_items f
JOIN dwh.dim_seller s USING (seller_key)
JOIN dwh.dim_date   d ON d.date_key = f.purchase_date_key
WHERE s.seller_id IN (SELECT seller_id FROM staging.seller_changes)
GROUP BY 1, 2, 3, 4, 5
ORDER BY 1, 3;
```

Result (after fix): 10 rows. For each of the 5 sellers, the old version has `valid_to = 2018-01-01` and `last_order = 2017-12-31`, and the Rio de Janeiro version has `valid_from = 2018-01-01` and `first_order = 2018-01-01`.

| Seller (first characters) | Old city          | Old items | Rio items | Total |
| ------------------------- | ----------------- | --------- | --------- | ----- |
| 1f50f9...                 | sao jose do ri... | 1,072     | 859       | 1,931 |
| 4a3ca9...                 | ibitinga          | 1,238     | 749       | 1,987 |
| 6560211...                | sao paulo         | 950       | 1,083     | 2,033 |
| cc419e...                 | santo andre       | 1,258     | 517       | 1,775 |
| da8622...                 | piracicaba        | 644       | 907       | 1,551 |

The totals match the "items before + after change" column of Test 1, so no order was lost or duplicated by the split.

### Test 8: idempotency (full pipeline run twice)

```powershell
powershell -ExecutionPolicy Bypass -File .\run_pipeline.ps1
```

The pipeline was run twice in a row (44 s, then 49 s). After each run, this check query was executed:

```sql
SELECT
  (SELECT count(*) FROM raw.orders)                AS raw_orders,
  (SELECT count(*) FROM staging.geolocation)       AS stg_geo,
  (SELECT count(*) FROM staging.seller_changes)    AS changes,
  (SELECT count(*) FROM dwh.dim_customer)          AS dim_customer,
  (SELECT count(*) FROM dwh.dim_seller)            AS dim_seller,
  (SELECT count(*) FROM dwh.fact_order_items)      AS fact_rows,
  (SELECT sum(price) FROM dwh.fact_order_items)    AS price_sum,
  (SELECT count(*) FROM (
      SELECT seller_id FROM dwh.dim_seller
      GROUP BY seller_id
      HAVING count(*) FILTER (WHERE is_current) <> 1) x) AS sellers_bad_current,
  (SELECT count(*) FROM dwh.dim_seller a
     JOIN dwh.dim_seller b
       ON a.seller_id = b.seller_id AND a.seller_key < b.seller_key
      AND a.valid_from < b.valid_to AND b.valid_from < a.valid_to) AS overlaps;
```

| Column              | Expected      | Run 1         | Run 2         |
| ------------------- | ------------- | ------------- | ------------- |
| raw_orders          | 99,441        | 99,441        | 99,441        |
| stg_geo             | 19,015        | 19,015        | 19,015        |
| changes             | 5             | 5             | 5             |
| dim_customer        | 96,096        | 96,096        | 96,096        |
| dim_seller          | 3,100         | 3,100         | 3,100         |
| fact_rows           | 112,650       | 112,650       | 112,650       |
| price_sum           | 13,591,643.70 | 13,591,643.70 | 13,591,643.70 |
| sellers_bad_current | 0             | 0             | 0             |
| overlaps            | 0             | 0             | 0             |

The Test 7 demo query still returns the same 10 rows after the second run, so the SCD2 history is rebuilt identically and not duplicated.

## Design decisions

- **Half-open intervals:** a version is valid when `valid_from <= date < valid_to`. The old row's `valid_to` equals the new row's `valid_from`, so versions never overlap and every date matches exactly one version.
- **Fact join on purchase date:** the fact table matches the seller version valid on the order's purchase date, not the current one. This is what lets old orders keep the old city.
- **Surrogate keys:** each version has its own `seller_key`, while `seller_id` stays the same across versions (so it is not unique in `dim_seller`).
- **Simulated history:** Olist has no history, so `staging.seller_changes` moves the 5 busiest sellers (with at least 10 items before and after 2018-01-01) to Rio de Janeiro on 2018-01-01. The selection is deterministic, so every rebuild gives the same history.
- **Idempotent SCD2 script:** the close-and-insert script is wrapped in a transaction and does nothing on a second run (nothing left to close, new version already present).
- **One-command pipeline:** `run_pipeline.ps1` runs every `.sql` file under `sql/` in folder and file-name order (`01_raw`, `02_staging`, `03_warehouse`) and stops at the first error (`ON_ERROR_STOP`). Each script drops and recreates its tables, so the pipeline can be rerun at any time and gives the same result. The Postgres password is read at run time (prompt or `PGPASSWORD`) and is never stored in the repo.
- **Full refresh instead of incremental load:** each pipeline run rebuilds every layer from the CSVs (about 45 seconds). It is simple and safe at this size (about 100k orders). On large data an incremental load would be faster. This goes in the README trade-offs.
- **Relative paths in the raw load:** `02_load_raw.sql` uses `data/...` paths, so the pipeline must run from the repo root. The script sets its own working directory, so this is handled automatically.

## Findings

### Finding 1: counts and sums passed while the history was broken

- **Table:** fact_order_items
- **Evidence:** on the first run, Tests 1 to 6 all passed, but the demo (Test 7) returned 5 rows instead of 10. Every seller appeared only with the Rio version, with orders from 2017 attached to it.
- **Cause:** `03_fact_order_items.sql` was renamed but still contained the old join (`AND ds.is_current`), so every order went to the current seller version.
- **Fix applied:** the join now matches on purchase date (`purchase_date >= valid_from AND purchase_date < valid_to`). After rerunning, Test 7 returns 10 rows and the old and new item counts add up to the totals of the buggy run.
- **Lesson:** row counts and sums cannot detect a join that sends rows to the wrong dimension version. A test that checks the business meaning (old orders keep the old city) is needed.

### Finding 2: expected notices during the pipeline run

- **Evidence:** the pipeline prints three kinds of NOTICE messages: schemas already exist, a `DROP cascade` on `order_reviews_order_id_fkey`, and `fact_order_items` does not exist.
- **Explanation:** all are harmless. The schemas are created with `IF NOT EXISTS`. Dropping `staging.orders` removes the foreign key of `order_reviews`, which is re-added by `03_constraints.sql`. The fact table is already dropped by `01_dimensions.sql` before its own script runs.
- **Fix applied:** none needed.
