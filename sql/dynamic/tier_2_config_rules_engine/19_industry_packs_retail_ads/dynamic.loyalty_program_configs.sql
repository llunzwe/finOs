-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 19 - Industry Packs Retail Ads
-- TABLE: dynamic.loyalty_program_configs
-- COMPLIANCE: IFRS 15
--   - CPA
--   - ASA
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.loyalty_program_configs (

    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    program_code VARCHAR(100) NOT NULL,
    program_name VARCHAR(200) NOT NULL,
    program_description TEXT,
    
    -- Program Type
    program_type VARCHAR(50) NOT NULL 
        CHECK (program_type IN ('POINTS', 'CASHBACK', 'TIERED', 'COALITION', 'HYBRID', 'VIP', 'SUBSCRIPTION')),
    
    -- Earning Rules
    earning_rules JSONB NOT NULL, -- [{action: 'PURCHASE', points_per_currency: 1, minimum_spend: 0}, ...]
    bonus_events JSONB, -- [{event: 'BIRTHDAY', multiplier: 2}, ...]
    
    -- Points Configuration
    point_name VARCHAR(50) DEFAULT 'Points',
    point_value_currency CHAR(3), -- Value per point
    point_value_amount DECIMAL(28,8),
    points_expiry_months INTEGER,
    
    -- Tiers (if tiered)
    tier_structure JSONB, -- [{name: 'Silver', minimum_points: 0, benefits: [...]}, ...]
    tier_qualification_period_months INTEGER,
    
    -- Redemption
    redemption_rules JSONB, -- [{type: 'DISCOUNT', points_required: 100, value: 1}, ...]
    minimum_redemption_points INTEGER DEFAULT 0,
    redemption_restrictions JSONB,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    enrollment_required BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_loyalty_program_code UNIQUE (tenant_id, program_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.loyalty_program_configs_default PARTITION OF dynamic.loyalty_program_configs DEFAULT;

-- Indexes
CREATE INDEX idx_loyalty_programs_tenant ON dynamic.loyalty_program_configs(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_loyalty_programs_type ON dynamic.loyalty_program_configs(tenant_id, program_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.loyalty_program_configs IS 'Customer loyalty program configurations';

-- Triggers
CREATE TRIGGER trg_loyalty_program_configs_audit
    BEFORE UPDATE ON dynamic.loyalty_program_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.loyalty_program_configs TO finos_app;