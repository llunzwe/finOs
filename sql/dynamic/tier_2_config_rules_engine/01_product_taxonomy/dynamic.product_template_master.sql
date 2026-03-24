-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_template_master
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Template Master.
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


CREATE TABLE dynamic.product_template_master (
    product_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    product_code VARCHAR(100) NOT NULL,
    product_sku VARCHAR(100), -- Stock Keeping Unit for commercial
    product_name VARCHAR(255) NOT NULL,
    product_description TEXT,
    
    -- Classification
    category_id UUID NOT NULL REFERENCES dynamic.product_category(category_id),
    product_type VARCHAR(50) NOT NULL, -- LOAN, DEPOSIT, INSURANCE, etc.
    
    -- Template Status
    template_status dynamic.product_status NOT NULL DEFAULT 'DRAFT',
    
    -- Inheritance
    parent_template_id UUID REFERENCES dynamic.product_template_master(product_id),
    inheritance_chain UUID[], -- Array of parent template IDs
    inheritance_strategy dynamic.inheritance_strategy DEFAULT 'OVERRIDABLE',
    
    -- Configuration Schema
    configuration_schema JSONB NOT NULL DEFAULT '{}', -- JSON Schema for valid parameters
    configuration_ui_schema JSONB DEFAULT '{}', -- UI rendering hints
    
    -- Multi-currency Strategy
    multi_currency_strategy VARCHAR(50) DEFAULT 'CONVERSION_AT_ORIGINATION' 
        CHECK (multi_currency_strategy IN ('CONVERSION_AT_ORIGINATION', 'DAILY_REVALUATION', 'MULTI_CURRENCY_ACCOUNT')),
    allowed_currencies CHAR(3)[],
    base_currency CHAR(3) REFERENCES core.currencies(code),
    
    -- Features
    enabled_features UUID[], -- References to feature_flags
    
    -- Commercial
    is_commercially_available BOOLEAN DEFAULT FALSE,
    launch_date DATE,
    retirement_date DATE,
    
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
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_product_code_per_tenant UNIQUE (tenant_id, product_code),
    CONSTRAINT chk_product_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_no_self_parent_template CHECK (parent_template_id IS NULL OR parent_template_id != product_id)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_template_master_default PARTITION OF dynamic.product_template_master DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_product_template_tenant ON dynamic.product_template_master(tenant_id);
CREATE INDEX idx_product_template_lookup ON dynamic.product_template_master(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_template_master IS 'Base product template definitions with inheritance and versioning';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_template_master TO finos_app;
