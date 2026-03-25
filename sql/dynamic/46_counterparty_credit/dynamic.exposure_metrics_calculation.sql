-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 46: Counterparty & Credit Management
-- Table: exposure_metrics_calculation
-- Description: Counterparty exposure metrics - current, peak, stress-test scenarios
--              for credit limit management and Basel RWA calculations
-- Compliance: Basel III/IV (CCR, CVA), Large Exposures, EMIR
-- ================================================================================

CREATE TABLE dynamic.exposure_metrics_calculation (
    -- Primary Identity
    exposure_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Counterparty Reference
    counterparty_id UUID NOT NULL REFERENCES dynamic.counterparty_master(counterparty_id),
    
    -- Calculation Context
    calculation_date DATE NOT NULL,
    calculation_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    calculation_type VARCHAR(50) NOT NULL CHECK (calculation_type IN (
        'EOD', 'INTRADAY', 'STRESS_TEST', 'SCENARIO', 'BACKTEST'
    )),
    scenario_name VARCHAR(100), -- For stress test calculations
    
    -- Netting Set
    netting_set_id UUID, -- Groups trades under netting agreement
    netting_agreement_type VARCHAR(50) CHECK (netting_agreement_type IN ('ISDA_CSA', 'GMRA', 'MSLA', 'UNNETTED')),
    
    -- Current Exposure Metrics
    current_exposure DECIMAL(28,8) NOT NULL DEFAULT 0, -- Current mark-to-market
    potential_future_exposure DECIMAL(28,8), -- PFE at confidence level
    expected_exposure DECIMAL(28,8), -- Average exposure over time
    peak_exposure DECIMAL(28,8), -- Maximum exposure over lookback period
    
    -- Collateral
    collateral_held DECIMAL(28,8) DEFAULT 0,
    collateral_posted DECIMAL(28,8) DEFAULT 0,
    collateral_eligible DECIMAL(28,8), -- Eligible for netting
    net_collateral_exposure DECIMAL(28,8), -- After collateral
    
    -- Credit Risk Metrics
    probability_of_default DECIMAL(8,6), -- 12-month PD
    loss_given_default DECIMAL(5,4),
    exposure_at_default DECIMAL(28,8),
    expected_loss DECIMAL(28,8),
    unexpected_loss DECIMAL(28,8),
    
    -- Basel III/IV Metrics
    sa_ccr_ead DECIMAL(28,8), -- Standardized Approach CCR EAD
    imm_ead DECIMAL(28,8), -- Internal Model Method EAD
    rwa_ccr DECIMAL(28,8), -- Credit Risk RWA
    rwa_cva DECIMAL(28,8), -- CVA Risk RWA
    leverage_exposure DECIMAL(28,8), -- For leverage ratio
    
    -- Wrong Way Risk
    wrong_way_risk_indicator BOOLEAN DEFAULT FALSE,
    wrong_way_risk_correlation DECIMAL(5,4), -- Correlation between exposure and credit quality
    specific_wrong_way_risk BOOLEAN DEFAULT FALSE, -- Specific WWR flag
    
    -- Large Exposures
    tier_1_capital DECIMAL(28,8), -- For large exposure calculation
    exposure_as_pct_of_tier_1 DECIMAL(8,4), -- Large exposure percentage
    large_exposure_limit DECIMAL(28,8),
    large_exposure_breach BOOLEAN DEFAULT FALSE,
    
    -- Limit Utilization
    credit_limit_amount DECIMAL(28,8),
    limit_utilization_pct DECIMAL(8,4),
    limit_headroom DECIMAL(28,8),
    limit_breach BOOLEAN DEFAULT FALSE,
    
    -- Partitioning
    partition_key DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT valid_pd CHECK (probability_of_default >= 0 AND probability_of_default <= 1),
    CONSTRAINT valid_lgd CHECK (loss_given_default >= 0 AND loss_given_default <= 1)
) PARTITION BY RANGE (partition_key);

-- Default partition
CREATE TABLE dynamic.exposure_metrics_calculation_default PARTITION OF dynamic.exposure_metrics_calculation
    DEFAULT;

-- Monthly partitions
CREATE TABLE dynamic.exposure_metrics_calculation_2025_01 PARTITION OF dynamic.exposure_metrics_calculation
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.exposure_metrics_calculation_2025_02 PARTITION OF dynamic.exposure_metrics_calculation
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Indexes
CREATE INDEX idx_exposure_metrics_counterparty ON dynamic.exposure_metrics_calculation (tenant_id, counterparty_id, calculation_date);
CREATE INDEX idx_exposure_metrics_calculation ON dynamic.exposure_metrics_calculation (tenant_id, calculation_type, calculation_date);
CREATE INDEX idx_exposure_metrics_netting ON dynamic.exposure_metrics_calculation (tenant_id, netting_set_id);
CREATE INDEX idx_exposure_metrics_breach ON dynamic.exposure_metrics_calculation (tenant_id, limit_breach) WHERE limit_breach = TRUE;
CREATE INDEX idx_exposure_metrics_wwr ON dynamic.exposure_metrics_calculation (tenant_id, wrong_way_risk_indicator) WHERE wrong_way_risk_indicator = TRUE;
CREATE INDEX idx_exposure_metrics_large ON dynamic.exposure_metrics_calculation (tenant_id, large_exposure_breach) WHERE large_exposure_breach = TRUE;

-- Comments
COMMENT ON TABLE dynamic.exposure_metrics_calculation IS 'Counterparty exposure metrics for credit risk and Basel RWA calculations';
COMMENT ON COLUMN dynamic.exposure_metrics_calculation.wrong_way_risk_indicator IS 'True when exposure correlates negatively with counterparty credit quality';
COMMENT ON COLUMN dynamic.exposure_metrics_calculation.sa_ccr_ead IS 'Standardized Approach for Counterparty Credit Risk Exposure at Default';

-- RLS
ALTER TABLE dynamic.exposure_metrics_calculation ENABLE ROW LEVEL SECURITY;
CREATE POLICY exposure_metrics_calculation_tenant_isolation ON dynamic.exposure_metrics_calculation
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.exposure_metrics_calculation TO finos_app_user;
GRANT SELECT ON dynamic.exposure_metrics_calculation TO finos_readonly_user;
