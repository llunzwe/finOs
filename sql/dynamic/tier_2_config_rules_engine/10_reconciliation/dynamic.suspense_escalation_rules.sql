-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 10 - Reconciliation
-- TABLE: dynamic.suspense_escalation_rules
--
-- DESCRIPTION:
--   Suspense item auto-escalation rules configuration.
--   Configures when unmatched items escalate to manual review.
--
-- CORE DEPENDENCY: 010_reconciliation_and_suspense.sql
--
-- ============================================================================

CREATE TABLE dynamic.suspense_escalation_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Applicability
    applicable_suspense_categories VARCHAR(50)[], -- 'UNMATCHED', 'AMOUNT_MISMATCH', 'DUPLICATE'
    applicable_amount_range_min DECIMAL(28,8),
    applicable_amount_range_max DECIMAL(28,8),
    applicable_currencies CHAR(3)[],
    
    -- Escalation Conditions
    age_hours_threshold INTEGER NOT NULL DEFAULT 24, -- Escalate after N hours
    retry_attempts_threshold INTEGER DEFAULT 3,
    
    -- Escalation Actions
    escalation_action VARCHAR(50) DEFAULT 'NOTIFY', -- NOTIFY, ASSIGN, AUTO_RESOLVE, ALERT
    assign_to_role VARCHAR(100),
    assign_to_user UUID,
    
    -- Notification
    notify_roles VARCHAR(100)[],
    notify_users UUID[],
    notification_template VARCHAR(100),
    
    -- Auto-Resolution (if enabled)
    auto_resolve_condition JSONB, -- JSON logic for auto-resolution
    auto_resolve_action VARCHAR(50), -- POST_TO_ACCOUNT, REVERSE, WRITE_OFF
    
    -- Priority
    priority INTEGER DEFAULT 100, -- Lower = higher priority
    
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
    
    CONSTRAINT unique_suspense_escalation_rule UNIQUE (tenant_id, rule_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.suspense_escalation_rules_default PARTITION OF dynamic.suspense_escalation_rules DEFAULT;

CREATE INDEX idx_suspense_escalation_active ON dynamic.suspense_escalation_rules(tenant_id) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.suspense_escalation_rules IS 'Suspense item auto-escalation rules for unmatched reconciliation items. Tier 2 Low-Code';

CREATE TRIGGER trg_suspense_escalation_rules_audit
    BEFORE UPDATE ON dynamic.suspense_escalation_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.suspense_escalation_rules TO finos_app;
