-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 24 - Transaction Entity
-- TABLE: dynamic.transaction_timeout_policies
--
-- DESCRIPTION:
--   Transaction timeout policy configuration.
--   Configures timeout behavior for distributed transactions.
--
-- CORE DEPENDENCY: 024_transaction_entity.sql
--
-- ============================================================================

CREATE TABLE dynamic.transaction_timeout_policies (
    policy_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Policy Identification
    policy_code VARCHAR(100) NOT NULL,
    policy_name VARCHAR(200) NOT NULL,
    policy_description TEXT,
    
    -- Transaction Type
    transaction_type VARCHAR(100) NOT NULL, -- 'PAYMENT', 'TRANSFER', 'TRADE', 'SETTLEMENT'
    
    -- Timeout Settings
    total_timeout_seconds INTEGER NOT NULL DEFAULT 300, -- 5 minutes default
    step_timeout_seconds INTEGER DEFAULT 60, -- Per-step timeout
    
    -- Timeout Stages
    warning_at_seconds INTEGER DEFAULT 120, -- Warning before timeout
    escalation_at_seconds INTEGER DEFAULT 240, -- Escalate before final timeout
    
    -- Timeout Actions
    on_timeout_action VARCHAR(50) DEFAULT 'COMPENSATE', -- COMPENSATE, ABORT, ALERT, HOLD
    on_timeout_notify BOOLEAN DEFAULT TRUE,
    on_timeout_escalate BOOLEAN DEFAULT TRUE,
    
    -- Retry Before Timeout
    retry_before_timeout BOOLEAN DEFAULT TRUE,
    max_retries INTEGER DEFAULT 3,
    retry_interval_seconds INTEGER DEFAULT 10,
    
    -- Long-Running Transaction Support
    allow_long_running BOOLEAN DEFAULT FALSE,
    long_running_threshold_seconds INTEGER DEFAULT 3600,
    heartbeat_interval_seconds INTEGER DEFAULT 30,
    
    -- Cleanup
    auto_cleanup_after_hours INTEGER DEFAULT 72,
    cleanup_action VARCHAR(50) DEFAULT 'ARCHIVE', -- ARCHIVE, DELETE, MARK_FAILED
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    
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
    
    CONSTRAINT unique_transaction_timeout_policy UNIQUE (tenant_id, transaction_type, policy_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.transaction_timeout_policies_default PARTITION OF dynamic.transaction_timeout_policies DEFAULT;

CREATE INDEX idx_transaction_timeout_type ON dynamic.transaction_timeout_policies(tenant_id, transaction_type) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.transaction_timeout_policies IS 'Transaction timeout policy configuration for distributed transaction lifecycle. Tier 2 Low-Code';

CREATE TRIGGER trg_transaction_timeout_policies_audit
    BEFORE UPDATE ON dynamic.transaction_timeout_policies
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.transaction_timeout_policies TO finos_app;
