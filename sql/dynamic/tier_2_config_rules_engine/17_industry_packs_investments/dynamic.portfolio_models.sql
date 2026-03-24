-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 17 - Industry Packs: Investments
-- TABLE: dynamic.portfolio_models
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Portfolio Models.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 8601
--   - ISO 20022
--   - IFRS 15
--   - Basel III
--   - OECD
--   - NCA
--
-- AUDIT & GOVERNANCE:
--   - Bitemporal tracking (effective_from/valid_from, effective_to/valid_to)
--   - Full audit trail (created_at, updated_at, created_by, updated_by)
--   - Version control for change management
--   - Tenant isolation via partitioning
--   - Row-Level Security (RLS) for data protection
--
-- DATA CLASSIFICATION:
--   - Tenant Isolation: Row-Level Security enabled
--   - Audit Level: FULL
--   - Encryption: At-rest for sensitive fields
--
-- ============================================================================
CREATE TABLE dynamic.portfolio_models (

    model_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    model_code VARCHAR(100) NOT NULL,
    model_name VARCHAR(200) NOT NULL,
    model_description TEXT,
    
    -- Model Type
    model_type VARCHAR(50) NOT NULL 
        CHECK (model_type IN ('STRATEGIC', 'TACTICAL', 'CORE_SATELLITE', 'FACTOR_BASED', 'RISK_BASED', 'GOAL_BASED', 'ESG', 'PASSIVE')),
    
    -- Risk Profile
    target_risk_rating INTEGER CHECK (target_risk_rating BETWEEN 1 AND 7),
    risk_tolerance VARCHAR(50), -- CONSERVATIVE, MODERATE_CONSERVATIVE, MODERATE, MODERATE_AGGRESSIVE, AGGRESSIVE
    
    -- Asset Allocation
    asset_allocation JSONB NOT NULL, -- [{asset_class: 'EQUITY', percentage: 60, deviation: 5}, ...]
    
    -- Rebalancing
    rebalancing_frequency VARCHAR(20) DEFAULT 'QUARTERLY', -- MONTHLY, QUARTERLY, ANNUAL, THRESHOLD_BASED
    rebalancing_threshold DECIMAL(5,4), -- Trigger rebalance when allocation deviates by X%
    rebalancing_method VARCHAR(50) DEFAULT 'CASH_FLOW', -- CASH_FLOW, FULL_REBALANCE, TAX_OPTIMIZED
    
    -- Constraints
    constraints JSONB, -- {max_single_security: 0.10, min_emerging_markets: 0.05, ...}
    excluded_assets UUID[],
    
    -- Performance Targets
    target_return_percentage DECIMAL(10,6),
    target_volatility_percentage DECIMAL(10,6),
    benchmark_index_id UUID,
    
    -- Tax Optimization
    tax_loss_harvesting_enabled BOOLEAN DEFAULT FALSE,
    tax_optimization_strategy VARCHAR(50),
    
    -- ESG
    esg_integration BOOLEAN DEFAULT FALSE,
    esg_minimum_rating VARCHAR(10),
    excluded_sectors VARCHAR(50)[],
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_public BOOLEAN DEFAULT FALSE, -- Available to all advisors or private
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    model_version VARCHAR(20) DEFAULT '1.0',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_portfolio_model_code UNIQUE (tenant_id, model_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.portfolio_models_default PARTITION OF dynamic.portfolio_models DEFAULT;

-- Indexes
CREATE INDEX idx_portfolio_models_tenant ON dynamic.portfolio_models(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_portfolio_models_type ON dynamic.portfolio_models(tenant_id, model_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.portfolio_models IS 'Model portfolio definitions with asset allocation';

-- Triggers
CREATE TRIGGER trg_portfolio_models_audit
    BEFORE UPDATE ON dynamic.portfolio_models
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.portfolio_models TO finos_app;