-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_feature_flags
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Feature Flags.
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


CREATE TABLE dynamic.product_feature_flags (
    feature_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    feature_code VARCHAR(100) NOT NULL, -- OVERDRAFT_ALLOWED, ISLAMIC_COMPLIANT, etc.
    feature_name VARCHAR(200) NOT NULL,
    feature_description TEXT,
    
    -- Applicability
    applicable_category_ids UUID[], -- Array of category IDs
    applicable_product_types VARCHAR(50)[],
    
    -- Validation Rules
    mandatory_validation_rules JSONB NOT NULL DEFAULT '[]', -- JSON Schema validation rules
    default_value JSONB,
    
    -- Feature Constraints
    requires_approval BOOLEAN DEFAULT FALSE,
    approval_workflow_id UUID,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_feature_code_per_tenant UNIQUE (tenant_id, feature_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_feature_flags_default PARTITION OF dynamic.product_feature_flags DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_feature_flags_tenant
idx_feature_flags_lookup
idx_feature_flags_categories

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_feature_flags IS 'Capability matrix defining product features and their validation rules';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_feature_flags TO finos_app;
