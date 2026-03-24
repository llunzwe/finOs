-- =============================================================================
-- FINOS CORE KERNEL - SCHEDULED JOBS
-- =============================================================================
-- File: 007_scheduled_jobs.sql
-- Description: pg_cron scheduled job management
-- Dependencies: pg_cron
-- =============================================================================

-- SECTION 17: PG_CRON SCHEDULED JOBS
-- =============================================================================

-- Enable pg_cron if available
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS "pg_cron";
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron extension not available, scheduled jobs must be managed externally';
END $$;

CREATE TABLE core.scheduled_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID,
    
    -- Job Definition
    job_name VARCHAR(100) NOT NULL,
    job_type VARCHAR(50) NOT NULL CHECK (job_type IN ('sql_function', 'maintenance', 'snapshot', 'refresh_mv', 'cleanup')),
    
    -- Schedule (cron format or interval)
    schedule_type VARCHAR(20) NOT NULL CHECK (schedule_type IN ('cron', 'interval')),
    schedule_expression TEXT NOT NULL, -- '* * * * *' or '1 hour'
    
    -- Execution
    function_name VARCHAR(100),
    function_parameters JSONB DEFAULT '{}',
    sql_command TEXT,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    run_count INTEGER DEFAULT 0,
    last_run_at TIMESTAMPTZ,
    last_run_status VARCHAR(20),
    last_run_output TEXT,
    last_error TEXT,
    
    -- Concurrency
    max_concurrent_runs INTEGER DEFAULT 1,
    
    -- Timeout
    timeout_seconds INTEGER DEFAULT 300,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    CONSTRAINT unique_job_name UNIQUE (COALESCE(tenant_id, '00000000-0000-0000-0000-000000000000'::UUID), job_name)
);

CREATE INDEX idx_scheduled_jobs_active ON core.scheduled_jobs(is_active) WHERE is_active = TRUE;

COMMENT ON TABLE core.scheduled_jobs IS 'pg_cron scheduled job definitions for EOD, snapshots, maintenance';

-- =============================================================================
