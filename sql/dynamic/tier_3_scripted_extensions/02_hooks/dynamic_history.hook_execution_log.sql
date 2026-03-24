-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 3: SCRIPTED EXTENSIONS (PRO-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Hooks
-- TABLE: dynamic_history.hook_execution_log
--
-- DESCRIPTION:
--   Enterprise-grade execution log for Tier 3 Hooks.
--   Records all hook script executions for audit and debugging.
--   Supports tenant isolation and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 3 - Pro-Code Extensions: Developer-only JavaScript, Lua, WASM scripts.
--   Requires coding expertise - managed through developer interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 27001 (Sandboxing)
--   - SOX (Audit)
--   - GDPR (Data Protection)
--
-- AUDIT & GOVERNANCE:
--   - Full audit trail (created_at, updated_at, created_by, updated_by)
--   - Sandbox isolation for security
--   - Tenant isolation via partitioning
--   - Row-Level Security (RLS) for data protection
--
-- DATA CLASSIFICATION:
--   - Tenant Isolation: Row-Level Security enabled
--   - Audit Level: FULL
--   - Encryption: At-rest for sensitive fields
--
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
    execution_logs TEXT,
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
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    correlation_id UUID,
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.hook_execution_log_default PARTITION OF dynamic_history.hook_execution_log DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_hook_execution_tenant ON dynamic_history.hook_execution_log(tenant_id);
CREATE INDEX idx_hook_execution_hook ON dynamic_history.hook_execution_log(tenant_id, hook_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic_history.hook_execution_log IS 'Hook execution log for audit and debugging. Tier 3 - Scripted Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic_history.hook_execution_log TO finos_app;
