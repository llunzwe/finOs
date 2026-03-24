-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 12 - Performance Operations
-- TABLE: dynamic.alert_configuration
-- COMPLIANCE: ITIL
--   - ISO 20000
--   - ISO 27001
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic.alert_configuration (

    alert_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    alert_name VARCHAR(200) NOT NULL,
    alert_description TEXT,
    
    -- Trigger
    trigger_type VARCHAR(50) NOT NULL 
        CHECK (trigger_type IN ('METRIC_THRESHOLD', 'EVENT', 'SCHEDULE', 'ANOMALY', 'HEARTBEAT')),
    trigger_condition TEXT NOT NULL, -- SQL or expression
    
    -- Severity
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL', 'EMERGENCY')),
    
    -- Notification
    notification_channels TEXT[], -- EMAIL, SMS, SLACK, PAGERDUTY
    notification_recipients JSONB, -- {emails: [], sms: [], webhooks: []}
    notification_template_id UUID,
    
    -- Throttling
    throttle_minutes INTEGER DEFAULT 60,
    max_notifications_per_hour INTEGER DEFAULT 10,
    
    -- Auto-Action
    auto_action_enabled BOOLEAN DEFAULT FALSE,
    auto_action_script TEXT,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Statistics
    trigger_count INTEGER DEFAULT 0,
    last_triggered_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.alert_configuration_default PARTITION OF dynamic.alert_configuration DEFAULT;

-- Indexes
CREATE INDEX idx_alert_config_active ON dynamic.alert_configuration(tenant_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.alert_configuration IS 'System and business alert definitions';

-- Triggers
CREATE TRIGGER trg_alert_configuration_audit
    BEFORE UPDATE ON dynamic.alert_configuration
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.alert_configuration TO finos_app;