-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 28 - Treasury & Liquidity Management
-- TABLE: dynamic.cash_positioning_config
--
-- DESCRIPTION:
--   Enterprise-grade cash positioning and forecasting configuration.
--   Intraday liquidity, cash concentration, virtual account management.
--
-- COMPLIANCE: Basel III/IV, Cash Management Regulations
-- ============================================================================


CREATE TABLE dynamic.cash_positioning_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Configuration
    config_name VARCHAR(200) NOT NULL,
    positioning_type VARCHAR(50) NOT NULL 
        CHECK (positioning_type IN ('CONCENTRATION', 'NOTIONAL_POOLING', 'PHYSICAL_POOLING', 'VIRTUAL_ACCOUNT')),
    
    -- Entity Scope
    legal_entities UUID[], -- Participating entities
    currencies CHAR(3)[], -- Included currencies
    
    -- Concentration Account
    concentration_account_id UUID REFERENCES dynamic.gl_account_master(account_id),
    
    -- Virtual Account Structure
    virtual_account_enabled BOOLEAN DEFAULT FALSE,
    virtual_account_hierarchy JSONB, -- Virtual account tree structure
    
    -- Forecasting
    forecasting_horizon_days INTEGER DEFAULT 30,
    forecasting_method VARCHAR(50) DEFAULT 'STATISTICAL' 
        CHECK (forecasting_method IN ('STATISTICAL', 'AI_ML', 'RULE_BASED', 'HYBRID')),
    include_pending_transactions BOOLEAN DEFAULT TRUE,
    
    -- Timing
    positioning_frequency VARCHAR(20) DEFAULT 'INTRADAY' 
        CHECK (positioning_frequency IN ('INTRADAY', 'END_OF_DAY', 'REALTIME')),
    cutoff_time TIME DEFAULT '17:00:00',
    
    -- Investment Sweep
    auto_investment_enabled BOOLEAN DEFAULT FALSE,
    investment_vehicle VARCHAR(50), -- 'MMF', 'REPO', 'COMMERCIAL_PAPER'
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.cash_positioning_config_default PARTITION OF dynamic.cash_positioning_config DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.cash_positioning_config IS 'Cash positioning and forecasting - intraday liquidity, virtual accounts, cash concentration. Tier 2 - Treasury & Liquidity Management.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.cash_positioning_config TO finos_app;
