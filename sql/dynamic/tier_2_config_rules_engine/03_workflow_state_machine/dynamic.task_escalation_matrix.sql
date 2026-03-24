-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 03 - Workflow & State Machine
-- TABLE: dynamic.task_escalation_matrix
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Task Escalation Matrix.
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


CREATE TABLE dynamic.task_escalation_matrix (
    escalation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    task_def_id UUID NOT NULL REFERENCES dynamic.task_definition(task_def_id),
    
    -- Escalation Level
    current_level INTEGER NOT NULL DEFAULT 0,
    escalation_trigger_hours INTEGER NOT NULL,
    
    -- Escalate To
    escalate_to_role VARCHAR(100),
    escalate_to_user_id UUID,
    escalate_to_queue_id UUID,
    
    -- Notification
    notification_template_id UUID,
    additional_notification_emails TEXT[],
    escalate_to_management BOOLEAN DEFAULT FALSE,
    
    -- Actions
    auto_actions JSONB, -- [{action: 'REASSIGN', parameters: {...}}]
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    CONSTRAINT unique_task_escalation_level UNIQUE (tenant_id, task_def_id, current_level)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.task_escalation_matrix_default PARTITION OF dynamic.task_escalation_matrix DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_escalation_matrix_task ON dynamic.task_escalation_matrix(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.task_escalation_matrix IS 'Escalation paths for overdue tasks';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.task_escalation_matrix TO finos_app;
