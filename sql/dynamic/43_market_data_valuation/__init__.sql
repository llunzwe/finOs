-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 43: Market Data & Valuation
-- Description: Market data capture with provenance, valuation methodology,
--              and yield curve construction
-- Compliance: Best Execution, IFRS 13, MiFID II
-- ================================================================================

-- Market Data Tables
\i dynamic.market_data_snapshot.sql
\i dynamic.valuation_methodology_config.sql
\i dynamic.yield_curve_construction.sql

-- Component Summary
-- Tables: 3
-- - market_data_snapshot: Price capture with quality metrics and staleness tracking
-- - valuation_methodology_config: IFRS 13 fair value hierarchy configuration
-- - yield_curve_construction: Curve bootstrapping and interpolation rules
-- ================================================================================
