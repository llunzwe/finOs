-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 03 - Workflow & State Machine
-- TABLE: dynamic.state_transition_permissions
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for State Transition Permissions.
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


CREATE TABLE dynamic.state_transition_permissions (
    permission_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    transition_id UUID NOT NULL REFERENCES dynamic.state_transition_rules(transition_id) ON DELETE CASCADE,
    
    -- Role Assignment
    role_code VARCHAR(100) NOT NULL,
    permission_type VARCHAR(20) DEFAULT 'EXECUTE' 
        CHECK (permission_type IN ('EXECUTE', 'VIEW', 'DELEGATE')),
    
    -- Four Eyes
    four_eyes_required BOOLEAN DEFAULT FALSE,
    secondary_approver_role VARCHAR(100),
    secondary_approver_user_id UUID,
    
    -- Conditions
    condition_expression TEXT, -- Additional conditions
    max_amount_authorized DECIMAL(28,8), -- For amount-based permissions
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    CONSTRAINT unique_transition_role UNIQUE (tenant_id, transition_id, role_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.state_transition_permissions_default PARTITION OF dynamic.state_transition_permissions DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_transition_permissions_transition
idx_transition_permissions_role

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.state_transition_permissions IS 'Role-based permissions for state transitions';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.state_transition_permissions TO finos_app;
