-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.reward_rules
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.reward_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    rule_name VARCHAR(200) NOT NULL,
    
    -- Applicability
    applies_to VARCHAR(30) NOT NULL,
    target_id UUID NOT NULL,
    
    -- Earning Rules
    earning_type VARCHAR(30) NOT NULL 
        CHECK (earning_type IN ('points', 'cashback', 'miles', 'crypto')),
    earning_rate DECIMAL(10,6) NOT NULL, -- Points per currency unit or percentage
    
    -- Conditions
    conditions_jsonb JSONB DEFAULT '{}',
    -- Example: {
    --   merchant_categories: ['5411'],
    --   transaction_types: ['pos', 'online'],
    --   min_transaction_amount: 10
    -- }
    
    -- Multipliers
    multipliers_jsonb JSONB DEFAULT '{}',
    -- Example: {
    --   weekend: 2.0,
    --   partner_merchants: 3.0
    -- }
    
    -- Caps
    daily_cap_points INTEGER,
    monthly_cap_points INTEGER,
    
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.reward_rules_default PARTITION OF dynamic.reward_rules DEFAULT;

-- Comments
COMMENT ON TABLE dynamic.reward_rules IS 'Reward earning rules with flexible conditions';

-- Triggers
CREATE TRIGGER trg_reward_rules_update
    BEFORE UPDATE ON dynamic.reward_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_marqeta_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.reward_rules TO finos_app;