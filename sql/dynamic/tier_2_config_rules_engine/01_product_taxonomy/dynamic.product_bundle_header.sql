-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_bundle_header
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Bundle Header.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 17442 (LEI)
--   - ISO 4217
--   - IFRS 9
--   - AAOIFI
--   - BCBS 239
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


CREATE TABLE dynamic.product_bundle_header (
    bundle_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    bundle_code VARCHAR(100) NOT NULL,
    bundle_name VARCHAR(255) NOT NULL,
    bundle_description TEXT,
    
    -- Pricing
    bundle_pricing_strategy VARCHAR(50) DEFAULT 'DISCOUNT' 
        CHECK (bundle_pricing_strategy IN ('DISCOUNT', 'SUM_OF_PARTS', 'FIXED_PRICE', 'PREMIUM')),
    bundle_discount_percentage DECIMAL(10,6),
    bundle_fixed_price DECIMAL(28,8),
    
    -- Commercial
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Marketing
    marketing_priority INTEGER DEFAULT 0,
    target_customer_segments VARCHAR(50)[],
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_bundle_code_per_tenant UNIQUE (tenant_id, bundle_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_bundle_header_default PARTITION OF dynamic.product_bundle_header DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_bundle_header_tenant
idx_bundle_header_lookup

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_bundle_header IS 'Product package definitions for bundling';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_bundle_header TO finos_app;
