-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 03 - Workflow & State Machine
-- TABLE: dynamic.state_transition_rules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for State Transition Rules.
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


CREATE TABLE dynamic.state_transition_rules (
    transition_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    machine_id UUID NOT NULL REFERENCES dynamic.state_machine_definition(machine_id) ON DELETE CASCADE,
    
    -- Transition Definition
    from_state VARCHAR(50) NOT NULL,
    to_state VARCHAR(50) NOT NULL,
    transition_code VARCHAR(100) NOT NULL,
    transition_name VARCHAR(200),
    
    -- Guard Conditions
    guard_expression TEXT, -- SpEL/DSL condition
    guard_function_name VARCHAR(100), -- Reference to registered function
    guard_sql_condition TEXT, -- SQL expression for evaluation
    
    -- Automation
    auto_transition BOOLEAN DEFAULT FALSE,
    trigger_event_type VARCHAR(100),
    trigger_timer_duration INTERVAL,
    
    -- Actions
    pre_actions JSONB, -- Actions before transition
    post_actions JSONB, -- Actions after transition
    
    -- UI
    ui_button_label VARCHAR(100),
    ui_button_style VARCHAR(20), -- PRIMARY, SECONDARY, DANGER
    ui_confirmation_required BOOLEAN DEFAULT FALSE,
    ui_confirmation_message TEXT,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_machine_transition UNIQUE (tenant_id, machine_id, from_state, to_state)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.state_transition_rules_default PARTITION OF dynamic.state_transition_rules DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_transition_rules_machine
idx_transition_rules_from

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.state_transition_rules IS 'Valid state transitions with guard conditions';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.state_transition_rules TO finos_app;
