-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 12 - Performance Operations
-- TABLE: dynamic_history.alert_history
-- COMPLIANCE: ITIL
--   - ISO 20000
--   - ISO 27001
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic_history.alert_history (

    history_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    alert_id UUID NOT NULL REFERENCES dynamic.alert_configuration(alert_id),
    
    -- Trigger Details
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    trigger_value DECIMAL(20,8),
    trigger_context JSONB,
    
    -- Notification
    notification_sent BOOLEAN DEFAULT FALSE,
    notification_sent_at TIMESTAMPTZ,
    notification_error TEXT,
    
    -- Status
    alert_status VARCHAR(20) DEFAULT 'OPEN' 
        CHECK (alert_status IN ('OPEN', 'ACKNOWLEDGED', 'RESOLVED', 'ESCALATED')),
    
    -- Resolution
    acknowledged_at TIMESTAMPTZ,
    acknowledged_by VARCHAR(100),
    resolved_at TIMESTAMPTZ,
    resolved_by VARCHAR(100),
    resolution_notes TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.alert_history_default PARTITION OF dynamic_history.alert_history DEFAULT;

-- Indexes
CREATE INDEX idx_alert_history_alert ON dynamic_history.alert_history(tenant_id, alert_id);
CREATE INDEX idx_alert_history_open ON dynamic_history.alert_history(tenant_id, alert_status) WHERE alert_status IN ('OPEN', 'ACKNOWLEDGED');
CREATE INDEX idx_alert_history_time ON dynamic_history.alert_history(triggered_at DESC);

-- Comments
COMMENT ON TABLE dynamic_history.alert_history IS 'Triggered alert history and resolution tracking';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.alert_history TO finos_app;