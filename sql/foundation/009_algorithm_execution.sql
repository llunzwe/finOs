-- =============================================================================
-- FINOS CORE KERNEL - ALGORITHM EXECUTION LOGGING
-- =============================================================================
-- File: 009_algorithm_execution.sql
-- Description: ML/Algorithm execution tracking and lineage
-- =============================================================================

-- SECTION 19: ALGORITHM EXECUTION LOGGING
-- =============================================================================

CREATE TABLE core_audit.algorithm_executions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    
    -- Algorithm
    algorithm_name VARCHAR(100) NOT NULL,
    algorithm_version VARCHAR(20),
    algorithm_type VARCHAR(50),
    
    -- Execution
    execution_id UUID NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    duration_ms INTEGER,
    
    -- Performance
    rows_scanned BIGINT,
    rows_processed BIGINT,
    cpu_time_ms INTEGER,
    memory_bytes BIGINT,
    
    -- Status
    status VARCHAR(20) NOT NULL CHECK (status IN ('running', 'completed', 'failed', 'timeout')),
    error_message TEXT,
    
    -- Context
    input_parameters JSONB,
    output_results JSONB,
    
    -- Resource
    executed_by VARCHAR(100),
    session_id UUID,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

SELECT create_hypertable('core_audit.algorithm_executions', 'created_at', 
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists => TRUE);

CREATE INDEX idx_algo_exec_name ON core_audit.algorithm_executions(algorithm_name, created_at DESC);
CREATE INDEX idx_algo_exec_status ON core_audit.algorithm_executions(tenant_id, status) WHERE status != 'completed';

COMMENT ON TABLE core_audit.algorithm_executions IS 'Algorithm execution logging for performance monitoring';

-- =============================================================================
