-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 3: SCRIPTED EXTENSIONS (SMART CONTRACTS)
-- ============================================================================
-- TABLE: dynamic_history.hook_execution_log
-- DESCRIPTION: Hook Execution Log
-- COMPLIANCE: ISO 27001 (Sandboxing), SOX (Audit), GDPR (Data Protection)
-- TIER: 3 - Developer-Only (JavaScript, Lua, WASM scripts)
-- ============================================================================

CREATE TABLE dynamic_history.hook_execution_log (

    execution_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    hook_id UUID NOT NULL REFERENCES dynamic.hook_definition(hook_id),
    
    -- Trigger
    trigger_event VARCHAR(100) NOT NULL,
    trigger_event_id UUID,
    
    -- Execution
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    duration_ms INTEGER,
    
    -- Sandbox
    sandbox_instance_id VARCHAR(100),
    
    -- I/O
    input_payload JSONB,
    output_result JSONB,
    
    -- Logs
    execution_logs TEXT, -- stdout/stderr
    log_level VARCHAR(20) DEFAULT 'INFO',
    
    -- Status
    status VARCHAR(20) DEFAULT 'RUNNING' 
        CHECK (status IN ('RUNNING', 'COMPLETED', 'FAILED', 'TIMEOUT', 'CANCELLED')),
    error_message TEXT,
    error_stack_trace TEXT,
    
    -- Retry
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    correlation_id UUID

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.hook_execution_log_default PARTITION OF dynamic_history.hook_execution_log DEFAULT;

COMMENT ON TABLE dynamic_history.hook_execution_log IS 'Hook Execution Log. Tier 3 - Scripted Extensions (Developer Only).';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.hook_execution_log TO finos_app;
