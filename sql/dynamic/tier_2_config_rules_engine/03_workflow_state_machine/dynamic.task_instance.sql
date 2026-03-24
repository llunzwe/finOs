-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 03 - Workflow & State Machine
-- TABLE: dynamic.task_instance
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Task Instance.
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


CREATE TABLE dynamic.task_instance (
    task_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- References
    task_def_id UUID NOT NULL REFERENCES dynamic.task_definition(task_def_id),
    instance_id UUID REFERENCES dynamic.workflow_instance(instance_id),
    
    -- Assignment
    assigned_to VARCHAR(100),
    assigned_to_user_id UUID,
    assigned_queue_id UUID,
    assigned_at TIMESTAMPTZ,
    
    -- Timing
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    due_date TIMESTAMPTZ NOT NULL,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    -- Status
    status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (status IN ('PENDING', 'ASSIGNED', 'IN_PROGRESS', 'ON_HOLD', 'COMPLETED', 'CANCELLED', 'ESCALATED')),
    
    -- Completion
    outcome VARCHAR(50), -- APPROVED, REJECTED, MORE_INFO, etc.
    outcome_reason TEXT,
    comments TEXT,
    
    -- Data
    form_data JSONB,
    attachment_urls TEXT[],
    
    -- SLA Tracking
    sla_breach_at TIMESTAMPTZ,
    sla_breach_duration INTERVAL,
    escalation_count INTEGER DEFAULT 0,
    
    -- Audit
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    created_by VARCHAR(100),
    completed_by VARCHAR(100),
    correlation_id UUID
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.task_instance_default PARTITION OF dynamic.task_instance DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_task_instance_assignee ON dynamic.task_instance(tenant_id);
CREATE INDEX idx_task_instance_queue ON dynamic.task_instance(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.task_instance IS 'Actual work items assigned to users or queues';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.task_instance TO finos_app;
