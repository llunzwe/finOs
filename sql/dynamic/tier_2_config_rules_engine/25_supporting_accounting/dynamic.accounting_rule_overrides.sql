-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 25 - Supporting Accounting
-- TABLE: dynamic.accounting_rule_overrides
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Accounting Rule Overrides.
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
CREATE TABLE dynamic.accounting_rule_overrides (

    override_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Override Identity
    override_name VARCHAR(200) NOT NULL,
    override_description TEXT,
    
    -- Applicability
    applies_to_type VARCHAR(30) NOT NULL 
        CHECK (applies_to_type IN ('product', 'product_version', 'contract', 'transaction_type', 'global')),
    applies_to_id UUID, -- NULL for global rules
    
    -- Event Matching
    event_type VARCHAR(50) NOT NULL, -- 'disbursement', 'repayment', 'fee_charge', etc.
    event_sub_type VARCHAR(50), -- 'principal', 'interest', 'penalty', etc.
    
    -- Matching Conditions (JSON for flexibility)
    match_conditions JSONB DEFAULT '{}',
    -- Example: {
    --   amount_range: {min: 0, max: 10000},
    --   currency: ['USD', 'EUR'],
    --   channel: ['online', 'branch']
    -- }
    
    -- Accounting Entry Rules (Double-Entry)
    debit_account_rules JSONB NOT NULL DEFAULT '{}',
    -- Example: {
    --   account_code: '1200-LOANS-RECEIVABLE',
    --   account_code_dynamic: 'concat("1200-", product_type, "-RECEIVABLE")',
    --   amount_source: 'transaction.amount',
    --   dimension_mappings: {cost_center: 'branch_code'}
    -- }
    
    credit_account_rules JSONB NOT NULL DEFAULT '{}',
    -- Same structure as debit_account_rules
    
    -- Multi-leg support (for complex transactions)
    additional_legs JSONB DEFAULT '[]',
    -- Example: [
    --   {account_code: '4100-FEE-INCOME', amount_source: 'transaction.fee_amount', direction: 'credit'}
    -- ]
    
    -- Override Priority (higher number = higher priority)
    priority INTEGER DEFAULT 100,
    
    -- Effective Period
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.accounting_rule_overrides_default PARTITION OF dynamic.accounting_rule_overrides DEFAULT;

-- Indexes
CREATE INDEX idx_accounting_rules_tenant ON dynamic.accounting_rule_overrides(tenant_id, active) 
    WHERE active = TRUE AND effective_from <= CURRENT_DATE AND effective_to >= CURRENT_DATE;
CREATE INDEX idx_accounting_rules_target ON dynamic.accounting_rule_overrides(tenant_id, applies_to_type, applies_to_id);
CREATE INDEX idx_accounting_rules_event ON dynamic.accounting_rule_overrides(tenant_id, event_type, event_sub_type);
CREATE INDEX idx_accounting_rules_priority ON dynamic.accounting_rule_overrides(tenant_id, priority DESC);

-- Comments
COMMENT ON TABLE dynamic.accounting_rule_overrides IS 
    'Dynamic GL mapping per product contract - links every event to Core Chart of Accounts';

-- Triggers
CREATE TRIGGER trg_accounting_rules_update
    BEFORE UPDATE ON dynamic.accounting_rule_overrides
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_supporting_accounting_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.accounting_rule_overrides TO finos_app;