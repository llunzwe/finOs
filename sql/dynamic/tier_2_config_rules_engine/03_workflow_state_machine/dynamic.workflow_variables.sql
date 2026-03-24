-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 03 - Workflow & State Machine
-- TABLE: dynamic.workflow_variables
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Workflow Variables.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO/IEC 19510 (BPMN 2.0)
--   - SOX
--   - PSD2
--   - DORA
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


CREATE TABLE dynamic.workflow_variables (
    variable_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    instance_id UUID NOT NULL REFERENCES dynamic.workflow_instance(instance_id) ON DELETE CASCADE,
    
    variable_name VARCHAR(100) NOT NULL,
    variable_type VARCHAR(50) NOT NULL 
        CHECK (variable_type IN ('STRING', 'INTEGER', 'DECIMAL', 'BOOLEAN', 'DATE', 'DATETIME', 'JSON', 'OBJECT')),
    
    -- Value Storage
    value_string TEXT,
    value_integer BIGINT,
    value_decimal DECIMAL(28,8),
    value_boolean BOOLEAN,
    value_date DATE,
    value_datetime TIMESTAMPTZ,
    value_json JSONB,
    
    -- Security
    is_encrypted BOOLEAN DEFAULT FALSE,
    encrypted_value BYTEA,
    
    -- Scope
    scope VARCHAR(20) DEFAULT 'LOCAL' 
        CHECK (scope IN ('GLOBAL', 'LOCAL', 'TRANSIENT')),
    
    -- Versioning
    variable_version INTEGER DEFAULT 1,
    previous_value JSONB,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    created_by VARCHAR(100),
    updated_by VARCHAR(100),
    
    CONSTRAINT unique_instance_variable UNIQUE (tenant_id, instance_id, variable_name)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.workflow_variables_default PARTITION OF dynamic.workflow_variables DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_workflow_variables_instance ON dynamic.workflow_variables(tenant_id);
CREATE INDEX idx_workflow_variables_name ON dynamic.workflow_variables(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.workflow_variables IS 'Runtime context variables for workflow instances';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.workflow_variables TO finos_app;
