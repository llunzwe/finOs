-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Enterprise Extensions
-- TABLE: dynamic.product_instance_parameters
--
-- DESCRIPTION:
--   Enterprise-grade runtime parameter values for product instances.
--   Stores instance-specific overrides of product template parameters.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- ============================================================================


CREATE TABLE dynamic.product_instance_parameters (
    parameter_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- References
    instance_id UUID NOT NULL REFERENCES dynamic.product_instances(instance_id) ON DELETE CASCADE,
    parameter_definition_id UUID REFERENCES dynamic.product_parameter_definition(parameter_id),
    
    -- Parameter Details
    parameter_name VARCHAR(100) NOT NULL,
    parameter_code VARCHAR(100) NOT NULL,
    parameter_description TEXT,
    
    -- Value Storage (Multi-type support)
    value_string VARCHAR(500),
    value_number DECIMAL(28,8),
    value_boolean BOOLEAN,
    value_date DATE,
    value_json JSONB,
    value_type VARCHAR(20) NOT NULL 
        CHECK (value_type IN ('STRING', 'NUMBER', 'BOOLEAN', 'DATE', 'JSON', 'REFERENCE')),
    
    -- Default vs Override
    is_override BOOLEAN DEFAULT TRUE,
    template_default_value TEXT, -- Original template value for reference
    
    -- Validation
    is_valid BOOLEAN DEFAULT TRUE,
    validation_message TEXT,
    
    -- Change Tracking
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by VARCHAR(100),
    change_reason TEXT,
    
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
    
    CONSTRAINT unique_param_instance_code UNIQUE (tenant_id, instance_id, parameter_code, valid_from)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_instance_parameters_default PARTITION OF dynamic.product_instance_parameters DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_instance_params_tenant ON dynamic.product_instance_parameters(tenant_id);
CREATE INDEX idx_instance_params_instance ON dynamic.product_instance_parameters(tenant_id, instance_id);
CREATE INDEX idx_instance_params_def ON dynamic.product_instance_parameters(tenant_id, parameter_definition_id);
CREATE INDEX idx_instance_params_temporal ON dynamic.product_instance_parameters(tenant_id, valid_from, valid_to) WHERE is_current = TRUE;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_instance_parameters IS 'Product instance parameter values - runtime overrides of template parameters. Tier 2 - Enterprise Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_instance_parameters TO finos_app;
