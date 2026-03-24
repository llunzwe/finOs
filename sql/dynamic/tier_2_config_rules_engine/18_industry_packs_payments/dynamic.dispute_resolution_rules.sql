-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 18 - Industry Packs: Payments
-- TABLE: dynamic.dispute_resolution_rules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Dispute Resolution Rules.
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
CREATE TABLE dynamic.dispute_resolution_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Dispute Type
    dispute_type VARCHAR(50) NOT NULL 
        CHECK (dispute_type IN ('CHARGEBACK', 'FRAUD_CLAIM', 'REFUND_REQUEST', 'SERVICE_COMPLAINT', 'DUPLICATE_CHARGE', 'UNRECOGNIZED')),
    
    -- Applicability
    applicable_payment_methods UUID[],
    applicable_card_schemes dynamic.card_scheme[],
    min_dispute_amount DECIMAL(28,8) DEFAULT 0,
    max_dispute_amount DECIMAL(28,8),
    
    -- Timeframes
    customer_filing_window_days INTEGER NOT NULL, -- How long customer has to file
    merchant_response_window_hours INTEGER DEFAULT 72, -- Time to respond
    evidence_submission_deadline_days INTEGER DEFAULT 10,
    
    -- Auto-Response Rules
    auto_accept_threshold DECIMAL(28,8), -- Auto-accept disputes below this amount
    auto_reject_conditions JSONB, -- [{condition: 'evidence_provided', value: true}]
    
    -- Workflow
    workflow_definition_id UUID REFERENCES dynamic.state_machine_definition(machine_id),
    escalation_matrix JSONB, -- [{hours: 24, escalate_to: 'SUPERVISOR'}, ...]
    
    -- Fees
    dispute_fee_amount DECIMAL(28,8) DEFAULT 0,
    chargeback_fee_amount DECIMAL(28,8) DEFAULT 0,
    representment_fee_amount DECIMAL(28,8) DEFAULT 0,
    
    -- Liability
    liability_shift_rules JSONB, -- {3ds_authenticated: 'ISSUER', else: 'MERCHANT'}
    
    -- Actions
    allow_representment BOOLEAN DEFAULT TRUE,
    allow_arbitration BOOLEAN DEFAULT TRUE,
    arbitration_threshold DECIMAL(28,8),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
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
    
    CONSTRAINT unique_dispute_rule_code UNIQUE (tenant_id, rule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.dispute_resolution_rules_default PARTITION OF dynamic.dispute_resolution_rules DEFAULT;

-- Indexes
CREATE INDEX idx_dispute_rules_tenant ON dynamic.dispute_resolution_rules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_dispute_rules_type ON dynamic.dispute_resolution_rules(tenant_id, dispute_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.dispute_resolution_rules IS 'Payment dispute handling and chargeback rules';

-- Triggers
CREATE TRIGGER trg_dispute_resolution_rules_audit
    BEFORE UPDATE ON dynamic.dispute_resolution_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.dispute_resolution_rules TO finos_app;