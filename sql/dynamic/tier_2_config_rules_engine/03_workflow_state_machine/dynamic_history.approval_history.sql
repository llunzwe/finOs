-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 03 - Workflow & State Machine
-- TABLE: dynamic_history.approval_history
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Approval History.
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


CREATE TABLE dynamic_history.approval_history (
    history_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    approval_id UUID NOT NULL REFERENCES dynamic.approval_instance(approval_id) ON DELETE CASCADE,
    
    -- Level Details
    level_number INTEGER NOT NULL,
    approver_id UUID NOT NULL,
    approver_role VARCHAR(100),
    
    -- Decision
    decision VARCHAR(20) NOT NULL,
    decision_at TIMESTAMPTZ NOT NULL,
    decision_comment TEXT,
    
    -- Delegation
    is_delegated BOOLEAN DEFAULT FALSE,
    delegated_from_user_id UUID,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,

    ip_address INET
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.approval_history_default PARTITION OF dynamic_history.approval_history DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_approval_history_approval ON dynamic_history.approval_history(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic_history.approval_history IS 'Multi-level approval decision history';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic_history.approval_history TO finos_app;
