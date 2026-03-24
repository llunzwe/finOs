-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 12 - Performance Operations
-- TABLE: dynamic_history.batch_job_execution_history
-- COMPLIANCE: ITIL
--   - ISO 20000
--   - ISO 27001
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic_history.batch_job_execution_history (

    execution_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    job_id UUID NOT NULL REFERENCES dynamic.batch_job_control(job_id),
    
    -- Execution Details
    execution_status VARCHAR(20) NOT NULL 
        CHECK (execution_status IN ('RUNNING', 'COMPLETED', 'FAILED', 'TIMEOUT', 'CANCELLED', 'SKIPPED')),
    
    -- Timing
    scheduled_at TIMESTAMPTZ NOT NULL,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    
    -- Context
    execution_context JSONB, -- Parameters, environment
    
    -- Output
    output_summary TEXT,
    output_details JSONB,
    records_processed INTEGER,
    
    -- Error
    error_code VARCHAR(100),
    error_message TEXT,
    error_stack_trace TEXT,
    
    -- Retry
    is_retry BOOLEAN DEFAULT FALSE,
    retry_attempt INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.batch_job_execution_history_default PARTITION OF dynamic_history.batch_job_execution_history DEFAULT;

-- Indexes
CREATE INDEX idx_batch_exec_job ON dynamic_history.batch_job_execution_history(tenant_id, job_id);
CREATE INDEX idx_batch_exec_status ON dynamic_history.batch_job_execution_history(tenant_id, execution_status);
CREATE INDEX idx_batch_exec_time ON dynamic_history.batch_job_execution_history(started_at DESC);

-- Comments
COMMENT ON TABLE dynamic_history.batch_job_execution_history IS 'Batch job execution audit trail';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.batch_job_execution_history TO finos_app;