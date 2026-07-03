# SaaS Game Metrics Dashboard — MRR, Churn & LTV Analysis (2022)

An interactive Tableau Public dashboard analyzing monthly cash flow, revenue dynamics, and user retention across 3 mobile games, built on a PostgreSQL/SQL data pipeline.

🔗 **[View the live dashboard on Tableau Public](https://public.tableau.com/views/NakitAkDashboardOyunAnalizi2022/NakitAkDashboardOyunAnalizi2022?:language=en-US&:display_count=n&:origin=viz_share_link)**

📊 **[PROJE2_20052026_cashflow_TR_slides — View the full presentation](https://docs.google.com/presentation/d/18cCeq84RBpY9CPye5sXnrsdkcETnkp1PD5k8ov36O6I/edit?usp=sharing)**

## Objective

Analyze monthly cash flow per game and visualize the drivers behind revenue and user growth/decline for product managers — surfacing which games are worth further investment, and where retention is at risk.

## Data

Pulled via SQL from `project.games_payments` and `project.games_paid_users`, covering 3 games, 3 languages, and a wide age range, from March–December 2022.

## Methodology

A single chained-CTE SQL query (`dashboard_query.sql`) computes every metric from two raw tables (`project.games_payments`, `project.games_paid_users`):

- **MRR & ARPPU** — aggregated per game/language/age segment, per month
- **New vs. Expansion vs. Contraction MRR** — built with `LAG()` window functions to compare each user's revenue to their own prior month
- **Churn Rate & Revenue Churn Rate** — calculated at the true monthly-cohort level (not per-segment) by anti-joining each month's paying users against the next month's, then dividing by the correct denominator (prior month's users / prior month's total MRR)
- **LTV & average customer lifetime** — derived per user from `MIN`/`MAX` payment dates and total revenue, then averaged per segment

Interactive dashboard built in **Tableau Public**: 8 charts, 10+ metrics, 3 filters.

Tools: **PostgreSQL, DBeaver, Tableau Public**

## Key Findings

- **Strong growth**: MRR grew 6.3x between March and October 2022, driven consistently by New MRR.
- **November break**: Contraction MRR overtook Expansion MRR for the first time — churn pressure eroded revenue.
- **Churn is high**: Churn Rate held in the 20–35% range throughout the year, well above the 5–10% industry benchmark. A July dip (19.82%) stands out as a point worth investigating for a repeatable retention tactic.
- **Game-level gap**: Game 3 outperformed the other two by ~5x on both LTV ($168 vs. $23–31) and customer lifetime (102.8 days vs. 8.3–17 days) — a strong case for reallocating resources toward it.
- **Game 1 is critical**: Users are lost almost immediately (8.3-day average lifetime), pointing to an onboarding problem rather than a product-market fit problem.

## Recommendations Delivered

1. **Reduce churn** — analyze and repeat July's retention success; launch a proactive Q4 retention campaign ahead of the November spike.
2. **Fix Game 1 onboarding** — redesign the first 8 days of the user journey; identify early churn causes via cohort analysis.
3. **Scale Game 3** — increase marketing spend toward its user profile; apply learnings to other games; build a premium tier to capture Expansion MRR.
4. **Manage Contraction MRR** — target upsell messaging at lower-spending users; use exit surveys to understand downgrades.

## Outcome

Year-end MRR grew from $1.5K to $9.4K, confirming strong organic growth — while the analysis flagged churn as the primary risk to sustaining it into 2023.

## Files in this folder

| File | Description |
|---|---|
| `dashboard_query.sql` | Full SQL pipeline (MRR, ARPPU, Churn, Expansion/Contraction, LTV) |
| `cash_flow_dashboard.twb` | Tableau workbook source file |

The stakeholder presentation (findings + recommendations) is available via the Google Slides link above (`PROJE2_20052026_cashflow_TR_slides`).
