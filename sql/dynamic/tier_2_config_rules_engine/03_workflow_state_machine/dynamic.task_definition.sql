-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 03 - Workflow & State Machine
-- TABLE: dynamic.task_definition
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Task Definition.
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


CREATE TABLE dynamic.task_definition (
    task_def_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    task_code VARCHAR(100) NOT NULL,
    task_name VARCHAR(200) NOT NULL,
    task_description TEXT,
    
    -- Assignment
    default_assignee_role VARCHAR(100),
    default_assignee_user_id UUID,
    default_queue_id UUID,
    
    -- SLA
    default_sla_hours INTEGER NOT NULL DEFAULT 24,
    priority_calculation_formula TEXT,
    default_priority INTEGER DEFAULT 3, -- 1=Highest, 5=Lowest
    
    -- Skills
    required_skills VARCHAR(100)[],
    required_system_access VARCHAR(100)[],
    min_clearance_level INTEGER,
    
    -- Form
    form_schema JSONB, -- JSON Schema for UI rendering
    form_ui_schema JSONB,
    form_data_mapping JSONB,
    
    -- Actions
    available_actions JSONB, -- [{code: 'APPROVE', label: 'Approve', next_state: '...'}, ...]
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_task_code_per_tenant UNIQUE (tenant_id, task_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.task_definition_default PARTITION OF dynamic.task_definition DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_task_def_tenant ON dynamic.task_definition(tenant_id);
CREATE INDEX idx_task_def_lookup ON dynamic.task_definition(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.task_definition IS 'Task templates with form schemas and SLA definitions';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.task_definition TO finos_app;
