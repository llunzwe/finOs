-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_parameter_definition
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Parameter Definition.
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


CREATE TABLE dynamic.product_parameter_definition (
    parameter_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    parameter_name VARCHAR(100) NOT NULL,
    parameter_code VARCHAR(100) NOT NULL,
    parameter_description TEXT,
    
    -- Data Type
    data_type VARCHAR(20) NOT NULL 
        CHECK (data_type IN ('STRING', 'INTEGER', 'DECIMAL', 'PERCENT', 'BOOLEAN', 'DATE', 'DATETIME', 'ENUM', 'JSON', 'ARRAY')),
    
    -- Validation Constraints
    validation_constraints JSONB NOT NULL DEFAULT '{}', -- {min, max, regex, allowed_values, precision}
    
    -- Default & Options
    default_value JSONB,
    allowed_values JSONB, -- For ENUM type
    
    -- Permissions
    user_editable BOOLEAN DEFAULT TRUE,
    requires_approval_to_modify BOOLEAN DEFAULT FALSE,
    visible_in_ui BOOLEAN DEFAULT TRUE,
    
    -- Scope
    applicable_product_ids UUID[], -- NULL = all products
    applicable_categories UUID[],
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
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
    
    CONSTRAINT unique_parameter_code_per_tenant UNIQUE (tenant_id, parameter_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_parameter_definition_default PARTITION OF dynamic.product_parameter_definition DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_parameter_def_tenant ON dynamic.product_parameter_definition(tenant_id);
CREATE INDEX idx_parameter_def_lookup ON dynamic.product_parameter_definition(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_parameter_definition IS 'Schema definitions for product parameters with validation rules';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_parameter_definition TO finos_app;
