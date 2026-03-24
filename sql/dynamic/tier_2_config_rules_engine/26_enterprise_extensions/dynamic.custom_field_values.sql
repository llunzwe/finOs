-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Enterprise Extensions
-- TABLE: dynamic.custom_field_values
--
-- DESCRIPTION:
--   Enterprise-grade custom field value storage.
--   Stores UDF values for any entity instance.
--
-- ============================================================================


CREATE TABLE dynamic.custom_field_values (
    value_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- References
    field_id UUID NOT NULL REFERENCES dynamic.custom_field_definitions(field_id),
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    
    -- Value Storage (Multi-type)
    value_string VARCHAR(1000),
    value_text TEXT,
    value_integer BIGINT,
    value_decimal DECIMAL(28,8),
    value_boolean BOOLEAN,
    value_date DATE,
    value_datetime TIMESTAMPTZ,
    value_json JSONB,
    value_reference UUID,
    
    -- Validation
    is_valid BOOLEAN DEFAULT TRUE,
    validation_errors TEXT,
    
    -- Change Tracking
    previous_value TEXT,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by VARCHAR(100),
    change_reason TEXT,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_field_entity_value UNIQUE (tenant_id, field_id, entity_type, entity_id)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.custom_field_values_default PARTITION OF dynamic.custom_field_values DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_custom_values_tenant ON dynamic.custom_field_values(tenant_id);
CREATE INDEX idx_custom_values_field ON dynamic.custom_field_values(tenant_id, field_id);
CREATE INDEX idx_custom_values_entity ON dynamic.custom_field_values(tenant_id, entity_type, entity_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.custom_field_values IS 'Custom field values - UDF value storage for entity instances. Tier 2 - Enterprise Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.custom_field_values TO finos_app;
