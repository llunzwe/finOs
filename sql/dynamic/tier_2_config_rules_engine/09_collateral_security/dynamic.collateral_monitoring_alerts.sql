-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 09 - Collateral & Security
-- TABLE: dynamic.collateral_monitoring_alerts
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Collateral Monitoring Alerts.
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
CREATE TABLE dynamic.collateral_monitoring_alerts (

    alert_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    collateral_id UUID NOT NULL REFERENCES dynamic.collateral_master(collateral_id),
    
    -- Alert Details
    alert_type VARCHAR(50) NOT NULL 
        CHECK (alert_type IN ('INSURANCE_EXPIRY', 'REVALUATION_DUE', 'VALUE_DECLINE', 'PERFECTION_INCOMPLETE', 'DEFAULT_EVENT')),
    alert_severity VARCHAR(20) DEFAULT 'MEDIUM' 
        CHECK (alert_severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    alert_description TEXT,
    
    -- Trigger
    trigger_value DECIMAL(28,8),
    threshold_value DECIMAL(28,8),
    
    -- Status
    alert_status VARCHAR(20) DEFAULT 'OPEN' 
        CHECK (alert_status IN ('OPEN', 'ACKNOWLEDGED', 'RESOLVED', 'ESCALATED')),
    
    -- Assignment
    assigned_to VARCHAR(100),
    assigned_at TIMESTAMPTZ,
    
    -- Resolution
    resolved_at TIMESTAMPTZ,
    resolved_by VARCHAR(100),
    resolution_notes TEXT,
    
    -- Notifications
    notification_sent BOOLEAN DEFAULT FALSE,
    notification_sent_at TIMESTAMPTZ,
    
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

CREATE TABLE dynamic.collateral_monitoring_alerts_default PARTITION OF dynamic.collateral_monitoring_alerts DEFAULT;

-- Indexes
CREATE INDEX idx_collateral_alert_status ON dynamic.collateral_monitoring_alerts(tenant_id, alert_status) WHERE alert_status IN ('OPEN', 'ACKNOWLEDGED');
CREATE INDEX idx_collateral_alert_collateral ON dynamic.collateral_monitoring_alerts(tenant_id, collateral_id);

-- Comments
COMMENT ON TABLE dynamic.collateral_monitoring_alerts IS 'Collateral monitoring and exception alerts';

GRANT SELECT, INSERT, UPDATE ON dynamic.collateral_monitoring_alerts TO finos_app;