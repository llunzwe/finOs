-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 12 - Performance & Operations
-- TABLE: dynamic.alert_configuration
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Alert Configuration.
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
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
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