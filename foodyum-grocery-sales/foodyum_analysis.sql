/* ============================================================
   FoodYum Grocery Store Sales — Data Cleaning & Analysis
   ============================================================
   FoodYum is a US-based grocery store chain selling produce,
   meat, dairy, baked goods, snacks, and other household staples.

   Goal: Clean the `products` table and analyze pricing patterns
   across product categories to support inventory decisions.
   ============================================================ */


/* ------------------------------------------------------------
   TASK 1 — Identify missing values
   ------------------------------------------------------------
   In 2022, a system bug caused some products added that year to
   have a missing `year_added` value. Since the year a product was
   added may affect its price, this needs to be quantified before
   any further analysis.

   Output: a single column, `missing_year`, with one row giving
   the count of missing values.
   ------------------------------------------------------------ */

SELECT
    COUNT(*) - COUNT(year_added) AS missing_year
FROM products;

-- Result: 170 missing values out of 1,700 total rows (10%)


/* ------------------------------------------------------------
   TASK 2 — Clean the full dataset
   ------------------------------------------------------------
   Data quality rules applied (per business requirements):

     product_id           -> never missing (PK)
     product_type         -> missing -> 'Unknown'
     brand                -> missing -> 'Unknown'.
                              NOTE: raw data also contained a '-'
                              placeholder (not a true NULL) used to
                              represent missing brand — caught only
                              by inspecting DISTINCT values, since
                              a NULL-count check reports 0 nulls.
                              Handled with NULLIF(brand, '-').
     weight (grams)       -> strip " grams" suffix, cast to numeric,
                              missing -> overall median, round to 2dp
     price (USD)          -> missing -> overall median, round to 2dp
     average_units_sold   -> missing -> 0
     year_added           -> missing -> 2022 (known system bug year)
     stock_location       -> missing -> 'Unknown', standardized to
                              uppercase (A/B/C/D) to fix inconsistent
                              casing found in the raw data (a, b, d...)

   NOTE: This is a read-only SELECT — the original `products`
   table is never modified (UPDATE was intentionally avoided).
   ------------------------------------------------------------ */

SELECT
    product_id,
    COALESCE(product_type, 'Unknown') AS product_type,
    COALESCE(NULLIF(brand, '-'), 'Unknown') AS brand,
    ROUND(
        COALESCE(
            REPLACE(weight, ' grams', '')::numeric,
            (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY REPLACE(weight, ' grams', '')::numeric)
             FROM products WHERE weight IS NOT NULL)
        )::numeric, 2
    ) AS weight,
    ROUND(
        COALESCE(
            price::numeric,
            (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price)
             FROM products WHERE price IS NOT NULL)
        )::numeric, 2
    ) AS price,
    COALESCE(average_units_sold, 0) AS average_units_sold,
    COALESCE(year_added, 2022) AS year_added,
    COALESCE(UPPER(stock_location), 'Unknown') AS stock_location
FROM products;

-- Result: 1,700 clean rows, zero remaining nulls, stock_location
-- fully standardized to uppercase A/B/C/D/Unknown, brand reduced
-- from 8 raw distinct values (7 brands + '-') to 7 brands + 'Unknown'


/* ------------------------------------------------------------
   TASK 3 — Price range by product type
   ------------------------------------------------------------
   The manager wants to know how price varies within each
   category to ensure stock covers a broad range of price points.

   Output: product_type, min_price, max_price
   ------------------------------------------------------------ */

WITH clean_data AS (
    SELECT
        product_id,
        COALESCE(product_type, 'Unknown') AS product_type,
        COALESCE(NULLIF(brand, '-'), 'Unknown') AS brand,
        ROUND(
            COALESCE(
                REPLACE(weight, ' grams', '')::numeric,
                (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY REPLACE(weight, ' grams', '')::numeric)
                 FROM products WHERE weight IS NOT NULL)
            )::numeric, 2
        ) AS weight,
        ROUND(
            COALESCE(
                price::numeric,
                (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price)
                 FROM products WHERE price IS NOT NULL)
            )::numeric, 2
        ) AS price,
        COALESCE(average_units_sold, 0) AS average_units_sold,
        COALESCE(year_added, 2022) AS year_added,
        COALESCE(UPPER(stock_location), 'Unknown') AS stock_location
    FROM products
)
SELECT
    product_type,
    MIN(price) AS min_price,
    MAX(price) AS max_price
FROM clean_data
GROUP BY product_type;

/* Result:
   product_type | min_price | max_price
   ------------- | --------- | ---------
   Dairy         | 8.33      | 13.97
   Meat          | 11.48     | 16.98
   Snacks        | 5.20      | 10.72
   Produce       | 3.46      | 8.78
   Bakery        | 6.26      | 11.88
*/


/* ------------------------------------------------------------
   TASK 4 — High-volume Meat & Dairy products
   ------------------------------------------------------------
   The team wants a closer look at Meat and Dairy products with
   average_units_sold greater than 10 per month.

   Output: product_id, price, average_units_sold
   ------------------------------------------------------------ */

WITH clean_data AS (
    SELECT
        product_id,
        COALESCE(product_type, 'Unknown') AS product_type,
        COALESCE(NULLIF(brand, '-'), 'Unknown') AS brand,
        ROUND(
            COALESCE(
                REPLACE(weight, ' grams', '')::numeric,
                (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY REPLACE(weight, ' grams', '')::numeric)
                 FROM products WHERE weight IS NOT NULL)
            )::numeric, 2
        ) AS weight,
        ROUND(
            COALESCE(
                price::numeric,
                (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price)
                 FROM products WHERE price IS NOT NULL)
            )::numeric, 2
        ) AS price,
        COALESCE(average_units_sold, 0) AS average_units_sold,
        COALESCE(year_added, 2022) AS year_added,
        COALESCE(UPPER(stock_location), 'Unknown') AS stock_location
    FROM products
)
SELECT
    product_id,
    price,
    average_units_sold
FROM clean_data
WHERE product_type IN ('Meat', 'Dairy')
  AND average_units_sold > 10;

-- Result: 698 rows matching the criteria
