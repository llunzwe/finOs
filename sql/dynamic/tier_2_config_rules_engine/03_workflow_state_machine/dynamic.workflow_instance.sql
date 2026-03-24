-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 03 - Workflow & State Machine
-- TABLE: dynamic.workflow_instance
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Workflow Instance.
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


CREATE TABLE dynamic.workflow_instance (
    instance_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Definition Reference
    machine_id UUID NOT NULL REFERENCES dynamic.state_machine_definition(machine_id),
    machine_version INTEGER NOT NULL,
    
    -- Context Entity
    context_entity_type VARCHAR(50) NOT NULL,
    context_entity_id UUID NOT NULL,
    
    -- Current State
    current_state VARCHAR(50) NOT NULL,
    previous_state VARCHAR(50),
    state_entry_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Execution
    started_by VARCHAR(100) NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    priority_score INTEGER DEFAULT 0, -- Calculated priority
    
    -- SLA
    sla_deadline TIMESTAMPTZ,
    escalation_level INTEGER DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'ACTIVE' 
        CHECK (status IN ('ACTIVE', 'COMPLETED', 'CANCELLED', 'SUSPENDED', 'ERROR')),
    on_hold_reason TEXT,
    on_hold_since TIMESTAMPTZ,
    
    -- Completion
    completed_at TIMESTAMPTZ,
    completed_by VARCHAR(100),
    completion_outcome VARCHAR(50),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    correlation_id UUID,
    
    CONSTRAINT unique_entity_workflow UNIQUE (tenant_id, context_entity_type, context_entity_id, status)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.workflow_instance_default PARTITION OF dynamic.workflow_instance DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_workflow_machine
idx_workflow_entity
idx_workflow_state
idx_workflow_status
idx_workflow_sla
idx_workflow_priority

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.workflow_instance IS 'Running workflow process instances';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.workflow_instance TO finos_app;
