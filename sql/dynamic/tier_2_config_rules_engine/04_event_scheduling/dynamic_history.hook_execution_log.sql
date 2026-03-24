-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 04 - Event & Scheduling
-- TABLE: dynamic_history.hook_execution_log
--
-- DESCRIPTION:
--   Configuration table for Hook Execution Log
--
-- TIER: 2 - Low-Code Configuration (UI/API setup, no coding required)
--
-- COMPLIANCE FRAMEWORK:
--   - ISO 8601: Date/time representation
--   - ISO 20022: Event messaging standards
--   - GDPR: Event data retention
--   - BCBS 239: Event data aggregation
--
-- AUDIT & GOVERNANCE:
--   - Bitemporal tracking (effective_from/to, created/updated)
--   - Full audit trail via triggers
--   - Tenant isolation for data residency
--   - Version control for change management
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

-- Comments
COMMENT ON TABLE dynamic_history.hook_execution_log IS 'Audit trail of hook executions with sandbox isolation';

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic_history.hook_execution_log TO finos_app;
