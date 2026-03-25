-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 11 - Control & Batch Processing
-- TABLE: dynamic.eod_workflow_configs
--
-- DESCRIPTION:
--   End-of-day workflow configuration.
--   Configures EOD batch job sequences, dependencies, and scheduling.
--
-- CORE DEPENDENCY: 011_control_and_batch_processing.sql
--
-- ============================================================================

CREATE TABLE dynamic.eod_workflow_configs (
    workflow_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Workflow Identification
    workflow_code VARCHAR(100) NOT NULL,
    workflow_name VARCHAR(200) NOT NULL,
    workflow_description TEXT,
    
    -- Schedule
    schedule_type VARCHAR(20) DEFAULT 'DAILY', -- DAILY, WEEKLY, MONTHLY, END_OF_MONTH
    execution_time TIME NOT NULL DEFAULT '18:00:00',
    timezone VARCHAR(50) DEFAULT 'UTC',
    business_day_only BOOLEAN DEFAULT TRUE,
    
    -- Workflow Steps
    workflow_steps JSONB NOT NULL, -- Ordered array of steps with job references
    -- [{"step": 1, "job_code": "INTEREST_ACCRUAL", "depends_on": [], "parallel": false}, ...]
    
    -- Dependencies
    predecessor_workflows UUID[], -- Other EOD workflows that must complete first
    
    -- Execution Rules
    max_parallel_jobs INTEGER DEFAULT 5,
    retry_failed_jobs BOOLEAN DEFAULT TRUE,
    max_retries INTEGER DEFAULT 3,
    stop_on_failure BOOLEAN DEFAULT TRUE,
    
    -- Notifications
    notify_on_start BOOLEAN DEFAULT TRUE,
    notify_on_completion BOOLEAN DEFAULT TRUE,
    notify_on_failure BOOLEAN DEFAULT TRUE,
    notification_recipients VARCHAR(500), -- Email addresses
    
    -- SLA
    expected_duration_minutes INTEGER DEFAULT 120,
    warning_threshold_minutes INTEGER DEFAULT 180,
    critical_threshold_minutes INTEGER DEFAULT 240,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    
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
    
    CONSTRAINT unique_eod_workflow_code UNIQUE (tenant_id, workflow_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.eod_workflow_configs_default PARTITION OF dynamic.eod_workflow_configs DEFAULT;

CREATE INDEX idx_eod_workflow_active ON dynamic.eod_workflow_configs(tenant_id) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.eod_workflow_configs IS 'End-of-day workflow configuration for batch job sequencing. Tier 2 Low-Code';

CREATE TRIGGER trg_eod_workflow_configs_audit
    BEFORE UPDATE ON dynamic.eod_workflow_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.eod_workflow_configs TO finos_app;
