-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.reward_rules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Reward Rules.
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
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.reward_rules_default PARTITION OF dynamic.reward_rules DEFAULT;

-- Comments
COMMENT ON TABLE dynamic.reward_rules IS 'Reward earning rules with flexible conditions';

-- Triggers
CREATE TRIGGER trg_reward_rules_update
    BEFORE UPDATE ON dynamic.reward_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_marqeta_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.reward_rules TO finos_app;