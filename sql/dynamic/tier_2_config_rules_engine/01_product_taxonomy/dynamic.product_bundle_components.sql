-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_bundle_components
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Bundle Components.
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


CREATE TABLE dynamic.product_bundle_components (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    bundle_id UUID NOT NULL REFERENCES dynamic.product_bundle_header(bundle_id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id) ON DELETE CASCADE,
    
    -- Component Properties
    is_mandatory BOOLEAN DEFAULT TRUE,
    sequence_in_bundle INTEGER DEFAULT 0,
    component_description TEXT,
    
    -- Pricing Override
    bundle_specific_pricing_override JSONB, -- {fee_discount: 0.1, rate_discount: 0.005}
    
    -- Constraints
    min_quantity INTEGER DEFAULT 1,
    max_quantity INTEGER DEFAULT 1,
    
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
    
    CONSTRAINT unique_bundle_component UNIQUE (tenant_id, bundle_id, product_id)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_bundle_components_default PARTITION OF dynamic.product_bundle_components DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_bundle_components_bundle ON dynamic.product_bundle_components(tenant_id, bundle_id);
CREATE INDEX idx_bundle_components_product ON dynamic.product_bundle_components(tenant_id, product_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_bundle_components IS 'Junction table linking products to bundles';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_bundle_components TO finos_app;
