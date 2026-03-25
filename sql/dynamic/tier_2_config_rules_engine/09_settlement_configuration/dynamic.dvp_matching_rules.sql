-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 09 - Settlement Configuration
-- TABLE: dynamic.dvp_matching_rules
--
-- DESCRIPTION:
--   DvP (Delivery vs Payment) and PvP (Payment vs Payment) matching rules.
--   Configures linkage between delivery and payment instructions.
--   Maps to core.settlement_instructions.dvp_model.
--
-- CORE DEPENDENCY: 009_settlement_and_finality.sql
--
-- COMPLIANCE:
--   - CSDR DvP requirements
--   - PFMI Principle 12 (Exchange-of-value settlement)
--
-- ============================================================================

CREATE TABLE dynamic.dvp_matching_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- DvP/PvP Model
    dvp_model dynamic.dvp_model NOT NULL,
    
    -- Matching Criteria
    match_on_amount BOOLEAN DEFAULT TRUE,
    match_on_currency BOOLEAN DEFAULT TRUE,
    match_on_value_date BOOLEAN DEFAULT TRUE,
    match_on_counterparty BOOLEAN DEFAULT TRUE,
    match_on_reference BOOLEAN DEFAULT FALSE,
    
    -- Tolerance Settings (for PvP especially)
    amount_tolerance_percentage DECIMAL(5,4) DEFAULT 0.0000, -- 0% to 100%
    amount_tolerance_absolute DECIMAL(28,8) DEFAULT 0.00,
    
    -- Timing
    matching_window_hours INTEGER DEFAULT 24,
    auto_match BOOLEAN DEFAULT TRUE,
    manual_approval_required BOOLEAN DEFAULT FALSE,
    
    -- Failure Handling
    on_match_failure VARCHAR(50) DEFAULT 'CANCEL_BOTH', -- CANCEL_BOTH, CANCEL_DELIVERY, CANCEL_PAYMENT, HOLD
    retry_attempts INTEGER DEFAULT 3,
    retry_interval_minutes INTEGER DEFAULT 30,
    
    -- Linked Settlement
    delivery_settlement_method dynamic.settlement_method,
    payment_settlement_method dynamic.settlement_method,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 100, -- Lower number = higher priority
    
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
    
    -- Constraints
    CONSTRAINT unique_dvp_rule_code UNIQUE (tenant_id, rule_code),
    CONSTRAINT chk_dvp_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_amount_tolerance CHECK (amount_tolerance_percentage BETWEEN 0 AND 1)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.dvp_matching_rules_default PARTITION OF dynamic.dvp_matching_rules DEFAULT;

-- Indexes
CREATE INDEX idx_dvp_rules_model ON dynamic.dvp_matching_rules(tenant_id, dvp_model) WHERE is_active = TRUE AND is_current = TRUE;
CREATE INDEX idx_dvp_rules_priority ON dynamic.dvp_matching_rules(tenant_id, priority) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.dvp_matching_rules IS 'DvP/PvP matching rules configuration - links delivery and payment settlement. Tier 2 Low-Code';

-- Trigger
CREATE TRIGGER trg_dvp_rules_audit
    BEFORE UPDATE ON dynamic.dvp_matching_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.dvp_matching_rules TO finos_app;
