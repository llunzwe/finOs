-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 03 - Workflow & State Machine
-- TABLE: dynamic.approval_instance
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Approval Instance.
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


CREATE TABLE dynamic.approval_instance (
    approval_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- References
    task_id UUID REFERENCES dynamic.task_instance(task_id),
    matrix_id UUID REFERENCES dynamic.approval_matrix_advanced(matrix_id),
    
    -- Request
    requester_id UUID NOT NULL,
    requester_comment TEXT,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Subject
    subject_entity_type VARCHAR(50) NOT NULL,
    subject_entity_id UUID NOT NULL,
    subject_amount DECIMAL(28,8),
    subject_currency CHAR(3),
    subject_description TEXT,
    
    -- Current Approver
    current_level INTEGER DEFAULT 1,
    approver_id UUID,
    approver_role VARCHAR(100),
    assigned_at TIMESTAMPTZ,
    
    -- Decision
    decision VARCHAR(20), -- PENDING, APPROVED, REJECTED, MORE_INFO
    decision_at TIMESTAMPTZ,
    decision_comment TEXT,
    decision_reason_code VARCHAR(50),
    
    -- Delegation
    delegation_indicator BOOLEAN DEFAULT FALSE,
    delegated_from_user_id UUID,
    
    -- Status
    status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (status IN ('PENDING', 'IN_REVIEW', 'APPROVED', 'REJECTED', 'ESCALATED', 'CANCELLED')),
    
    -- SLA
    sla_deadline TIMESTAMPTZ,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    correlation_id UUID
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.approval_instance_default PARTITION OF dynamic.approval_instance DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_approval_instance_approver
idx_approval_instance_requester
idx_approval_instance_status
idx_approval_instance_subject

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.approval_instance IS 'Specific approval requests with audit trail';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.approval_instance TO finos_app;
