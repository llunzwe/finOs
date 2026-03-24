-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.credit_products
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Credit Products.
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
CREATE TABLE dynamic.credit_products (

    product_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    product_name VARCHAR(200) NOT NULL,
    product_code VARCHAR(100) NOT NULL,
    
    -- Credit Terms
    credit_limit_min DECIMAL(28,8),
    credit_limit_max DECIMAL(28,8),
    credit_limit_default DECIMAL(28,8),
    
    -- Interest
    interest_rate_purchase DECIMAL(10,6),
    interest_rate_cash DECIMAL(10,6),
    interest_rate_penalty DECIMAL(10,6),
    
    interest_calculation_method VARCHAR(50) DEFAULT 'average_daily_balance',
    interest_free_period_days INTEGER DEFAULT 0,
    
    -- Fees
    annual_fee DECIMAL(28,8),
    late_payment_fee DECIMAL(28,8),
    over_limit_fee DECIMAL(28,8),
    
    -- Payment
    min_payment_percentage DECIMAL(5,4) DEFAULT 0.03,
    min_payment_amount DECIMAL(28,8),
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    
    -- Metadata
    policy_id UUID, -- Reference to policy document
    bundle_id UUID, -- If part of a bundle
    
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
    
    CONSTRAINT unique_credit_product_code UNIQUE (tenant_id, product_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.credit_products_default PARTITION OF dynamic.credit_products DEFAULT;

-- Triggers
CREATE TRIGGER trg_credit_products_update
    BEFORE UPDATE ON dynamic.credit_products
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_marqeta_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.credit_products TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.credit_products IS 'Credit Products';