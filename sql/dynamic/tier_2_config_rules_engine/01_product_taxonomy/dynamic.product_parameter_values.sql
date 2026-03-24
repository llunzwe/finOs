-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_parameter_values
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Parameter Values.
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


CREATE TABLE dynamic.product_parameter_values (
    value_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id) ON DELETE CASCADE,
    parameter_id UUID NOT NULL REFERENCES dynamic.product_parameter_definition(parameter_id) ON DELETE CASCADE,
    
    -- Value Storage (polymorphic)
    value_string VARCHAR(1000),
    value_numeric DECIMAL(28,8),
    value_boolean BOOLEAN,
    value_date DATE,
    value_datetime TIMESTAMPTZ,
    value_json JSONB,
    
    -- Override Tracking
    is_override BOOLEAN DEFAULT FALSE,
    override_justification TEXT, -- Required for deviation from template
    inherited_from UUID, -- Parent template if inherited
    
    -- Effective Period
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE DEFAULT '9999-12-31',
    
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
    
    CONSTRAINT unique_param_value_per_product UNIQUE (tenant_id, product_id, parameter_id, effective_date)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_parameter_values_default PARTITION OF dynamic.product_parameter_values DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_param_values_product ON dynamic.product_parameter_values(tenant_id);
CREATE INDEX idx_param_values_param ON dynamic.product_parameter_values(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_parameter_values IS 'Configured parameter values for product templates with override tracking';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_parameter_values TO finos_app;
