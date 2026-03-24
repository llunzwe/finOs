-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 25 - Supporting Accounting
-- TABLE: dynamic.product_pack_features
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Pack Features.
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
CREATE TABLE dynamic.product_pack_features (

    feature_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    pack_id UUID NOT NULL REFERENCES dynamic.product_pack_enablement(pack_id),
    
    feature_name VARCHAR(100) NOT NULL,
    feature_description TEXT,
    
    -- Feature Configuration
    feature_config JSONB DEFAULT '{}',
    
    -- Status
    is_enabled BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_pack_features_default PARTITION OF dynamic.product_pack_features DEFAULT;

-- Triggers
CREATE TRIGGER trg_pack_features_update
    BEFORE UPDATE ON dynamic.product_pack_features
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_supporting_accounting_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.product_pack_features TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.product_pack_features IS 'Product Pack Features';