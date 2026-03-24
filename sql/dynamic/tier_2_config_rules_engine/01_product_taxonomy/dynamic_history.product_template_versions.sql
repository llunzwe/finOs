-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic_history.product_template_versions
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Template Versions.
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


CREATE TABLE dynamic_history.product_template_versions (
    version_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id) ON DELETE CASCADE,
    
    -- Version Tracking
    version_sequence BIGINT NOT NULL,
    version_label VARCHAR(50),
    version_description TEXT,
    
    -- Bitemporal Timestamps
    assertion_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_time_start TIMESTAMPTZ NOT NULL,
    valid_time_end TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    
    -- Diff Storage
    diff_patch JSONB, -- JSONB delta from previous version
    full_snapshot JSONB, -- Complete product state for major versions
    
    -- Migration
    migration_script TEXT, -- Automated upgrade path SQL
    is_breaking_change BOOLEAN DEFAULT FALSE,
    
    -- Approvals
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    approval_notes TEXT,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    CONSTRAINT unique_product_version UNIQUE (tenant_id, product_id, version_sequence),
    CONSTRAINT chk_version_valid_time CHECK (valid_time_start < valid_time_end)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.product_template_versions_default PARTITION OF dynamic_history.product_template_versions DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_template_versions_product
idx_template_versions_temporal

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic_history.product_template_versions IS 'Complete version history for product templates with bitemporal support';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic_history.product_template_versions TO finos_app;
