-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 1: INSTANT LIBRARY (ZERO-CODE)
-- ============================================================================
-- TABLE: dynamic.product_pack_enablement
-- DESCRIPTION: Product Pack Enablement - Industry packs
-- COMPLIANCE: IFRS 9, Basel III, GDPR, POPIA, AAOIFI
-- TIER: 1 - Zero-Code (Ready-to-use, single-click activation)
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
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_pack_per_tenant UNIQUE (tenant_id, pack_name)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_pack_enablement_default PARTITION OF dynamic.product_pack_enablement DEFAULT;

COMMENT ON TABLE dynamic.product_pack_enablement IS 'Product Pack Enablement - Industry packs. Tier 1 - Instant Library.';

GRANT SELECT, INSERT, UPDATE ON dynamic.product_pack_enablement TO finos_app;
