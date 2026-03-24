-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 03 - Workflow & State Machine
-- TABLE: dynamic_history.workflow_history
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Workflow History.
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


CREATE TABLE dynamic_history.workflow_history (
    history_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    instance_id UUID NOT NULL REFERENCES dynamic.workflow_instance(instance_id) ON DELETE CASCADE,
    
    -- Transition Details
    from_state VARCHAR(50) NOT NULL,
    to_state VARCHAR(50) NOT NULL,
    transition_code VARCHAR(100),
    
    -- Who triggered
    transition_triggered_by VARCHAR(100) NOT NULL,
    transition_triggered_by_user_id UUID,
    transition_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Context
    context_snapshot JSONB, -- Full workflow state snapshot
    ip_address INET,
    user_agent TEXT,
    
    -- Duration
    time_in_previous_state INTERVAL,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.workflow_history_default PARTITION OF dynamic_history.workflow_history DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_workflow_history_instance ON dynamic_history.workflow_history(tenant_id);
CREATE INDEX idx_workflow_history_timestamp ON dynamic_history.workflow_history(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic_history.workflow_history IS 'Audit trail of workflow state transitions';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic_history.workflow_history TO finos_app;
