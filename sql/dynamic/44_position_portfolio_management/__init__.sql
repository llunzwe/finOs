-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 44: Position & Portfolio Management
-- Description: Bitemporal position tracking with trade/settlement date views
--              and portfolio strategy allocation
-- Compliance: Portfolio Reconciliation, UCITS/AIFMD, CSDR
-- ================================================================================

-- Position Management Tables
\i dynamic.position_history.sql
\i dynamic.portfolio_strategy_allocation.sql
\i dynamic.position_reconciliation_config.sql

-- Component Summary
-- Tables: 3
-- - position_history: Bitemporal positions with trade-date vs settlement-date views
-- - portfolio_strategy_allocation: Strategy targets and rebalancing rules
-- - position_reconciliation_config: Internal vs external matching configuration
-- ================================================================================
