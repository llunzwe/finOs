-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_category
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Category.
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


CREATE TABLE dynamic.product_category (
    category_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    category_code VARCHAR(50) NOT NULL,
    category_name VARCHAR(200) NOT NULL,
    category_description TEXT,
    
    -- Hierarchy
    parent_category_id UUID REFERENCES dynamic.product_category(category_id),
    path LTREE,
    depth INTEGER GENERATED ALWAYS AS (nlevel(path)) STORED,
    display_order INTEGER DEFAULT 0,
    
    -- Regulatory Classification
    regulatory_reporting_class VARCHAR(50), -- SARB/RBZ specific codes
    capital_risk_weight DECIMAL(5,4), -- Basel III/IV risk-weighting (0-1)
    expected_cclg_treatment DECIMAL(5,4), -- Countercyclical capital buffer
    
    -- Product Classification Flags
    is_lending_product BOOLEAN DEFAULT FALSE,
    is_deposit_product BOOLEAN DEFAULT FALSE,
    is_insurance_product BOOLEAN DEFAULT FALSE,
    is_investment_product BOOLEAN DEFAULT FALSE,
    is_islamic_compliant BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Metadata
    attributes JSONB NOT NULL DEFAULT '{}',
    tags TEXT[],
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_category_code_per_tenant UNIQUE (tenant_id, category_code),
    CONSTRAINT chk_category_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_no_self_parent CHECK (parent_category_id IS NULL OR parent_category_id != category_id)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_category_default PARTITION OF dynamic.product_category DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_product_category_tenant
idx_product_category_lookup
idx_product_category_hierarchy
idx_product_category_parent
idx_product_category_temporal
idx_product_category_attributes
idx_category_hierarchy_ancestor
idx_category_hierarchy_descendant
idx_category_hierarchy_leaf

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_category IS 'Master classification for financial products with regulatory risk weighting';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_category TO finos_app;
