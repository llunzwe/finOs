-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 45: Settlement Fails Management (CSDR)
-- Description: CSDR settlement fails tracking with penalty calculation,
--              buy-in/sell-out workflows, and CSD reporting
-- Compliance: CSDR (EU) 909/2014, Settlement Discipline Regime
-- ================================================================================

-- Settlement Fails Tables
\i dynamic.settlement_fails_management.sql
\i dynamic.buy_in_sell_out_rules.sql
\i dynamic.csd_penalty_reporting.sql

-- Component Summary
-- Tables: 3
-- - settlement_fails_management: Settlement fail tracking with CSDR penalty calculation
-- - buy_in_sell_out_rules: CSDR Article 7 buy-in execution configuration
-- - csd_penalty_reporting: Penalty reporting to CSDs and regulators
-- ================================================================================
