-- One row per segment per quarter. Figures in USD millions, as printed in the filing.
DROP TABLE IF EXISTS segment_results;
CREATE TABLE segment_results (
    fiscal_quarter        TEXT    NOT NULL,   -- e.g. 2026Q2
    period_end            DATE    NOT NULL,
    segment               TEXT    NOT NULL CHECK (segment IN ('North America','International','AWS')),
    net_sales_musd        INTEGER NOT NULL,
    operating_income_musd INTEGER NOT NULL,
    source_filing         TEXT    NOT NULL,
    verified              TEXT    NOT NULL DEFAULT 'N',  -- flip to Y after checking the filing page
    PRIMARY KEY (fiscal_quarter, segment)
);

-- Company-level totals from the same filings, used to prove the segment rows tie out.
DROP TABLE IF EXISTS consolidated_check;
CREATE TABLE consolidated_check (
    fiscal_quarter                 TEXT PRIMARY KEY,
    reported_net_sales_musd        INTEGER NOT NULL,
    reported_operating_income_musd INTEGER NOT NULL
);
