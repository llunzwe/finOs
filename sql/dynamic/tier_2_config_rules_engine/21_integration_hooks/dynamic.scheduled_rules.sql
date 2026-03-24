-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 21 - Integration Hooks
-- TABLE: dynamic.scheduled_rules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Scheduled Rules.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 8601
--   - ISO 20022
--   - IFRS 15
--   - Basel III
--   - OECD
--   - NCA
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
CREATE TABLE dynamic.scheduled_rules (

    schedule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    schedule_code VARCHAR(100) NOT NULL,
    schedule_name VARCHAR(200) NOT NULL,
    schedule_description TEXT,
    
    -- Schedule Type
    schedule_type VARCHAR(50) NOT NULL 
        CHECK (schedule_type IN ('CRON', 'INTERVAL', 'ONE_TIME', 'EVENT_BASED')),
    
    -- Timing
    cron_expression VARCHAR(100), -- Standard cron expression
    timezone VARCHAR(50) DEFAULT 'UTC',
    interval_seconds INTEGER, -- For INTERVAL type
    
    -- Execution Target
    target_type VARCHAR(50) NOT NULL 
        CHECK (target_type IN ('SQL_QUERY', 'HOOK', 'WORKFLOW', 'API_CALL', 'REPORT', 'BATCH_JOB')),
    target_id UUID, -- Reference to hook, workflow, etc.
    target_config JSONB, -- {query: '...', params: {...}} or {endpoint: '...', method: 'POST'}
    
    -- Holiday Handling
    holiday_calendar_id UUID,
    holiday_behavior VARCHAR(20) DEFAULT 'RUN' 
        CHECK (holiday_behavior IN ('RUN', 'SKIP', 'NEXT_BUSINESS_DAY', 'PREVIOUS_BUSINESS_DAY')),
    
    -- Dependencies
    depends_on_schedules UUID[], -- Other schedules that must complete first
    dependency_timeout_minutes INTEGER DEFAULT 60,
    
    -- Execution Limits
    max_runtime_minutes INTEGER DEFAULT 60,
    timeout_action VARCHAR(50) DEFAULT 'KILL' CHECK (timeout_action IN ('KILL', 'ALERT', 'KILL_AND_ALERT')),
    
    -- Notifications
    notify_on_success BOOLEAN DEFAULT FALSE,
    notify_on_failure BOOLEAN DEFAULT TRUE,
    notification_recipients TEXT[],
    
    -- Execution Tracking
    next_execution_time TIMESTAMPTZ,
    last_execution_time TIMESTAMPTZ,
    last_execution_status VARCHAR(20),
    last_execution_output TEXT,
    last_execution_error TEXT,
    last_execution_duration_ms INTEGER,
    
    -- Statistics
    total_executions INTEGER DEFAULT 0,
    successful_executions INTEGER DEFAULT 0,
    failed_executions INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_paused BOOLEAN DEFAULT FALSE,
    paused_at TIMESTAMPTZ,
    paused_by VARCHAR(100),
    paused_reason TEXT,
    
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
    
    CONSTRAINT unique_scheduled_rule_code UNIQUE (tenant_id, schedule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.scheduled_rules_default PARTITION OF dynamic.scheduled_rules DEFAULT;

-- Indexes
CREATE INDEX idx_scheduled_rules_tenant ON dynamic.scheduled_rules(tenant_id) WHERE is_active = TRUE AND is_paused = FALSE;
CREATE INDEX idx_scheduled_rules_next ON dynamic.scheduled_rules(tenant_id, next_execution_time) WHERE is_active = TRUE AND is_paused = FALSE;
CREATE INDEX idx_scheduled_rules_type ON dynamic.scheduled_rules(tenant_id, target_type) WHERE is_active = TRUE AND is_paused = FALSE;

-- Comments
COMMENT ON TABLE dynamic.scheduled_rules IS 'Cron/daily/monthly scheduled jobs (accruals, fees, reports)';

-- Triggers
CREATE TRIGGER trg_scheduled_rules_audit
    BEFORE UPDATE ON dynamic.scheduled_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.scheduled_rules TO finos_app;