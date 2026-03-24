-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 11 - Integration Api Management
-- TABLE: dynamic.api_transformation_mapping
-- COMPLIANCE: ISO 20022
--   - ISO 27001
--   - OpenAPI
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.api_transformation_mapping (

    mapping_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    endpoint_id UUID NOT NULL REFERENCES dynamic.api_endpoint_registry(endpoint_id),
    
    -- Direction
    direction VARCHAR(10) NOT NULL CHECK (direction IN ('REQUEST', 'RESPONSE')),
    
    -- Formats
    source_format VARCHAR(20) NOT NULL, -- JSON, XML, FORM, etc.
    target_format VARCHAR(20) NOT NULL,
    
    -- Transformation
    transformation_script TEXT, -- XSLT, JSONata, or custom
    transformation_language VARCHAR(20) DEFAULT 'JSONATA', -- XSLT, JSONATA, JOLT
    
    -- Field Mappings
    field_mappings JSONB, -- {source_field: 'target_field', ...}
    
    -- Validation
    validation_schema JSONB,
    validation_required BOOLEAN DEFAULT TRUE,
    
    -- Conditions
    condition_expression TEXT, -- When to apply this transformation
    
    -- Priority
    execution_order INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.api_transformation_mapping_default PARTITION OF dynamic.api_transformation_mapping DEFAULT;

-- Indexes
CREATE INDEX idx_transformation_endpoint ON dynamic.api_transformation_mapping(tenant_id, endpoint_id);

-- Comments
COMMENT ON TABLE dynamic.api_transformation_mapping IS 'Request/response transformation rules';

GRANT SELECT, INSERT, UPDATE ON dynamic.api_transformation_mapping TO finos_app;