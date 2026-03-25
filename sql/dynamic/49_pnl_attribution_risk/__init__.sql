-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 49: P&L Attribution & Risk Analytics
-- Description: P&L explain decomposition, risk sensitivities (Greeks),
--              and VaR calculations with backtesting
-- Compliance: Market Risk Management, FRTB, Investor Reporting
-- ================================================================================

-- P&L and Risk Tables
\i dynamic.pnl_attribution_analysis.sql
\i dynamic.risk_sensitivities.sql
\i dynamic.var_calculation_engine.sql

-- Component Summary
-- Tables: 3
-- - pnl_attribution_analysis: P&L decomposition (market, carry, credit, trading)
-- - risk_sensitivities: Greeks, DV01, CS01, VaR contributions
-- - var_calculation_engine: Parametric, historical, Monte Carlo VaR with backtesting
-- ================================================================================
