-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 12 - Performance Operations
-- TABLE: dynamic.batch_job_control
-- COMPLIANCE: ITIL
--   - ISO 20000
--   - ISO 27001
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic.batch_job_control (

    job_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    job_name VARCHAR(200) NOT NULL,
    job_code VARCHAR(100) NOT NULL,
    job_description TEXT,
    
    -- Job Type
    job_type VARCHAR(50) NOT NULL 
        CHECK (job_type IN ('ACCRUAL', 'INTEREST_POSTING', 'STATEMENTS', 'REPORTS', 'RECONCILIATION', 'ARCHIVAL', 'CLEANUP', 'CUSTOM')),
    
    -- Schedule
    schedule_cron VARCHAR(100) NOT NULL,
    schedule_timezone VARCHAR(50) DEFAULT 'UTC',
    
    -- Dependencies
    dependency_jobs UUID[], -- Array of job_ids that must complete first
    dependency_check_type VARCHAR(20) DEFAULT 'ALL' CHECK (dependency_check_type IN ('ALL', 'ANY')),
    
    -- Execution
    executable_path TEXT,
    executable_parameters JSONB,
    
    -- Limits
    max_runtime_minutes INTEGER DEFAULT 60,
    max_retry_attempts INTEGER DEFAULT 3,
    
    -- Notifications
    success_notification BOOLEAN DEFAULT FALSE,
    failure_notification BOOLEAN DEFAULT TRUE,
    notification_groups TEXT[],
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_paused BOOLEAN DEFAULT FALSE,
    
    -- Last Run
    last_run_at TIMESTAMPTZ,
    last_run_status VARCHAR(20),
    last_run_duration_seconds INTEGER,
    last_run_output TEXT,
    last_run_error TEXT,
    
    -- Next Run
    next_run_at TIMESTAMPTZ,
    
    -- Statistics
    total_runs INTEGER DEFAULT 0,
    successful_runs INTEGER DEFAULT 0,
    failed_runs INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_job_code UNIQUE (tenant_id, job_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.batch_job_control_default PARTITION OF dynamic.batch_job_control DEFAULT;

-- Indexes
CREATE INDEX idx_batch_job_tenant ON dynamic.batch_job_control(tenant_id) WHERE is_active = TRUE AND is_paused = FALSE;
CREATE INDEX idx_batch_job_next ON dynamic.batch_job_control(next_run_at) WHERE is_active = TRUE AND is_paused = FALSE;

-- Comments
COMMENT ON TABLE dynamic.batch_job_control IS 'EOD/EOM batch job scheduling and control';

-- Triggers
CREATE TRIGGER trg_batch_job_control_audit
    BEFORE UPDATE ON dynamic.batch_job_control
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.batch_job_control TO finos_app;