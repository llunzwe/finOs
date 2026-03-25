-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 03 - Value Movements
-- TABLE: dynamic.movement_type_workflows
--
-- DESCRIPTION:
--   Movement type workflow configuration.
--   Configures approval workflows, validation rules per movement type.
--
-- CORE DEPENDENCY: 003_value_movement_and_double_entry.sql
--
-- ============================================================================

CREATE TABLE dynamic.movement_type_workflows (
    workflow_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Workflow Identification
    workflow_code VARCHAR(100) NOT NULL,
    workflow_name VARCHAR(200) NOT NULL,
    workflow_description TEXT,
    
    -- Movement Type Mapping
    movement_type VARCHAR(50) NOT NULL, -- Maps to core.value_movements.movement_type
    
    -- Workflow Configuration
    approval_required BOOLEAN DEFAULT FALSE,
    approval_levels INTEGER DEFAULT 1,
    approver_roles VARCHAR(100)[],
    auto_approve_below_amount DECIMAL(28,8),
    
    -- Validation Rules
    validation_rules JSONB, -- [{"field": "amount", "operator": "less_than", "value": 1000000}]
    required_fields VARCHAR(100)[],
    restricted_fields VARCHAR(100)[],
    
    -- Workflow Steps
    workflow_steps JSONB, -- Ordered array of steps with actions
    
    -- SLA
    sla_hours INTEGER DEFAULT 24,
    escalation_hours INTEGER DEFAULT 48,
    auto_reject_after_hours INTEGER,
    
    -- Notifications
    notify_on_submit BOOLEAN DEFAULT TRUE,
    notify_on_approval BOOLEAN DEFAULT TRUE,
    notify_on_rejection BOOLEAN DEFAULT TRUE,
    notification_roles VARCHAR(100)[],
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_movement_workflow UNIQUE (tenant_id, movement_type, workflow_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.movement_type_workflows_default PARTITION OF dynamic.movement_type_workflows DEFAULT;

CREATE INDEX idx_movement_workflow_type ON dynamic.movement_type_workflows(tenant_id, movement_type) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.movement_type_workflows IS 'Movement type workflow configuration for approval and validation rules. Tier 2 Low-Code';

CREATE TRIGGER trg_movement_type_workflows_audit
    BEFORE UPDATE ON dynamic.movement_type_workflows
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.movement_type_workflows TO finos_app;
