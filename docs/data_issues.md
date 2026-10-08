# Data issues log

Issues found while exploring the `raw` layer (Day 1). Each one has a planned fix in the `staging` layer (Day 2).

## Load validation

All 9 tables were loaded and the row counts match the source CSVs.

| Table                | Rows      |
| -------------------- | --------- |
| customers            | 99,441    |
| geolocation          | 1,000,163 |
| order_items          | 112,650   |
| order_payments       | 103,886   |
| order_reviews        | 99,224    |
| orders               | 99,441    |
| products             | 32,951    |
| sellers              | 3,095     |
| category_translation | 71        |

## Issues

| #   | Table         | Issue                                                  | Evidence                                                           | Planned fix (staging)                                                 |
| --- | ------------- | ------------------------------------------------------ | ------------------------------------------------------------------ | --------------------------------------------------------------------- |
| 1   | all           | Every column is stored as text in raw (by design)      | Date columns return text values                                    | Cast to proper types (timestamp, numeric, integer)                    |
| 2   | orders        | 8 orders with status `delivered` have no delivery date | 2,965 orders have no delivery date, of which 8 are `delivered`     | Keep the rows and flag them as a data anomaly                         |
| 3   | orders        | Only 96,478 of 99,441 orders are `delivered`           | Status distribution query                                          | Filter on status in analytics (for example revenue only on delivered) |
| 4   | customers     | `customer_id` is generated per order, not per person   | 0 duplicate `customer_id`, but 3,345 repeated `customer_unique_id` | Use `customer_unique_id` as the real customer key                     |
| 5   | order_reviews | `review_id` is not unique                              | 814 duplicate `review_id` values                                   | Deduplicate, keeping the latest answer timestamp                      |
| 6   | geolocation   | Many rows per zip code                                 | 1,000,163 rows for 19,015 distinct zip codes (about 52 per zip)    | One row per zip code, using the average latitude and longitude        |
| 7   | products      | Products without a category                            | 610 rows with a NULL or empty category                             | Replace with `unknown`                                                |
| 8   | products      | Typos in column names                                  | `product_name_lenght`, `product_description_lenght`                | Rename to `length`                                                    |

## Data profile

- Order purchase dates range from 2016-09-04 to 2018-10-17.
- Order status distribution: delivered 96,478, shipped 1,107, canceled 625, unavailable 609, invoiced 314, processing 301, created 5, approved 2.
- Geolocation is the largest table (about 61 MB as CSV) and is only needed to enrich customers and sellers with coordinates.

## Missing values

Missing values are stored as `NULL`, not as empty strings (checked on `orders.order_delivered_customer_date`: 2,965 NULLs, 0 empty strings). This is because `\copy` in CSV mode converts unquoted empty fields to `NULL`. Staging casts will still use `NULLIF(column, '')` as a defensive measure.
