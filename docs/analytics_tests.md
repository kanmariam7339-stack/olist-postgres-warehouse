# Analytics tests

Checks that the `analytics` views and data quality checks are correct and that the pipeline still rebuilds everything. Each query was run in the pgAdmin Query Tool or through `run_pipeline.ps1`.

## Summary

| #   | Test                                                           | Expected                     | Result                      | Status |
| --- | -------------------------------------------------------------- | ---------------------------- | --------------------------- | ------ |
| 1   | Monthly revenue adds up to delivered revenue in the fact table | identical                    | 13,221,498.11 on both sides | Pass   |
| 2   | Category revenue shares add up                                 | about 100                    | 99.96                       | Pass   |
| 3   | Payment shares add up                                          | about 100                    | 99.99                       | Pass   |
| 4   | Customers in repeat-rate view match delivered customers        | identical                    | 93,358 = 93,358             | Pass   |
| 5   | Delivery buckets do not double count orders                    | at most the delivered orders | 95,824 of 96,478            | Pass   |
| 6   | All data quality checks pass                                   | 8 rows, all OK               | 8 OK                        | Pass   |
| 7   | Pipeline rebuilds everything with identical results            | identical counts and checks  | 3 runs, identical           | Pass   |

## Views created (`sql/04_analytics/01_analytics_views.sql`)

| View                         | Purpose                                                             | SQL features                |
| ---------------------------- | ------------------------------------------------------------------- | --------------------------- |
| v_monthly_revenue            | Monthly revenue, growth and running total (delivered orders)        | CTE, LAG, SUM OVER          |
| v_top_sellers_per_state      | Top 3 sellers per state, using the seller state at the time of sale | RANK, PARTITION BY          |
| v_delivery_vs_review         | Average review score by delivery delay bucket                       | CTE, CASE                   |
| v_customer_repeat_rate       | Share of customers with 2 or more delivered orders                  | FILTER                      |
| v_revenue_by_category        | Revenue and share by product category                               | window over aggregate, RANK |
| v_payment_mix                | Orders and value by payment type                                    | window over aggregate       |
| v_delivery_by_customer_state | Average delivery time by customer state                             | RANK over aggregate         |
| v_top_product_per_category   | Best-selling product in each category                               | ROW_NUMBER                  |

Revenue means the sum of item `price` on orders with status `delivered`. Freight is not included.

## Queries and results

### Tests 1 to 5: consistency between views and the fact table

```sql
SELECT
  (SELECT sum(revenue) FROM analytics.v_monthly_revenue)                          AS monthly_rev,
  (SELECT sum(price) FROM dwh.fact_order_items WHERE order_status = 'delivered')  AS fact_delivered_rev,
  (SELECT sum(share_pct) FROM analytics.v_revenue_by_category)                    AS category_share,
  (SELECT sum(share_pct) FROM analytics.v_payment_mix)                            AS payment_share,
  (SELECT customers FROM analytics.v_customer_repeat_rate)                        AS repeat_view_customers,
  (SELECT count(DISTINCT customer_key) FROM dwh.fact_order_items
     WHERE order_status = 'delivered')                                            AS delivered_customers,
  (SELECT sum(orders) FROM analytics.v_delivery_vs_review)                        AS bucketed_orders,
  (SELECT count(DISTINCT order_id) FROM dwh.fact_order_items
     WHERE order_status = 'delivered')                                            AS delivered_orders;
```

| Column                | Result        |
| --------------------- | ------------- |
| monthly_rev           | 13,221,498.11 |
| fact_delivered_rev    | 13,221,498.11 |
| category_share        | 99.96         |
| payment_share         | 99.99         |
| repeat_view_customers | 93,358        |
| delivered_customers   | 93,358        |
| bucketed_orders       | 95,824        |
| delivered_orders      | 96,478        |

The shares are not exactly 100 because each row is rounded to 2 decimals. The delivery buckets cover fewer orders than the delivered total (654 fewer) because an order needs both a delivery date and a review to appear in them.

### Test 6: data quality view

```sql
SELECT * FROM analytics.v_data_quality;
```

| Check                                                   | Failing rows | Expected | Status |
| ------------------------------------------------------- | ------------ | -------- | ------ |
| fact rows equal staging order_items                     | 0            | 0        | OK     |
| fact revenue equals staging revenue                     | 0            | 0        | OK     |
| items with null or non-positive price                   | 0            | 0        | OK     |
| delivered orders with no delivery date (known, Issue 2) | 8            | 8        | OK     |
| orders delivered before they were purchased             | 0            | 0        | OK     |
| review scores outside 1 to 5                            | 0            | 0        | OK     |
| sellers without exactly one current version             | 0            | 0        | OK     |
| overlapping seller versions                             | 0            | 0        | OK     |

The Issue 2 check expects 8, so it flags a change if the number of known anomalies ever differs.

### Test 7: pipeline repeatability

```powershell
powershell -ExecutionPolicy Bypass -File .\run_pipeline.ps1
```

The pipeline was run 3 times in a row (129 s, 65 s, 117 s). Each run printed the same row counts (dim_seller 3,100, fact_order_items 112,650) and the same data quality table (8 rows, all OK). The pipeline now ends with this quality table, so every run validates itself.

## View results

### v_delivery_vs_review

```sql
SELECT * FROM analytics.v_delivery_vs_review ORDER BY 1;
```

| Delivery bucket      | Orders | Average review score |
| -------------------- | ------ | -------------------- |
| 1 - on time or early | 89,443 | 4.29                 |
| 2 - late 1 to 7 days | 3,600  | 2.72                 |
| 3 - late 8+ days     | 2,781  | 1.70                 |

### v_customer_repeat_rate

```sql
SELECT * FROM analytics.v_customer_repeat_rate;
```

| Customers | Repeat customers | Repeat rate |
| --------- | ---------------- | ----------- |
| 93,358    | 2,801            | 3.00%       |

### v_payment_mix

```sql
SELECT * FROM analytics.v_payment_mix ORDER BY total_value DESC;
```

| Payment type | Orders | Total value   | Share  |
| ------------ | ------ | ------------- | ------ |
| credit_card  | 76,505 | 12,542,084.19 | 78.34% |
| boleto       | 19,784 | 2,869,361.27  | 17.92% |
| voucher      | 3,866  | 379,436.87    | 2.37%  |
| debit_card   | 1,528  | 217,989.79    | 1.36%  |
| not_defined  | 3      | 0.00          | 0.00%  |

### v_monthly_revenue

```sql
SELECT * FROM analytics.v_monthly_revenue ORDER BY month_start;
```

23 months, from 2016-09 (134.97) to 2018-08 (838,576.64), with a cumulative revenue of 13,221,498.11. Highlights:

| Month   | Orders | Revenue    | Growth       |
| ------- | ------ | ---------- | ------------ |
| 2016-10 | 265    | 40,325.11  | 29,777.1%    |
| 2017-01 | 750    | 111,798.36 | 1,025,573.0% |
| 2017-11 | 7,289  | 987,765.37 | 52.4%        |
| 2017-12 | 5,513  | 726,033.19 | -26.5%       |
| 2018-05 | 6,749  | 977,544.69 | 0.4%         |
| 2018-08 | 6,351  | 838,576.64 | -3.4%        |

The other four views (`v_top_sellers_per_state`, `v_revenue_by_category`, `v_delivery_by_customer_state`, `v_top_product_per_category`) were created and are rebuilt by the pipeline on every run. Their results are not recorded in this file.

## Key findings

| Finding                                     | Evidence                                                                                                                          |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Late deliveries sharply lower review scores | On time or early: 4.29 (89,443 orders). Late 1 to 7 days: 2.72 (3,600). Late 8+ days: 1.70 (2,781).                               |
| Most customers buy only once                | 2,801 of 93,358 customers (3.00%) have 2 or more delivered orders.                                                                |
| Credit card dominates payments              | credit_card 78.34%, boleto 17.92%, voucher 2.37%, debit_card 1.36%.                                                               |
| Revenue grew through 2017, then plateaued   | Monthly revenue rose from 40,325.11 (Oct 2016) to 987,765.37 (Nov 2017). During 2018 it stayed between 826,437.13 and 977,544.69. |
| Black Friday effect                         | November 2017 shows 987,765.37 (+52.4%), followed by 726,033.19 (-26.5%) in December.                                             |

## Findings during Day 5

### Finding 1: extreme growth percentages at the start of the data

- **View:** v_monthly_revenue
- **Evidence:** December 2016 has 1 order worth 10.90, so January 2017 shows +1,025,573.0% growth.
- **Cause:** tiny starting months, a data coverage effect and not a bug.
- **Fix applied:** none. Growth rates for 2016 should be ignored in reports.

### Finding 2: November 2016 is missing

- **View:** v_monthly_revenue
- **Evidence:** the dataset has no delivered orders in November 2016, so the view jumps from October to December and LAG compares December with October (-100.0%).
- **Fix applied:** none. The view only contains months with delivered orders. A complete calendar join would fix it if needed.

### Finding 3: payment type `not_defined`

- **View:** v_payment_mix
- **Evidence:** 3 orders with payment type `not_defined` and a total value of 0.00.
- **Fix applied:** none. Kept as is, and their share is 0.00%.

### Finding 4: revenue definitions differ between views

- **Evidence:** revenue views sum item `price` for delivered orders (13,221,498.11, no freight). `v_payment_mix` sums `payment_value` for all orders, including freight and non-delivered orders, so its total is higher.
- **Fix applied:** none. The definitions are stated in this file. Do not compare the two totals directly.

### Finding 5: views are dropped and recreated on every rebuild

- **Evidence:** the pipeline output shows `DROP cascade` notices on `analytics.v_*` views when staging and warehouse tables are rebuilt, followed by `CREATE VIEW` in `04_analytics`.
- **Explanation:** PostgreSQL drops a view when a table it depends on is dropped. Because scripts run in folder order, `04_analytics` always recreates the views and indexes after the tables they depend on exist. This is expected behavior.
- **Fix applied:** none needed.
