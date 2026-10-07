# Olist E-Commerce Data Warehouse (PostgreSQL)

A local data warehouse built in PostgreSQL from the Olist Brazilian e-commerce dataset. The project takes raw CSV files through a cleaning layer into a star schema, then answers business questions with SQL.

**Status:** 🚧 In progress (Day 0 complete: setup and environment)

## Goal

Practice end-to-end data engineering fundamentals:
- Layered architecture (raw → staging → warehouse)
- Dimensional modeling (star schema, SCD Type 2)
- Idempotent, repeatable loads
- Analytical SQL (CTEs, window functions)
- Query performance tuning and data quality checks

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle): about 100k orders from 2016 to 2018 across 9 related tables (orders, items, customers, sellers, products, payments, reviews, geolocation, category translation).

The CSV files are not included in this repo. Download them from Kaggle and place them in `data/`.

## Architecture

| Schema | Purpose |
|--------|---------|
| `raw` | Data exactly as loaded from the CSVs (all text columns) |
| `staging` | Cleaned and typed data, with keys and consistent naming |
| `dwh` | Star schema: fact and dimension tables |

