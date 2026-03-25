-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 46: Counterparty & Credit Management
-- Description: Counterparty master with LEI integration, credit rating history,
--              and exposure metrics for Basel RWA
-- Compliance: Basel III/IV, EMIR LEI, Large Exposures
-- ================================================================================

-- Counterparty Credit Tables
\i dynamic.counterparty_master.sql
\i dynamic.credit_rating_history.sql
\i dynamic.exposure_metrics_calculation.sql

-- Component Summary
-- Tables: 3
-- - counterparty_master: LEI-based entity master with hierarchy
-- - credit_rating_history: S&P, Moody's, Fitch rating migration tracking
-- - exposure_metrics_calculation: Current, peak, stress exposure for Basel
-- ================================================================================
