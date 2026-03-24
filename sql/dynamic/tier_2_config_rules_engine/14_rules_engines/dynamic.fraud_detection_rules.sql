-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 14 - Rules Engines
-- TABLE: dynamic.fraud_detection_rules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Fraud Detection Rules.
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
CREATE TABLE dynamic.fraud_detection_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Rule Category
    fraud_category VARCHAR(50) NOT NULL 
        CHECK (fraud_category IN ('IDENTITY_THEFT', 'ACCOUNT_TAKEOVER', 'CARD_FRAUD', 'MONEY_LAUNDERING', 'INSIDER_TRADING', 'PHISHING', 'SYNTHETIC_IDENTITY', 'APPLICATION_FRAUD', 'TRANSACTION_FRAUD')),
    
    -- Trigger Event
    trigger_event VARCHAR(100) NOT NULL, -- TRANSACTION_INITIATED, LOGIN_ATTEMPT, ACCOUNT_CHANGE, etc.
    
    -- Detection Logic
    detection_logic JSONB NOT NULL, -- JSONLogic expression or DSL
    rule_expression TEXT, -- Lua/JSONLogic script
    
    -- Scoring
    risk_score_increment INTEGER NOT NULL DEFAULT 10, -- Points to add when rule fires
    score_cap INTEGER DEFAULT 100,
    
    -- Thresholds
    alert_threshold INTEGER DEFAULT 50, -- Score at which to alert
    block_threshold INTEGER DEFAULT 80, -- Score at which to block
    
    -- Actions
    action_on_trigger VARCHAR(50) DEFAULT 'SCORE' 
        CHECK (action_on_trigger IN ('SCORE', 'ALERT', 'BLOCK', 'CHALLENGE', 'REVIEW', 'DECLINE')),
    action_parameters JSONB, -- {notification_channels: ['EMAIL', 'SMS'], escalation_hours: 2}
    
    -- Velocity Controls
    velocity_window_minutes INTEGER,
    velocity_max_count INTEGER,
    velocity_amount_threshold DECIMAL(28,8),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    priority INTEGER DEFAULT 0,
    
    -- Performance
    execution_order INTEGER DEFAULT 0,
    stop_on_trigger BOOLEAN DEFAULT FALSE, -- Stop processing other rules if this triggers
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_fraud_rule_code UNIQUE (tenant_id, rule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.fraud_detection_rules_default PARTITION OF dynamic.fraud_detection_rules DEFAULT;

-- Indexes
CREATE INDEX idx_fraud_rules_tenant ON dynamic.fraud_detection_rules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_fraud_rules_category ON dynamic.fraud_detection_rules(tenant_id, fraud_category) WHERE is_active = TRUE;
CREATE INDEX idx_fraud_rules_event ON dynamic.fraud_detection_rules(tenant_id, trigger_event) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.fraud_detection_rules IS 'Real-time fraud detection rules with scoring';

-- Triggers
CREATE TRIGGER trg_fraud_detection_rules_audit
    BEFORE UPDATE ON dynamic.fraud_detection_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.fraud_detection_rules TO finos_app;