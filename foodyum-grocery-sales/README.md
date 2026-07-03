# FoodYum Grocery Store Sales — SQL Data Cleaning & Analysis

A PostgreSQL project focused on **data cleaning** and **exploratory analysis** for a US-based grocery store chain, completed as a practical certification exam. This project demonstrates handling of real-world "messy data" problems: missing values, inconsistent data types, and inconsistent text formatting.

## Business Context

FoodYum sells produce, meat, dairy, baked goods, and snacks across four warehouse locations. As food costs rise, the business wants to ensure it stocks products across a broad range of prices in every category, so it can serve a wide range of customers. This requires trustworthy, clean data as a foundation.

## Dataset

A single table, `products`, with 1,700 records and the following columns:

| Column | Type | Description |
|---|---|---|
| `product_id` | integer | Unique product identifier |
| `product_type` | text | One of: Produce, Meat, Dairy, Bakery, Snacks |
| `brand` | text | One of 7 brand values |
| `weight` | text | Product weight in grams (inconsistently formatted, see below) |
| `price` | real | Price in USD |
| `average_units_sold` | integer | Average monthly units sold |
| `year_added` | integer | Year the product was added to stock |
| `stock_location` | text | Warehouse location (A, B, C, or D) |

## Data Quality Issues Found & Resolved

This dataset had two categories of problems that are common in real business data:

1. **Missing values** across several columns (e.g. 170 missing `year_added` values caused by a known 2022 system bug), each requiring a different, business-defined fill strategy (median, zero, fixed value, or `'Unknown'`).
2. **Inconsistent formatting**, discovered during cleaning rather than specified upfront:
   - `weight` was stored as **text**, with some values suffixed `" grams"` (e.g. `"479.42 grams"`) and others stored as plain numbers (e.g. `"247"`) — requiring string parsing before any numeric calculation (like the median) could be performed.
   - `stock_location` had **inconsistent casing** (e.g. `a`, `B`, `d`) instead of the required uppercase `A`/`B`/`C`/`D`, which was only caught by inspecting the cleaned output — a good reminder that "no missing values" doesn't mean "clean data."

## Approach

All cleaning is done with a **non-destructive `SELECT` query** (no `UPDATE` statements), preserving the original `products` table:

- `COALESCE()` to fill missing values per business-defined rules
- `REPLACE()` to strip inconsistent unit suffixes from `weight` before casting to `numeric`
- `PERCENTILE_CONT(0.5)` to calculate the true median for `weight` and `price` (rather than the mean, which is more sensitive to outliers)
- `UPPER()` to standardize `stock_location` casing
- `ROUND(..., 2)` to enforce consistent decimal precision across monetary and weight fields

## Tasks & Queries

| Task | Description | Output |
|---|---|---|
| 1 | Quantify missing `year_added` values | Single value: 170 missing |
| 2 | Produce a fully cleaned version of the dataset | 1,700 clean rows, zero nulls |
| 3 | Find min/max price per product type | 5 rows (one per category) |
| 4 | Filter Meat & Dairy products with `average_units_sold > 10` | 698 matching rows |

Full SQL is available in [`foodyum_analysis.sql`](./foodyum_analysis.sql).

### Sample result — Task 3: Price range by category

| product_type | min_price | max_price |
|---|---|---|
| Dairy | 8.33 | 13.97 |
| Meat | 11.48 | 16.98 |
| Snacks | 5.20 | 10.72 |
| Produce | 3.46 | 8.78 |
| Bakery | 6.26 | 11.88 |

## Tools

- PostgreSQL
- Window/aggregate functions: `PERCENTILE_CONT`, `COALESCE`, `ROUND`, `REPLACE`, `UPPER`

## Key Takeaways

- Business-defined fill rules for missing data should always be treated as a starting point — cleaned output should still be visually inspected, since problems like inconsistent casing can hide behind a "no nulls" check.
- Casting text-typed numeric columns safely often requires stripping inconsistent formatting first; checking `information_schema.columns` early avoids wasted debugging time.
- Keeping cleaning logic in a reusable CTE (`WITH clean_data AS (...)`) makes downstream analysis queries (Tasks 3 & 4) simpler and ensures consistency across the whole analysis.
