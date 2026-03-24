-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 04 - Event Scheduling
-- TABLE: dynamic.scheduled_event_cron
-- COMPLIANCE: ISO 8601
--   - ISO 20022
--   - ISO 25010
--   - GDPR
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic.scheduled_event_cron (

    schedule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    schedule_name VARCHAR(200) NOT NULL,
    schedule_description TEXT,
    
    -- Cron Expression
    cron_expression VARCHAR(100) NOT NULL,
    timezone VARCHAR(50) DEFAULT 'UTC',
    
    -- Holiday Adjustment
    holiday_adjustment VARCHAR(20) DEFAULT 'NONE' 
        CHECK (holiday_adjustment IN ('NONE', 'PREVIOUS_BUSINESS_DAY', 'NEXT_BUSINESS_DAY', 'SKIP')),
    holiday_calendar_id UUID,
    
    -- Target
    target_hook_id UUID REFERENCES dynamic.hook_definition(hook_id),
    target_workflow_id UUID,
    target_event_type VARCHAR(100),
    target_payload JSONB,
    
    -- Execution Tracking
    next_execution_time TIMESTAMPTZ,
    last_execution_time TIMESTAMPTZ,
    last_execution_status VARCHAR(20),
    last_execution_output JSONB,
    execution_count BIGINT DEFAULT 0,
    failure_count BIGINT DEFAULT 0,
    
    -- Retry
    max_retries INTEGER DEFAULT 3,
    failure_notification_group VARCHAR(100),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    paused BOOLEAN DEFAULT FALSE,
    paused_at TIMESTAMPTZ,
    paused_by VARCHAR(100),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.scheduled_event_cron_default PARTITION OF dynamic.scheduled_event_cron DEFAULT;

-- Indexes
CREATE INDEX idx_scheduled_cron_tenant ON dynamic.scheduled_event_cron(tenant_id) WHERE is_active = TRUE AND paused = FALSE;
CREATE INDEX idx_scheduled_cron_next ON dynamic.scheduled_event_cron(next_execution_time) WHERE is_active = TRUE AND paused = FALSE;

-- Comments
COMMENT ON TABLE dynamic.scheduled_event_cron IS 'Time-based event triggers with cron expressions';

-- Triggers
CREATE TRIGGER trg_scheduled_event_cron_audit
    BEFORE UPDATE ON dynamic.scheduled_event_cron
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.scheduled_event_cron TO finos_app;