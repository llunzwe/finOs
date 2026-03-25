-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 49: P&L Attribution & Risk Analytics
-- Table: risk_sensitivities
-- Description: Risk sensitivity calculations - Greeks, DV01, CS01, VaR contributions
--              for portfolios and individual positions
-- Compliance: Market Risk Management, Risk Limits, Regulatory Reporting
-- ================================================================================

CREATE TABLE dynamic.risk_sensitivities (
    -- Primary Identity
    sensitivity_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Calculation Context
    calculation_date DATE NOT NULL,
    calculation_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Entity Reference
    portfolio_id UUID,
    position_id UUID,
    account_id UUID REFERENCES core.account_master(id),
    instrument_id UUID REFERENCES dynamic.securities_master(security_id),
    counterparty_id UUID REFERENCES dynamic.counterparty_master(counterparty_id),
    
    -- Price Sensitivities (Equity/FX/Commodity)
    delta DECIMAL(28,8), -- Price sensitivity
    gamma DECIMAL(28,8), -- Convexity
    vega DECIMAL(28,8), -- Volatility sensitivity
    theta DECIMAL(28,8), -- Time decay (per day)
    
    -- Interest Rate Sensitivities
    dv01 DECIMAL(28,8), -- Dollar value of 01bp
    pv01 DECIMAL(28,8), -- Present value of 01bp
    duration DECIMAL(10,6), -- Modified duration
    convexity DECIMAL(18,8),
    
    -- Credit Sensitivities
    cs01 DECIMAL(28,8), -- Credit spread 01
    jtd DECIMAL(28,8), -- Jump to default
    expected_recovery DECIMAL(5,4),
    
    -- Cross-Asset Sensitivities
    correlation_sensitivity DECIMAL(28,8),
    cross_gamma DECIMAL(28,8),
    vanna DECIMAL(28,8), -- dDelta/dVol
    volga DECIMAL(28,8), -- dVega/dVol
    
    -- VaR Components
    var_contribution DECIMAL(28,8),
    var_percentile DECIMAL(5,2), -- e.g., 99.00
    var_horizon_days INTEGER, -- e.g., 1, 10
    var_methodology VARCHAR(50), -- PARAMETRIC, HISTORICAL, MONTE_CARLO
    
    -- Stress Test Sensitivities
    stress_loss_severe DECIMAL(28,8),
    stress_loss_moderate DECIMAL(28,8),
    stress_scenario_name VARCHAR(100),
    
    -- Currency
    sensitivity_currency CHAR(3) NOT NULL,
    
    -- Model Reference
    pricing_model_id UUID,
    
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
CREATE TABLE dynamic.risk_sensitivities_default PARTITION OF dynamic.risk_sensitivities
    DEFAULT;

-- Monthly partitions
CREATE TABLE dynamic.risk_sensitivities_2025_01 PARTITION OF dynamic.risk_sensitivities
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.risk_sensitivities_2025_02 PARTITION OF dynamic.risk_sensitivities
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Indexes
CREATE INDEX idx_risk_sens_portfolio ON dynamic.risk_sensitivities (tenant_id, portfolio_id, calculation_date);
CREATE INDEX idx_risk_sens_instrument ON dynamic.risk_sensitivities (tenant_id, instrument_id, calculation_date);
CREATE INDEX idx_risk_sens_counterparty ON dynamic.risk_sensitivities (tenant_id, counterparty_id, calculation_date);
CREATE INDEX idx_risk_sens_var ON dynamic.risk_sensitivities (tenant_id, var_contribution) WHERE var_contribution IS NOT NULL;
CREATE INDEX idx_risk_sens_delta ON dynamic.risk_sensitivities (tenant_id, delta) WHERE delta IS NOT NULL;

-- Comments
COMMENT ON TABLE dynamic.risk_sensitivities IS 'Risk sensitivity calculations - Greeks, DV01, CS01, VaR contributions';
COMMENT ON COLUMN dynamic.risk_sensitivities.dv01 IS 'Dollar value of 1 basis point rate change';
COMMENT ON COLUMN dynamic.risk_sensitivities.cs01 IS 'Credit spread sensitivity - P&L for 1bp credit spread move';

-- RLS
ALTER TABLE dynamic.risk_sensitivities ENABLE ROW LEVEL SECURITY;
CREATE POLICY risk_sensitivities_tenant_isolation ON dynamic.risk_sensitivities
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.risk_sensitivities TO finos_app_user;
GRANT SELECT ON dynamic.risk_sensitivities TO finos_readonly_user;
