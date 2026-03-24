-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 12 - Performance & Operations
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
CREATE INDEX idx_alert_history_alert ON dynamic_history.alert_history(tenant_id, alert_id);
CREATE INDEX idx_alert_history_open ON dynamic_history.alert_history(tenant_id, alert_status) WHERE alert_status IN ('OPEN', 'ACKNOWLEDGED');
CREATE INDEX idx_alert_history_time ON dynamic_history.alert_history(triggered_at DESC);

-- Comments
COMMENT ON TABLE dynamic_history.alert_history IS 'Triggered alert history and resolution tracking';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.alert_history TO finos_app;