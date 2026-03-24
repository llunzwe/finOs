-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 04 - Event Scheduling
-- TABLE: dynamic_history.scheduled_execution_history
-- COMPLIANCE: ISO 8601
--   - ISO 20022
--   - ISO 25010
--   - GDPR
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic_history.scheduled_execution_history (

    history_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    schedule_id UUID NOT NULL REFERENCES dynamic.scheduled_event_cron(schedule_id),
    
    scheduled_time TIMESTAMPTZ NOT NULL,
    actual_execution_time TIMESTAMPTZ,
    
    status VARCHAR(20) NOT NULL,
    output JSONB,
    error_message TEXT,
    
    duration_ms INTEGER,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.scheduled_execution_history_default PARTITION OF dynamic_history.scheduled_execution_history DEFAULT;

-- Indexes
CREATE INDEX idx_scheduled_hist_schedule ON dynamic_history.scheduled_execution_history(tenant_id, schedule_id);
CREATE INDEX idx_scheduled_hist_time ON dynamic_history.scheduled_execution_history(scheduled_time DESC);

-- Comments
COMMENT ON TABLE dynamic_history.scheduled_execution_history IS 'Execution history for scheduled events';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.scheduled_execution_history TO finos_app;