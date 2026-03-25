-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 20 - Blockchain Configuration
-- TABLE: dynamic.anchor_schedules
--
-- DESCRIPTION:
--   Blockchain anchoring schedule configuration.
--   Configures when and how often to anchor Merkle roots.
--
-- CORE DEPENDENCY: 020_blockchain_anchoring.sql
--
-- ============================================================================

CREATE TABLE dynamic.anchor_schedules (
    schedule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Schedule Identification
    schedule_code VARCHAR(100) NOT NULL,
    schedule_name VARCHAR(200) NOT NULL,
    schedule_description TEXT,
    
    -- Target Chain
    chain_id UUID REFERENCES dynamic.sovereign_chain_registry(chain_id),
    anchor_chain dynamic.anchor_chain NOT NULL,
    
    -- Schedule Configuration
    schedule_type VARCHAR(50) NOT NULL DEFAULT 'INTERVAL', -- INTERVAL, CRON, EVENT_DRIVEN
    interval_minutes INTEGER, -- For INTERVAL type
    cron_expression VARCHAR(100), -- For CRON type
    event_trigger VARCHAR(100), -- For EVENT_DRIVEN type
    
    -- Execution Window
    execution_time_window_start TIME DEFAULT '00:00:00',
    execution_time_window_end TIME DEFAULT '23:59:59',
    timezone VARCHAR(50) DEFAULT 'UTC',
    
    -- Batching
    min_batch_size INTEGER DEFAULT 10,
    max_batch_size INTEGER DEFAULT 1000,
    max_wait_minutes INTEGER DEFAULT 60, -- Force anchor after N minutes
    
    -- Retry Logic
    retry_attempts INTEGER DEFAULT 3,
    retry_interval_minutes INTEGER DEFAULT 10,
    exponential_backoff BOOLEAN DEFAULT TRUE,
    
    -- Notifications
    notify_on_success BOOLEAN DEFAULT TRUE,
    notify_on_failure BOOLEAN DEFAULT TRUE,
    notification_recipients VARCHAR(500),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    last_execution_at TIMESTAMPTZ,
    next_scheduled_at TIMESTAMPTZ,
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_anchor_schedule_code UNIQUE (tenant_id, schedule_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.anchor_schedules_default PARTITION OF dynamic.anchor_schedules DEFAULT;

CREATE INDEX idx_anchor_schedule_chain ON dynamic.anchor_schedules(tenant_id, anchor_chain) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.anchor_schedules IS 'Blockchain anchoring schedule configuration for Merkle root anchoring. Tier 2 Low-Code';

CREATE TRIGGER trg_anchor_schedules_audit
    BEFORE UPDATE ON dynamic.anchor_schedules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.anchor_schedules TO finos_app;
