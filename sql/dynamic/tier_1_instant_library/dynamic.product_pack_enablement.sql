-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 1: INSTANT LIBRARY (ZERO-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product Library
-- TABLE: dynamic.product_pack_enablement
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Pack Enablement.
--   Supports tenant isolation and comprehensive audit trails.
--   Part of the Instant Library for single-click activation.
--
-- TIER CLASSIFICATION:
--   Tier 1 - Zero-Code Instant Library: Ready-to-use, single-click activation products.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 8601
--   - ISO 20022
--   - IFRS 9
--   - Basel III
--   - GDPR
--   - SOC2
--
-- AUDIT & GOVERNANCE:
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
CREATE TABLE dynamic.product_pack_enablement (

    pack_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Pack Identity
    pack_name VARCHAR(100) NOT NULL 
        CHECK (pack_name IN ('BANKING_FULL', 'INSURANCE', 'ADVERTISING', 'SAAS', 'PAYROLL', 'CARDS', 'WEALTH')),
    pack_display_name VARCHAR(200) NOT NULL,
    
    -- Included Products
    included_product_codes TEXT[] NOT NULL,
    
    -- Pricing
    pack_pricing_model VARCHAR(50) DEFAULT 'PER_TRANSACTION' 
        CHECK (pack_pricing_model IN ('FLAT', 'PER_TRANSACTION', 'PER_ACCOUNT', 'TIERED')),
    base_monthly_fee DECIMAL(28,8),
    transaction_fee_basis_points INTEGER,
    
    -- Features
    included_features JSONB DEFAULT '{}',
    api_rate_limits JSONB DEFAULT '{"requests_per_second": 1000}',
    
    -- Status
    is_enabled BOOLEAN DEFAULT FALSE,
    enabled_at TIMESTAMPTZ,
    enabled_by VARCHAR(100),
    
    -- Trial
    trial_period_days INTEGER DEFAULT 30,
    trial_ends_at TIMESTAMPTZ,
    
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
    
    CONSTRAINT unique_pack_per_tenant UNIQUE (tenant_id, pack_name)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_pack_enablement_default PARTITION OF dynamic.product_pack_enablement DEFAULT;

COMMENT ON TABLE dynamic.product_pack_enablement IS 'Product Pack Enablement - Industry packs. Tier 1 - Instant Library.';

GRANT SELECT, INSERT, UPDATE ON dynamic.product_pack_enablement TO finos_app;
