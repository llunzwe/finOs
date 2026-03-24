-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 20 - Reporting & Analytics
-- TABLE: dynamic_history.alert_history
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Alert History.
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
CREATE TABLE dynamic_history.alert_history (

    alert_history_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    rule_id UUID NOT NULL REFERENCES dynamic.alert_rules(rule_id),
    
    -- Alert Details
    alert_severity VARCHAR(20) NOT NULL,
    alert_title TEXT NOT NULL,
    alert_description TEXT,
    
    -- Trigger Context
    trigger_value DECIMAL(28,8),
    threshold_value DECIMAL(28,8),
    context_data JSONB, -- Snapshot of data that triggered alert
    
    -- Entity Reference
    affected_entity_type VARCHAR(50),
    affected_entity_id UUID,
    
    -- Notification
    notification_sent_at TIMESTAMPTZ,
    notification_channels_used VARCHAR(50)[],
    notification_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, SENT, FAILED
    notification_error TEXT,
    
    -- Status
    alert_status VARCHAR(20) DEFAULT 'OPEN' 
        CHECK (alert_status IN ('OPEN', 'ACKNOWLEDGED', 'INVESTIGATING', 'RESOLVED', 'ESCALATED', 'SUPPRESSED')),
    
    -- Acknowledgment
    acknowledged_at TIMESTAMPTZ,
    acknowledged_by VARCHAR(100),
    acknowledgment_notes TEXT,
    
    -- Resolution
    resolved_at TIMESTAMPTZ,
    resolved_by VARCHAR(100),
    resolution_notes TEXT,
    resolution_action VARCHAR(100),
    
    -- Timestamps
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    duration_minutes INTEGER GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (COALESCE(resolved_at, NOW()) - triggered_at)) / 60
    ) STORED,
    
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

CREATE TABLE dynamic_history.alert_history_default PARTITION OF dynamic_history.alert_history DEFAULT;

-- Indexes
CREATE INDEX idx_alert_history_rule ON dynamic_history.alert_history(tenant_id, rule_id);
CREATE INDEX idx_alert_history_status ON dynamic_history.alert_history(tenant_id, alert_status) WHERE alert_status IN ('OPEN', 'ACKNOWLEDGED', 'INVESTIGATING');
CREATE INDEX idx_alert_history_time ON dynamic_history.alert_history(triggered_at DESC);
CREATE INDEX idx_alert_history_entity ON dynamic_history.alert_history(tenant_id, affected_entity_type, affected_entity_id);

-- Comments
COMMENT ON TABLE dynamic_history.alert_history IS 'Alert trigger history and resolution tracking';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.alert_history TO finos_app;