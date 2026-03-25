-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 24 - Transaction Entity
-- TABLE: dynamic.saga_compensation_rules
--
-- DESCRIPTION:
--   Saga compensation rule configuration for distributed transactions.
--   Configures compensating actions for saga pattern failures.
--
-- CORE DEPENDENCY: 024_transaction_entity.sql
--
-- ============================================================================

CREATE TABLE dynamic.saga_compensation_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Saga Type
    saga_type VARCHAR(100) NOT NULL, -- 'ORDER', 'PAYMENT', 'TRANSFER', 'TRADE'
    
    -- Compensation Configuration
    compensating_action VARCHAR(200) NOT NULL, -- Function/workflow to execute
    compensation_parameters JSONB, -- Parameters for compensating action
    
    -- Trigger Conditions
    trigger_on_failure_types VARCHAR(50)[], -- 'TIMEOUT', 'ERROR', 'REJECTION', 'MANUAL'
    max_compensation_attempts INTEGER DEFAULT 3,
    compensation_retry_interval_seconds INTEGER DEFAULT 30,
    
    -- Compensation Strategy
    compensation_order VARCHAR(20) DEFAULT 'REVERSE', -- REVERSE, PARALLEL, SEQUENTIAL
    fail_saga_if_compensation_fails BOOLEAN DEFAULT TRUE,
    
    -- Notification
    notify_on_compensation_start BOOLEAN DEFAULT TRUE,
    notify_on_compensation_success BOOLEAN DEFAULT TRUE,
    notify_on_compensation_failure BOOLEAN DEFAULT TRUE,
    notification_recipients VARCHAR(500),
    
    -- Manual Intervention
    allow_manual_compensation BOOLEAN DEFAULT TRUE,
    require_manual_approval BOOLEAN DEFAULT FALSE,
    auto_compensate_below_amount DECIMAL(28,8),
    
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
    
    CONSTRAINT unique_saga_compensation_rule UNIQUE (tenant_id, saga_type, rule_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.saga_compensation_rules_default PARTITION OF dynamic.saga_compensation_rules DEFAULT;

CREATE INDEX idx_saga_compensation_type ON dynamic.saga_compensation_rules(tenant_id, saga_type) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.saga_compensation_rules IS 'Saga compensation rule configuration for distributed transaction rollback. Tier 2 Low-Code';

CREATE TRIGGER trg_saga_compensation_rules_audit
    BEFORE UPDATE ON dynamic.saga_compensation_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.saga_compensation_rules TO finos_app;
