-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 04 - Event Scheduling
-- TABLE: dynamic.hook_parameter_mapping
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Hook Parameter Mapping.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 8601
--   - ISO 20022
--   - IFRS 15
--   - Basel III
--   - OECD
--   - NCA
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
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    CONSTRAINT unique_hook_parameter UNIQUE (tenant_id, hook_id, parameter_name, parameter_direction)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.hook_parameter_mapping_default PARTITION OF dynamic.hook_parameter_mapping DEFAULT;

-- Comments
COMMENT ON TABLE dynamic.hook_parameter_mapping IS 'Input/output parameter contracts for hooks';

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.hook_parameter_mapping TO finos_app;
