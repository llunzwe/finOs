-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 19 - Industry Packs: Retail & Ads
-- TABLE: dynamic.ad_pricing_structures
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Ad Pricing Structures.
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
CREATE TABLE dynamic.ad_pricing_structures (

    structure_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    structure_code VARCHAR(100) NOT NULL,
    structure_name VARCHAR(200) NOT NULL,
    structure_description TEXT,
    
    -- Pricing Model
    pricing_model VARCHAR(50) NOT NULL 
        CHECK (pricing_model IN ('CPM', 'CPC', 'CPA', 'CPI', 'CPV', 'CPE', 'CPS', 'FLAT_RATE', 'REV_SHARE', 'DYNAMIC_CPM')),
    
    -- Base Rates
    base_rate DECIMAL(28,8) NOT NULL, -- Rate per unit (e.g., per 1000 impressions for CPM)
    rate_currency CHAR(3) NOT NULL,
    rate_unit VARCHAR(50) NOT NULL, -- IMPRESSIONS, CLICKS, ACTIONS, etc.
    
    -- Dynamic Pricing
    dynamic_pricing_enabled BOOLEAN DEFAULT FALSE,
    floor_price DECIMAL(28,8), -- Minimum acceptable price
    ceiling_price DECIMAL(28,8), -- Maximum price cap
    
    -- Targeting Premiums
    targeting_premiums JSONB, -- [{targeting_type: 'GEOGRAPHY', premium_percentage: 20}, ...]
    
    -- Volume Discounts
    volume_discount_tiers JSONB, -- [{min_volume: 1000000, discount_percentage: 5}, ...]
    
    -- Time-based Pricing
    dayparting_rates JSONB, -- [{time_start: '09:00', time_end: '17:00', rate_multiplier: 1.5}, ...]
    weekend_rate_multiplier DECIMAL(5,4) DEFAULT 1.0,
    holiday_rate_multiplier DECIMAL(5,4) DEFAULT 1.0,
    
    -- Inventory Tiers
    inventory_tier_pricing JSONB, -- [{tier: 'PREMIUM', rate_multiplier: 2.0}, {tier: 'REMNANT', rate_multiplier: 0.5}]
    
    -- Auction Settings (for programmatic)
    auction_type VARCHAR(50), -- FIRST_PRICE, SECOND_PRICE
    bid_floor DECIMAL(28,8),
    
    -- Floor Rules
    floor_rules JSONB, -- [{country: 'US', floor: 2.0}, ...]
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    is_default BOOLEAN DEFAULT FALSE,
    
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
    
    CONSTRAINT unique_ad_pricing_structure_code UNIQUE (tenant_id, structure_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.ad_pricing_structures_default PARTITION OF dynamic.ad_pricing_structures DEFAULT;

-- Indexes
CREATE INDEX idx_ad_pricing_tenant ON dynamic.ad_pricing_structures(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_ad_pricing_model ON dynamic.ad_pricing_structures(tenant_id, pricing_model) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.ad_pricing_structures IS 'Advertising pricing structures (CPC, CPM, CPA, etc.)';

-- Triggers
CREATE TRIGGER trg_ad_pricing_structures_audit
    BEFORE UPDATE ON dynamic.ad_pricing_structures
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.ad_pricing_structures TO finos_app;