-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 20 - Reporting Analytics
-- TABLE: dynamic.alert_rules
-- COMPLIANCE: BCBS 239
--   - IFRS
--   - XBRL
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.alert_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Alert Type
    alert_type VARCHAR(50) NOT NULL 
        CHECK (alert_type IN ('THRESHOLD', 'TREND', 'ANOMALY', 'EVENT', 'SCHEDULED', 'PREDICTIVE')),
    
    -- Condition
    condition_type VARCHAR(50) NOT NULL 
        CHECK (condition_type IN ('METRIC_THRESHOLD', 'METRIC_COMPARISON', 'CUSTOM_QUERY', 'BUSINESS_RULE', 'SYSTEM_EVENT')),
    
    -- Metric-based Condition
    metric_id UUID REFERENCES dynamic.metric_definitions(metric_id),
    threshold_operator VARCHAR(10), -- >, <, >=, <=, =, !=
    threshold_value DECIMAL(28,8),
    
    -- Query-based Condition
    condition_query TEXT,
    query_result_threshold INTEGER, -- Row count or value
    
    -- Rule-based Condition
    business_rule_id UUID REFERENCES dynamic.business_rule_engine(rule_id),
    
    -- Event-based Condition
    event_type VARCHAR(100),
    event_conditions JSONB,
    
    -- Time Window
    evaluation_window_minutes INTEGER DEFAULT 5,
    cooldown_minutes INTEGER DEFAULT 60, -- Don't alert again within this period
    
    -- Schedule
    schedule_enabled BOOLEAN DEFAULT FALSE,
    schedule_cron VARCHAR(100),
    
    -- Severity
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL', 'EMERGENCY')),
    
    -- Notification
    notification_channels VARCHAR(50)[] DEFAULT ARRAY['EMAIL'], -- EMAIL, SMS, SLACK, PAGERDUTY, WEBHOOK
    notification_recipients JSONB, -- {emails: [], sms_numbers: [], slack_channels: []}
    notification_template_id UUID,
    escalation_rules JSONB, -- [{delay_minutes: 30, escalate_to: 'MANAGER'}, ...]
    
    -- Actions
    auto_action_enabled BOOLEAN DEFAULT FALSE,
    auto_action_type VARCHAR(50), -- EXECUTE_SCRIPT, CREATE_TICKET, TRIGGER_WORKFLOW
    auto_action_config JSONB,
    
    -- Deduplication
    deduplication_key_fields VARCHAR(100)[], -- Fields to use for grouping similar alerts
    max_alerts_per_hour INTEGER DEFAULT 10,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Statistics
    trigger_count INTEGER DEFAULT 0,
    last_triggered_at TIMESTAMPTZ,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_alert_rule_code UNIQUE (tenant_id, rule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.alert_rules_default PARTITION OF dynamic.alert_rules DEFAULT;

-- Indexes
CREATE INDEX idx_alert_rules_tenant ON dynamic.alert_rules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_alert_rules_type ON dynamic.alert_rules(tenant_id, alert_type) WHERE is_active = TRUE;
CREATE INDEX idx_alert_rules_severity ON dynamic.alert_rules(tenant_id, severity) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.alert_rules IS 'Threshold-based and anomaly detection alert rules';

-- Triggers
CREATE TRIGGER trg_alert_rules_audit
    BEFORE UPDATE ON dynamic.alert_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.alert_rules TO finos_app;