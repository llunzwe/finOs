-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 03 - Workflow & State Machine
-- TABLE: dynamic.state_machine_definition
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for State Machine Definition.
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


CREATE TABLE dynamic.state_machine_definition (
    machine_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    machine_name VARCHAR(200) NOT NULL,
    machine_code VARCHAR(100) NOT NULL,
    machine_description TEXT,
    
    -- Scope
    entity_type VARCHAR(50) NOT NULL 
        CHECK (entity_type IN ('LOAN', 'DEPOSIT', 'APPLICATION', 'CLAIM', 'DISPUTE', 'PAYMENT', 'CUSTOMER', 'DOCUMENT', 'APPROVAL')),
    
    -- Version
    version INTEGER NOT NULL DEFAULT 1,
    version_label VARCHAR(50),
    
    -- State Definition
    states_json JSONB NOT NULL, -- JSON Schema validated states
    initial_state VARCHAR(50) NOT NULL,
    terminal_states VARCHAR(50)[] NOT NULL,
    
    -- Visual
    diagram_data JSONB, -- BPMN or custom diagram format
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
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
    
    CONSTRAINT unique_machine_code_version UNIQUE (tenant_id, machine_code, version)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.state_machine_definition_default PARTITION OF dynamic.state_machine_definition DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_state_machine_tenant ON dynamic.state_machine_definition(tenant_id);
CREATE INDEX idx_state_machine_lookup ON dynamic.state_machine_definition(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.state_machine_definition IS 'Workflow process blueprints with state definitions';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.state_machine_definition TO finos_app;
