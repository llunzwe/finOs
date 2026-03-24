-- ============================================================================
-- FINOS DAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 40 - Wealth & Digital Assets
-- TABLE: dynamic.robo_advisor_config
--
-- DESCRIPTION:
--   Enterprise-grade robo-advisor and goal-based investing configuration.
--   Automated portfolio construction, rebalancing, tax-loss harvesting.
--
-- COMPLIANCE: MiFID II, SEC, FCA, Financial Advice Regulations
-- ============================================================================


CREATE TABLE dynamic.robo_advisor_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Configuration
    advisor_name VARCHAR(200) NOT NULL,
    advisor_type VARCHAR(50) NOT NULL 
        CHECK (advisor_type IN ('GOAL_BASED', 'RISK_BASED', 'INCOME', 'TAX_OPTIMIZED', 'ESG')),
    
    -- Investment Goals
    supported_goal_types VARCHAR(50)[] DEFAULT ARRAY['RETIREMENT', 'HOME_PURCHASE', 'EDUCATION', 'EMERGENCY_FUND', 'WEALTH_BUILDING'],
    
    -- Risk Profiling
    risk_assessment_questionnaire JSONB NOT NULL, -- Question and scoring logic
    risk_categories VARCHAR(20)[] DEFAULT ARRAY['CONSERVATIVE', 'MODERATE', 'BALANCED', 'GROWTH', 'AGGRESSIVE'],
    
    -- Portfolio Construction
    strategic_asset_allocation JSONB NOT NULL, -- {"equities": 0.60, "bonds": 0.30, "alternatives": 0.10}
    investment_universe VARCHAR(50)[] DEFAULT ARRAY['ETF', 'MUTUAL_FUND', 'STOCKS', 'BONDS'],
    
    -- Rebalancing
    rebalancing_frequency VARCHAR(20) DEFAULT 'QUARTERLY' 
        CHECK (rebalancing_frequency IN ('MONTHLY', 'QUARTERLY', 'SEMI_ANNUAL', 'ANNUAL', 'THRESHOLD')),
    rebalancing_threshold DECIMAL(5,4) DEFAULT 0.05, -- 5% drift triggers rebalance
    tax_aware_rebalancing BOOLEAN DEFAULT TRUE,
    
    -- Tax Optimization
    tax_loss_harvesting_enabled BOOLEAN DEFAULT FALSE,
    tax_loss_harvesting_threshold DECIMAL(28,8) DEFAULT 1000.00,
    
    -- Fees
    management_fee_rate DECIMAL(10,6) DEFAULT 0.0025, -- 0.25% annually
    minimum_investment_amount DECIMAL(28,8) DEFAULT 100.00,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.robo_advisor_config_default PARTITION OF dynamic.robo_advisor_config DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.robo_advisor_config IS 'Robo-advisor configuration - goal-based investing, automated portfolio management. Tier 2 - Wealth & Digital Assets.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.robo_advisor_config TO finos_app;
