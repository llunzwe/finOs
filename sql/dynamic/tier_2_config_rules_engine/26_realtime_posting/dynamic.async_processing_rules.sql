-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Real-Time Posting
-- TABLE: dynamic.async_processing_rules
--
-- DESCRIPTION:
--   Async processing rule configuration.
--   Configures deferred and background posting rules.
--
-- CORE DEPENDENCY: 026_real_time_posting.sql
--
-- ============================================================================

CREATE TABLE dynamic.async_processing_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Async Trigger Conditions
    trigger_condition VARCHAR(50) NOT NULL, -- ALWAYS, VOLUME_BASED, TIME_BASED, ERROR_CONDITION
    
    -- Volume-Based Triggers
    batch_size_threshold INTEGER, -- Process when N items accumulated
    batch_value_threshold DECIMAL(28,8), -- Process when total value reaches threshold
    
    -- Time-Based Triggers
    schedule_cron VARCHAR(100), -- Cron expression for scheduled processing
    max_deferral_seconds INTEGER DEFAULT 300, -- Maximum time to defer
    
    -- Applicability
    applicable_movement_types VARCHAR(50)[],
    applicable_container_types VARCHAR(50)[],
    applicable_amount_range_min DECIMAL(28,8),
    applicable_amount_range_max DECIMAL(28,8),
    
    -- Processing Configuration
    processing_mode VARCHAR(50) DEFAULT 'BATCH', -- BATCH, STREAM, PARALLEL
    max_batch_size INTEGER DEFAULT 1000,
    parallel_workers INTEGER DEFAULT 4,
    
    -- Ordering
    preserve_ordering BOOLEAN DEFAULT TRUE,
    ordering_key VARCHAR(100), -- Field to order by
    
    -- Error Handling
    on_error_action VARCHAR(50) DEFAULT 'RETRY', -- RETRY, DLQ, ALERT, SKIP
    max_retries INTEGER DEFAULT 3,
    dead_letter_queue_enabled BOOLEAN DEFAULT TRUE,
    
    -- Notification
    notify_on_batch_complete BOOLEAN DEFAULT FALSE,
    notify_on_error BOOLEAN DEFAULT TRUE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
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
    
    CONSTRAINT unique_async_processing_rule UNIQUE (tenant_id, rule_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.async_processing_rules_default PARTITION OF dynamic.async_processing_rules DEFAULT;

CREATE INDEX idx_async_processing_trigger ON dynamic.async_processing_rules(tenant_id, trigger_condition) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.async_processing_rules IS 'Async processing rule configuration for deferred ledger posting. Tier 2 Low-Code';

CREATE TRIGGER trg_async_processing_rules_audit
    BEFORE UPDATE ON dynamic.async_processing_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.async_processing_rules TO finos_app;
