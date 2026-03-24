-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.jit_funding_rules
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.jit_funding_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    rule_name VARCHAR(200) NOT NULL,
    
    -- Applicability
    applies_to VARCHAR(30) NOT NULL 
        CHECK (applies_to IN ('program', 'user', 'card_product')),
    target_id UUID NOT NULL, -- ID of program/user/card product
    
    -- Trigger Conditions
    trigger_conditions JSONB NOT NULL DEFAULT '{}',
    -- Example: {
    --   transaction_amount_min: 0,
    --   transaction_amount_max: 10000,
    --   merchant_categories: ['groceries', 'fuel'],
    --   time_of_day: {start: '06:00', end: '23:00'}
    -- }
    
    -- Funding Configuration
    funding_source_id UUID REFERENCES dynamic.funding_sources(source_id),
    funding_amount_type VARCHAR(20) DEFAULT 'exact' 
        CHECK (funding_amount_type IN ('exact', 'rounded_up', 'fixed_amount')),
    funding_amount_fixed DECIMAL(28,8),
    
    -- Limits
    daily_funding_limit DECIMAL(28,8),
    monthly_funding_limit DECIMAL(28,8),
    per_transaction_max DECIMAL(28,8),
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.jit_funding_rules_default PARTITION OF dynamic.jit_funding_rules DEFAULT;

-- Indexes
CREATE INDEX idx_jit_rules_target ON dynamic.jit_funding_rules(tenant_id, applies_to, target_id);

-- Comments
COMMENT ON TABLE dynamic.jit_funding_rules IS 'Just-In-Time funding rules and triggers';

-- Triggers
CREATE TRIGGER trg_jit_funding_rules_update
    BEFORE UPDATE ON dynamic.jit_funding_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_marqeta_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.jit_funding_rules TO finos_app;