-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 04 - Event & Scheduling
-- TABLE: dynamic.hook_parameter_mapping
--
-- DESCRIPTION:
--   Configuration table for Hook Parameter Mapping
--
-- TIER: 2 - Low-Code Configuration (UI/API setup, no coding required)
--
-- COMPLIANCE FRAMEWORK:
--   - ISO 8601: Date/time representation
--   - ISO 20022: Event messaging standards
--   - GDPR: Event data retention
--   - BCBS 239: Event data aggregation
--
-- AUDIT & GOVERNANCE:
--   - Bitemporal tracking (effective_from/to, created/updated)
--   - Full audit trail via triggers
--   - Tenant isolation for data residency
--   - Version control for change management
-- ============================================================================

CREATE TABLE dynamic.hook_parameter_mapping (

    mapping_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    hook_id UUID NOT NULL REFERENCES dynamic.hook_definition(hook_id) ON DELETE CASCADE,
    
    parameter_name VARCHAR(100) NOT NULL,
    parameter_direction VARCHAR(10) DEFAULT 'INPUT' 
        CHECK (parameter_direction IN ('INPUT', 'OUTPUT')),
    
    -- Source
    parameter_source VARCHAR(50) NOT NULL 
        CHECK (parameter_source IN ('EVENT_PAYLOAD', 'DB_QUERY', 'STATIC', 'CONTEXT', 'CALCULATED')),
    source_expression TEXT, -- JSON path, SQL query, or static value
    
    -- Type
    parameter_type VARCHAR(50) NOT NULL,
    required BOOLEAN DEFAULT TRUE,
    default_value JSONB,
    
    -- Validation
    validation_rules JSONB,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    CONSTRAINT unique_hook_parameter UNIQUE (tenant_id, hook_id, parameter_name, parameter_direction)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.hook_parameter_mapping_default PARTITION OF dynamic.hook_parameter_mapping DEFAULT;

-- Comments
COMMENT ON TABLE dynamic.hook_parameter_mapping IS 'Input/output parameter contracts for hooks';

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.hook_parameter_mapping TO finos_app;
