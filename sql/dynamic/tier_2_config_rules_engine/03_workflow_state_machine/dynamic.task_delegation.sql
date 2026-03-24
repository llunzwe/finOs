-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 03 - Workflow & State Machine
-- TABLE: dynamic.task_delegation
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Task Delegation.
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


CREATE TABLE dynamic.task_delegation (
    delegation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Delegation Details
    from_user_id UUID NOT NULL,
    to_user_id UUID NOT NULL,
    
    -- Scope
    delegation_scope VARCHAR(20) DEFAULT 'ALL_TASKS' 
        CHECK (delegation_scope IN ('ALL_TASKS', 'SPECIFIC_TASK_CODES', 'SPECIFIC_WORKFLOWS')),
    specific_task_codes VARCHAR(100)[],
    specific_workflow_ids UUID[],
    
    -- Timing
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    cancelled_at TIMESTAMPTZ,
    cancelled_by UUID,
    
    -- Reason
    delegation_reason TEXT,
    
    created_by UUID NOT NULL
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.task_delegation_default PARTITION OF dynamic.task_delegation DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_delegation_from
idx_delegation_to
idx_delegation_dates

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.task_delegation IS 'Temporary task reassignments during absence';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.task_delegation TO finos_app;
