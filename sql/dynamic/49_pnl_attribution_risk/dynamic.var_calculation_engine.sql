-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 49: P&L Attribution & Risk Analytics
-- Table: var_calculation_engine
-- Description: Value at Risk calculation results - parametric, historical,
--              and Monte Carlo VaR with backtesting
-- Compliance: Basel Market Risk, FRTB, Model Risk Management
-- ================================================================================

CREATE TABLE dynamic.var_calculation_engine (
    -- Primary Identity
    var_calculation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Calculation Parameters
    calculation_date DATE NOT NULL,
    calculation_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Scope
    portfolio_id UUID,
    book_id UUID,
    desk VARCHAR(100),
    calculation_scope VARCHAR(50) CHECK (calculation_scope IN ('PORTFOLIO', 'BOOK', 'DESK', 'ENTITY', 'FIRM_WIDE')),
    
    -- VaR Configuration
    var_methodology VARCHAR(50) NOT NULL CHECK (var_methodology IN ('PARAMETRIC', 'HISTORICAL', 'MONTE_CARLO')),
    confidence_level DECIMAL(5,2) NOT NULL DEFAULT 99.00, -- 99% or 95%
    holding_period_days INTEGER NOT NULL DEFAULT 1, -- 1-day, 10-day
    lookback_period_days INTEGER DEFAULT 250, -- Historical lookback
    
    -- VaR Results
    var_amount DECIMAL(28,8) NOT NULL,
    var_currency CHAR(3) NOT NULL,
    cvar_amount DECIMAL(28,8), -- Expected Shortfall/CVaR
    
    -- Component Breakdown
    var_by_asset_class JSONB, -- {"equity": 100000, "fixed_income": 50000, ...}
    var_by_risk_factor JSONB, -- {"rates": 80000, "fx": 40000, ...}
    var_by_geography JSONB,
    
    -- Incremental VaR
    incremental_var JSONB, -- Contribution of each position to total VaR
    
    -- Model Information
    model_version VARCHAR(20),
    model_id UUID,
    correlation_matrix_id UUID,
    volatility_surface_id UUID,
    
    -- Stressed VaR (FRTB)
    stressed_var_amount DECIMAL(28,8),
    stress_period_start DATE,
    stress_period_end DATE,
    
    -- Backtesting
    backtested BOOLEAN DEFAULT FALSE,
    backtest_exceptions INTEGER,
    backtest_coverage_ratio DECIMAL(5,2),
    backtest_p_value DECIMAL(8,6),
    
    -- Model Validation
    validation_status VARCHAR(50) DEFAULT 'PENDING' CHECK (validation_status IN ('PENDING', 'VALIDATED', 'REJECTED', 'CONDITIONAL')),
    validation_notes TEXT,
    validated_by VARCHAR(100),
    validated_at TIMESTAMPTZ,
    
    -- Partitioning
    partition_key DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY RANGE (partition_key);

-- Default partition
CREATE TABLE dynamic.var_calculation_engine_default PARTITION OF dynamic.var_calculation_engine
    DEFAULT;

-- Monthly partitions
CREATE TABLE dynamic.var_calculation_engine_2025_01 PARTITION OF dynamic.var_calculation_engine
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.var_calculation_engine_2025_02 PARTITION OF dynamic.var_calculation_engine
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Indexes
CREATE INDEX idx_var_calc_portfolio ON dynamic.var_calculation_engine (tenant_id, portfolio_id, calculation_date);
CREATE INDEX idx_var_calc_method ON dynamic.var_calculation_engine (tenant_id, var_methodology, calculation_date);
CREATE INDEX idx_var_calc_confidence ON dynamic.var_calculation_engine (tenant_id, confidence_level, holding_period_days);
CREATE INDEX idx_var_calc_backtest ON dynamic.var_calculation_engine (tenant_id, backtested) WHERE backtested = FALSE;
CREATE INDEX idx_var_calc_stress ON dynamic.var_calculation_engine (tenant_id, stressed_var_amount) WHERE stressed_var_amount IS NOT NULL;

-- Comments
COMMENT ON TABLE dynamic.var_calculation_engine IS 'Value at Risk calculation results with component breakdown and backtesting';
COMMENT ON COLUMN dynamic.var_calculation_engine.cvar_amount IS 'Conditional VaR (Expected Shortfall) - average loss beyond VaR threshold';
COMMENT ON COLUMN dynamic.var_calculation_engine.stressed_var_amount IS 'Stressed VaR per FRTB - based on historical stress periods';

-- RLS
ALTER TABLE dynamic.var_calculation_engine ENABLE ROW LEVEL SECURITY;
CREATE POLICY var_calculation_engine_tenant_isolation ON dynamic.var_calculation_engine
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.var_calculation_engine TO finos_app_user;
GRANT SELECT ON dynamic.var_calculation_engine TO finos_readonly_user;
