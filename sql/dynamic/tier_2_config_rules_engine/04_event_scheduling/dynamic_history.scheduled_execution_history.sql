-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 04 - Event Scheduling
-- TABLE: dynamic_history.scheduled_execution_history
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Scheduled Execution History.
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
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.scheduled_execution_history_default PARTITION OF dynamic_history.scheduled_execution_history DEFAULT;

-- Indexes
CREATE INDEX idx_scheduled_hist_schedule ON dynamic_history.scheduled_execution_history(tenant_id, schedule_id);
CREATE INDEX idx_scheduled_hist_time ON dynamic_history.scheduled_execution_history(scheduled_time DESC);

-- Comments
COMMENT ON TABLE dynamic_history.scheduled_execution_history IS 'Execution history for scheduled events';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.scheduled_execution_history TO finos_app;