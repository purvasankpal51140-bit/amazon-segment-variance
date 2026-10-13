-- Tie-out: segment sum vs reported consolidated. Any non-zero diff is a data entry error.
DROP VIEW IF EXISTS v_tieout;
CREATE VIEW v_tieout AS
SELECT s.fiscal_quarter,
       SUM(s.net_sales_musd)                                   AS segment_sales,
       c.reported_net_sales_musd                               AS reported_sales,
       SUM(s.net_sales_musd) - c.reported_net_sales_musd       AS sales_diff,
       SUM(s.operating_income_musd)                            AS segment_oi,
       c.reported_operating_income_musd                        AS reported_oi,
       SUM(s.operating_income_musd) - c.reported_operating_income_musd AS oi_diff
FROM segment_results s
JOIN consolidated_check c USING (fiscal_quarter)
GROUP BY s.fiscal_quarter
ORDER BY s.fiscal_quarter;

-- Core analysis: margin, QoQ and YoY growth, share of total operating income.
DROP VIEW IF EXISTS v_segment_analysis;
CREATE VIEW v_segment_analysis AS
WITH base AS (
    SELECT fiscal_quarter, segment, net_sales_musd AS sales, operating_income_musd AS oi,
           SUM(operating_income_musd) OVER (PARTITION BY fiscal_quarter) AS total_oi,
           SUM(net_sales_musd)        OVER (PARTITION BY fiscal_quarter) AS total_sales,
           LAG(net_sales_musd, 1)       OVER w AS sales_prev_q,
           LAG(net_sales_musd, 4)       OVER w AS sales_prev_y,
           LAG(operating_income_musd, 1) OVER w AS oi_prev_q,
           LAG(operating_income_musd, 4) OVER w AS oi_prev_y
    FROM segment_results
    WINDOW w AS (PARTITION BY segment ORDER BY fiscal_quarter)
)
SELECT fiscal_quarter, segment, sales, oi,
       ROUND(100.0 * oi / sales, 1)                                   AS op_margin_pct,
       ROUND(100.0 * (sales - sales_prev_q) / sales_prev_q, 1)         AS sales_qoq_pct,
       ROUND(100.0 * (sales - sales_prev_y) / sales_prev_y, 1)         AS sales_yoy_pct,
       oi - oi_prev_q                                                  AS oi_qoq_change,
       oi - oi_prev_y                                                  AS oi_yoy_change,
       -- % growth on OI is meaningless when the base is negative or tiny, so guard it
       CASE WHEN oi_prev_y > 0 THEN ROUND(100.0 * (oi - oi_prev_y) / oi_prev_y, 1) END AS oi_yoy_pct,
       ROUND(100.0 * sales / total_sales, 1)                           AS share_of_sales_pct,
       ROUND(100.0 * oi / total_oi, 1)                                 AS share_of_oi_pct
FROM base
ORDER BY fiscal_quarter, segment;

-- Margin change in basis points YoY, ranked: this is where the variance commentary starts.
DROP VIEW IF EXISTS v_biggest_swings;
CREATE VIEW v_biggest_swings AS
WITH m AS (
    SELECT fiscal_quarter, segment,
           net_sales_musd AS sales, operating_income_musd AS oi,
           10000.0 * operating_income_musd / net_sales_musd AS margin_bps,
           LAG(10000.0 * operating_income_musd / net_sales_musd, 4)
               OVER (PARTITION BY segment ORDER BY fiscal_quarter) AS margin_bps_prev_y,
           LAG(operating_income_musd, 4)
               OVER (PARTITION BY segment ORDER BY fiscal_quarter) AS oi_prev_y
    FROM segment_results
)
SELECT fiscal_quarter, segment,
       ROUND(margin_bps / 100.0, 1)               AS op_margin_pct,
       ROUND(margin_bps - margin_bps_prev_y)       AS margin_change_bps_yoy,
       oi - oi_prev_y                              AS oi_change_yoy_musd
FROM m
WHERE margin_bps_prev_y IS NOT NULL
ORDER BY ABS(margin_bps - margin_bps_prev_y) DESC;
