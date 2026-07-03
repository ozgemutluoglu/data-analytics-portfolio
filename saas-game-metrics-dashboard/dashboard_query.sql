-- ============================================================
-- NAKİT AKIŞI DASHBOARD SQL SORGUSU
-- Tablolar: project.games_paid_users, project.games_payments
-- ============================================================

WITH

monthly_user_revenue AS (
    SELECT
        p.user_id,
        p.game_name,
        u.language,
        u.age,
        DATE_TRUNC('month', p.payment_date)::DATE AS payment_month,
        SUM(p.revenue_amount_usd)                 AS monthly_revenue
    FROM project.games_payments p
    JOIN project.games_paid_users u
        ON p.user_id = u.user_id AND p.game_name = u.game_name
    GROUP BY 1, 2, 3, 4, 5
),

user_monthly_with_prev AS (
    SELECT
        user_id, game_name, language, age,
        payment_month, monthly_revenue,
        LAG(monthly_revenue) OVER (
            PARTITION BY user_id, game_name ORDER BY payment_month
        ) AS prev_revenue,
        LAG(payment_month) OVER (
            PARTITION BY user_id, game_name ORDER BY payment_month
        ) AS prev_month
    FROM monthly_user_revenue
),

user_lifetime AS (
    SELECT
        user_id, game_name,
        MIN(payment_date) AS first_payment,
        MAX(payment_date) AS last_payment,
        MAX(payment_date) - MIN(payment_date) AS lifetime_days
    FROM project.games_payments
    GROUP BY 1, 2
),

monthly_metrics AS (
    SELECT
        cur.payment_month, cur.game_name, cur.language, cur.age,
        SUM(cur.monthly_revenue)                                        AS mrr,
        COUNT(DISTINCT cur.user_id)                                     AS paid_users,
        ROUND(SUM(cur.monthly_revenue) / NULLIF(COUNT(DISTINCT cur.user_id), 0), 2) AS arppu,
        COUNT(DISTINCT CASE WHEN cur.prev_month IS NULL THEN cur.user_id END) AS new_paid_users,
        SUM(CASE WHEN cur.prev_month IS NULL THEN cur.monthly_revenue ELSE 0 END) AS new_mrr,
        SUM(CASE
            WHEN cur.prev_month IS NOT NULL
             AND cur.prev_month = cur.payment_month - INTERVAL '1 month'
             AND cur.monthly_revenue > cur.prev_revenue
            THEN cur.monthly_revenue - cur.prev_revenue ELSE 0
        END) AS expansion_mrr,
        SUM(CASE
            WHEN cur.prev_month IS NOT NULL
             AND cur.prev_month = cur.payment_month - INTERVAL '1 month'
             AND cur.monthly_revenue < cur.prev_revenue
            THEN cur.prev_revenue - cur.monthly_revenue ELSE 0
        END) AS contraction_mrr
    FROM user_monthly_with_prev cur
    GROUP BY 1, 2, 3, 4
),

-- Churn (language/age bazında)
churn_calc AS (
    SELECT
        (prev_users.payment_month + INTERVAL '1 month')::DATE          AS churn_month,
        prev_users.game_name, prev_users.language, prev_users.age,
        COUNT(DISTINCT CASE WHEN cur_month.user_id IS NULL THEN prev_users.user_id END) AS churned_users,
        SUM(CASE WHEN cur_month.user_id IS NULL THEN prev_users.monthly_revenue ELSE 0 END) AS churned_revenue
    FROM monthly_user_revenue prev_users
    LEFT JOIN monthly_user_revenue cur_month
        ON  cur_month.user_id       = prev_users.user_id
        AND cur_month.game_name     = prev_users.game_name
        AND cur_month.payment_month = prev_users.payment_month + INTERVAL '1 month'
    WHERE (prev_users.payment_month + INTERVAL '1 month')::DATE
          IN (SELECT DISTINCT payment_month FROM monthly_user_revenue)
    GROUP BY 1, 2, 3, 4
),

-- Churn Rate: aylık toplam bazında (doğru)
monthly_churn_total AS (
    SELECT
        DATE_TRUNC('month', payment_date)::DATE AS payment_month,
        COUNT(DISTINCT user_id)                 AS paid_users_total
    FROM project.games_payments
    GROUP BY 1
),

monthly_churned_total AS (
    SELECT
        (prev.payment_month + INTERVAL '1 month')::DATE                AS churn_month,
        COUNT(DISTINCT prev.user_id)                                   AS churned_users_total
    FROM (
        SELECT DISTINCT user_id,
               DATE_TRUNC('month', payment_date)::DATE AS payment_month
        FROM project.games_payments
    ) prev
    LEFT JOIN (
        SELECT DISTINCT user_id,
               DATE_TRUNC('month', payment_date)::DATE AS payment_month
        FROM project.games_payments
    ) cur
        ON cur.user_id = prev.user_id
        AND cur.payment_month = prev.payment_month + INTERVAL '1 month'
    WHERE cur.user_id IS NULL
      AND (prev.payment_month + INTERVAL '1 month')::DATE
          IN (SELECT DISTINCT DATE_TRUNC('month', payment_date)::DATE FROM project.games_payments)
    GROUP BY 1
),

-- Revenue Churn Rate: aylık toplam bazında (doğru)
monthly_revenue_churn AS (
    SELECT
        (prev.payment_month + INTERVAL '1 month')::DATE                AS churn_month,
        SUM(prev.monthly_revenue)                                      AS churned_revenue_total
    FROM (
        SELECT user_id,
               DATE_TRUNC('month', payment_date)::DATE AS payment_month,
               SUM(revenue_amount_usd)                 AS monthly_revenue
        FROM project.games_payments
        GROUP BY 1, 2
    ) prev
    LEFT JOIN (
        SELECT DISTINCT user_id,
               DATE_TRUNC('month', payment_date)::DATE AS payment_month
        FROM project.games_payments
    ) cur
        ON cur.user_id = prev.user_id
        AND cur.payment_month = prev.payment_month + INTERVAL '1 month'
    WHERE cur.user_id IS NULL
      AND (prev.payment_month + INTERVAL '1 month')::DATE
          IN (SELECT DISTINCT DATE_TRUNC('month', payment_date)::DATE FROM project.games_payments)
    GROUP BY 1
),

ltv_summary AS (
    SELECT
        DATE_TRUNC('month', p.payment_date)::DATE AS payment_month,
        p.game_name, u.language, u.age,
        AVG(lt.lifetime_days)                     AS avg_lifetime_days,
        AVG(user_total.total_revenue)             AS avg_ltv
    FROM project.games_payments p
    JOIN project.games_paid_users u ON p.user_id = u.user_id AND p.game_name = u.game_name
    JOIN user_lifetime lt ON p.user_id = lt.user_id AND p.game_name = lt.game_name
    JOIN (
        SELECT user_id, game_name, SUM(revenue_amount_usd) AS total_revenue
        FROM project.games_payments GROUP BY 1, 2
    ) user_total ON p.user_id = user_total.user_id AND p.game_name = user_total.game_name
    GROUP BY 1, 2, 3, 4
),

prev_month_mrr AS (
    SELECT
        payment_month + INTERVAL '1 month'        AS next_month,
        SUM(mrr)                                   AS prev_mrr_total
    FROM monthly_metrics
    GROUP BY 1
)

-- ============================================================
-- FINAL SORGU
-- ============================================================
SELECT
    m.payment_month,
    m.game_name,
    m.language,
    m.age,

    ROUND(m.mrr, 2)::FLOAT8                                            AS mrr,
    m.paid_users,
    ROUND(m.arppu, 2)::FLOAT8                                          AS arppu,
    m.new_paid_users,
    ROUND(m.new_mrr, 2)::FLOAT8                                        AS new_mrr,

    COALESCE(c.churned_users, 0)                                       AS churned_users,

    -- Churn Rate: aylık toplam bazında (tüm satırlarda aynı değer)
    ROUND(
        COALESCE(ct.churned_users_total, 0)::NUMERIC
        / NULLIF(prev_total.paid_users_total, 0) * 100, 2
    )::FLOAT8                                                          AS churn_rate_pct,

    ROUND(COALESCE(c.churned_revenue, 0), 2)::FLOAT8                   AS churned_revenue,

    -- Revenue Churn Rate: aylık toplam bazında (tüm satırlarda aynı değer)
    ROUND(
        COALESCE(rc.churned_revenue_total, 0)::NUMERIC
        / NULLIF(pm.prev_mrr_total, 0) * 100, 2
    )::FLOAT8                                                          AS revenue_churn_rate_pct,

    ROUND(m.expansion_mrr, 2)::FLOAT8                                  AS expansion_mrr,
    ROUND(m.contraction_mrr, 2)::FLOAT8                                AS contraction_mrr,

    ROUND(COALESCE(lv.avg_lifetime_days, 0), 1)::FLOAT8                AS avg_customer_lifetime_days,
    ROUND(COALESCE(lv.avg_ltv, 0), 2)::FLOAT8                         AS avg_ltv_usd

FROM monthly_metrics m

LEFT JOIN churn_calc c
    ON  c.churn_month = m.payment_month
    AND c.game_name   = m.game_name
    AND c.language    = m.language
    AND c.age         = m.age

LEFT JOIN monthly_churned_total ct
    ON  ct.churn_month = m.payment_month

LEFT JOIN monthly_churn_total prev_total
    ON  prev_total.payment_month = m.payment_month - INTERVAL '1 month'

LEFT JOIN monthly_revenue_churn rc
    ON  rc.churn_month = m.payment_month

LEFT JOIN prev_month_mrr pm
    ON  pm.next_month = m.payment_month

LEFT JOIN ltv_summary lv
    ON  lv.payment_month = m.payment_month
    AND lv.game_name     = m.game_name
    AND lv.language      = m.language
    AND lv.age           = m.age

order BY m.payment_month, m.game_name, m.language, m.age;
