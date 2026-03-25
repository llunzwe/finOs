-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 42: Instrument Reference Data Management
-- Description: Multi-venue instrument identification and corporate actions
--              with benchmark constituent mapping
-- Compliance: MiFID II, SFTR, Best Execution
-- ================================================================================

-- Reference Data Tables
\i dynamic.instrument_identifier_mapping.sql
\i dynamic.instrument_corporate_action.sql
\i dynamic.instrument_benchmark_mapping.sql

-- Component Summary
-- Tables: 3
-- - instrument_identifier_mapping: ISIN, CUSIP, SEDOL, FIGI, RIC mapping with temporal validity
-- - instrument_corporate_action: Dividends, splits, mergers, rights issues lifecycle
-- - instrument_benchmark_mapping: Index constituent tracking for performance attribution
-- ================================================================================
