-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 39 - Risk Management
-- TABLE: dynamic.risk_weighted_assets_config
--
-- DESCRIPTION:
--   Enterprise-grade Basel III/IV RWA calculation configuration.
--   Credit risk, market risk, operational risk weightings.
--
-- COMPLIANCE: Basel III/IV, CRD IV/CRR, SARB, RBZ
-- ============================================================================


CREATE TABLE dynamic.risk_weighted_assets_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Configuration
    config_name VARCHAR(200) NOT NULL,
    risk_type VARCHAR(50) NOT NULL 
        CHECK (risk_type IN ('CREDIT', 'MARKET', 'OPERATIONAL', 'CVA', 'TOTAL')),
    calculation_approach VARCHAR(50) NOT NULL 
        CHECK (calculation_approach IN ('STANDARDIZED', 'IRB_FOUNDATION', 'IRB_ADVANCED', 'IMA', 'BIA', 'SA')),
    
    -- Basel Version
    basel_version VARCHAR(10) NOT NULL 
        CHECK (basel_version IN ('BASEL_III', 'BASEL_IV', 'BASEL_III_ENDGAME')),
    
    -- Asset Class Risk Weights (Standardized Approach)
    sovereign_risk_weights JSONB DEFAULT '{}', -- By rating: {"AAA": 0.0, "BB+": 1.0}
    bank_risk_weights JSONB DEFAULT '{}',
    corporate_risk_weights JSONB DEFAULT '{}',
    retail_risk_weights JSONB DEFAULT '{"mortgages": 0.35, "other": 0.75}',
    
    -- Credit Risk Mitigation
    collateral_haircuts JSONB DEFAULT '{}',
    guarantee_credit_conversion_factors JSONB DEFAULT '{}',
    
    -- Market Risk
    market_risk_approach VARCHAR(50), -- 'STANDARDIZED' or 'IMA'
    var_confidence_level DECIMAL(5,4) DEFAULT 0.99,
    var_holding_period_days INTEGER DEFAULT 10,
    
    -- Operational Risk
    business_indicator_thresholds JSONB DEFAULT '{"low": 1000000000, "high": 30000000000}',
    internal_loss_multiplier DECIMAL(5,2) DEFAULT 1.0,
    
    -- Output Floors (Basel IV)
    output_floor_percentage DECIMAL(5,4) DEFAULT 0.725, -- 72.5%
    
    -- Reporting
    reporting_frequency VARCHAR(20) DEFAULT 'QUARTERLY',
    reporting_currency CHAR(3) DEFAULT 'ZAR',
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.risk_weighted_assets_config_default PARTITION OF dynamic.risk_weighted_assets_config DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.risk_weighted_assets_config IS 'Basel III/IV RWA calculation configuration - credit, market, operational risk. Tier 2 - Risk Management.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.risk_weighted_assets_config TO finos_app;
