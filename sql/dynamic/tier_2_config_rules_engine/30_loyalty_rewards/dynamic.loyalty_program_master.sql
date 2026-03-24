-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 30 - Loyalty & Rewards Engine
-- TABLE: dynamic.loyalty_program_master
--
-- DESCRIPTION:
--   Enterprise-grade loyalty and rewards program configuration.
--   Points, cashback, tiered benefits, coalition programs.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- COMPLIANCE: GDPR, Consumer Protection, Financial Regulations
-- ============================================================================


CREATE TABLE dynamic.loyalty_program_master (
    program_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Program Identity
    program_code VARCHAR(100) NOT NULL,
    program_name VARCHAR(200) NOT NULL,
    program_description TEXT,
    program_type VARCHAR(50) NOT NULL 
        CHECK (program_type IN ('POINTS', 'CASHBACK', 'TIERED', 'COALITION', 'HYBRID', 'GAMIFIED')),
    
    -- Currency & Valuation
    points_currency_name VARCHAR(50), -- e.g., "Reward Points", "Stars"
    points_currency_code VARCHAR(20), -- e.g., "PTS", "CASH"
    point_value_base_currency DECIMAL(20,10), -- Value per point in base currency
    
    -- Earning Rules
    earn_calculation_method TEXT NOT NULL, -- SQL formula or rule reference
    base_earn_rate DECIMAL(10,6) DEFAULT 1.0, -- Points per unit spend
    minimum_earn_amount DECIMAL(28,8) DEFAULT 0,
    earn_rounding_method VARCHAR(20) DEFAULT 'DOWN' 
        CHECK (earn_rounding_method IN ('UP', 'DOWN', 'NEAREST')),
    
    -- Multipliers
    category_multipliers JSONB DEFAULT '{}', -- {"GROCERIES": 2.0, "FUEL": 3.0}
    tier_multipliers JSONB DEFAULT '{}', -- {"SILVER": 1.0, "GOLD": 1.5}
    channel_multipliers JSONB DEFAULT '{}', -- {"APP": 1.2, "IN_STORE": 1.0}
    
    -- Tier Configuration
    tier_program_enabled BOOLEAN DEFAULT FALSE,
    tier_names VARCHAR(50)[], -- ['BRONZE', 'SILVER', 'GOLD', 'PLATINUM']
    tier_thresholds INTEGER[], -- Points required for each tier
    tier_benefits JSONB DEFAULT '{}',
    tier_qualification_period_months INTEGER DEFAULT 12,
    
    -- Expiration
    points_expiry_enabled BOOLEAN DEFAULT TRUE,
    points_expiry_months INTEGER DEFAULT 36,
    expiry_extension_on_activity BOOLEAN DEFAULT TRUE,
    
    -- Redemption
    redemption_minimum_points INTEGER DEFAULT 100,
    redemption_options VARCHAR(50)[], -- ['STATEMENT_CREDIT', 'MERCHANT_VOUCHER', 'CASH']
    redemption_value_rate DECIMAL(10,6), -- Points to currency conversion
    
    -- Coalition Partners
    coalition_partners UUID[], -- Partner tenant IDs
    cross_redemption_allowed BOOLEAN DEFAULT FALSE,
    
    -- Status
    program_status VARCHAR(20) DEFAULT 'DRAFT' 
        CHECK (program_status IN ('DRAFT', 'ACTIVE', 'PAUSED', 'ENDED')),
    launch_date DATE,
    end_date DATE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_program_code_per_tenant UNIQUE (tenant_id, program_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.loyalty_program_master_default PARTITION OF dynamic.loyalty_program_master DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_loyalty_program_tenant ON dynamic.loyalty_program_master(tenant_id);
CREATE INDEX idx_loyalty_program_type ON dynamic.loyalty_program_master(tenant_id, program_type);
CREATE INDEX idx_loyalty_program_status ON dynamic.loyalty_program_master(tenant_id, program_status);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.loyalty_program_master IS 'Loyalty and rewards program configuration - points, cashback, tiered benefits. Tier 2 - Loyalty & Rewards Engine.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.loyalty_program_master TO finos_app;
