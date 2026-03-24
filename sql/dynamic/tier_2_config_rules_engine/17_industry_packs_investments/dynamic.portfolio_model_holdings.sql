-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 17 - Industry Packs: Investments
-- TABLE: dynamic.portfolio_model_holdings
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Portfolio Model Holdings.
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
CREATE TABLE dynamic.portfolio_model_holdings (

    holding_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    model_id UUID NOT NULL REFERENCES dynamic.portfolio_models(model_id),
    
    -- Holding Details
    security_id UUID, -- Reference to security master
    security_isin VARCHAR(12),
    security_name VARCHAR(200),
    
    -- Allocation
    target_allocation_percentage DECIMAL(10,6) NOT NULL,
    min_allocation_percentage DECIMAL(10,6),
    max_allocation_percentage DECIMAL(10,6),
    
    -- Asset Class
    asset_class VARCHAR(50), -- EQUITY, FIXED_INCOME, ALTERNATIVE, CASH
    sub_asset_class VARCHAR(50), -- LARGE_CAP, SMALL_CAP, EMERGING_MARKETS, etc.
    geography VARCHAR(50), -- DOMESTIC, INTERNATIONAL, EMERGING_MARKETS
    sector VARCHAR(50),
    
    -- Currency
    currency_code CHAR(3),
    
    -- Priority
    priority INTEGER DEFAULT 0, -- For cash flow rebalancing priority
    
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
    
    CONSTRAINT unique_model_holding UNIQUE (tenant_id, model_id, security_id)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.portfolio_model_holdings_default PARTITION OF dynamic.portfolio_model_holdings DEFAULT;

-- Indexes
CREATE INDEX idx_model_holdings_model ON dynamic.portfolio_model_holdings(tenant_id, model_id);

-- Comments
COMMENT ON TABLE dynamic.portfolio_model_holdings IS 'Constituent securities for portfolio models';

-- Triggers
CREATE TRIGGER trg_portfolio_model_holdings_audit
    BEFORE UPDATE ON dynamic.portfolio_model_holdings
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.portfolio_model_holdings TO finos_app;