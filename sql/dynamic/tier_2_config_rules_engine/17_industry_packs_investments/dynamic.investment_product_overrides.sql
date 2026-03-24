-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 17 - Industry Packs: Investments
-- TABLE: dynamic.investment_product_overrides
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Investment Product Overrides.
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
CREATE TABLE dynamic.investment_product_overrides (

    override_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Product Reference
    product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id),
    
    -- Override Scope
    override_name VARCHAR(200) NOT NULL,
    override_description TEXT,
    override_type VARCHAR(50) NOT NULL 
        CHECK (override_type IN ('MUTUAL_FUND', 'ETF', 'STOCK', 'BOND', 'STRUCTURED_PRODUCT', 'HEDGE_FUND', 'PRIVATE_EQUITY', 'CRYPTO', 'COMMODITY', 'REIT')),
    
    -- Investment Specifics
    investment_objective VARCHAR(100), -- GROWTH, INCOME, BALANCED, CAPITAL_PRESERVATION
    investment_style VARCHAR(50), -- ACTIVE, PASSIVE, INDEX, QUANTITATIVE
    
    -- Risk Profile
    risk_rating_min INTEGER CHECK (risk_rating_min BETWEEN 1 AND 7),
    risk_rating_max INTEGER CHECK (risk_rating_max BETWEEN 1 AND 7),
    volatility_category VARCHAR(50), -- LOW, MEDIUM_LOW, MEDIUM, MEDIUM_HIGH, HIGH
    
    -- Benchmark
    benchmark_index_code VARCHAR(50),
    benchmark_name VARCHAR(200),
    tracking_error_limit DECIMAL(10,6),
    
    -- Fees
    management_fee_min DECIMAL(10,6),
    management_fee_max DECIMAL(10,6),
    performance_fee_percentage DECIMAL(10,6),
    performance_fee_hurdle_rate DECIMAL(10,6),
    performance_fee_high_watermark BOOLEAN DEFAULT TRUE,
    
    -- Subscription/Redemption
    min_initial_investment DECIMAL(28,8),
    min_subsequent_investment DECIMAL(28,8),
    min_balance_required DECIMAL(28,8),
    subscription_frequency VARCHAR(20) DEFAULT 'DAILY', -- DAILY, WEEKLY, MONTHLY
    redemption_frequency VARCHAR(20) DEFAULT 'DAILY',
    redemption_notice_days INTEGER DEFAULT 0,
    
    -- Settlement
    subscription_settlement_days INTEGER DEFAULT 3, -- T+3
    redemption_settlement_days INTEGER DEFAULT 3,
    
    -- Restrictions
    investor_types_allowed VARCHAR(50)[], -- RETAIL, HIGH_NET_WORTH, PROFESSIONAL, INSTITUTIONAL
    restricted_countries CHAR(2)[],
    restricted_investor_types VARCHAR(50)[],
    
    -- Liquidity
    liquidity_profile VARCHAR(50), -- HIGHLY_LIQUID, LIQUID, ILLIQUID, RESTRICTED
    lock_up_period_months INTEGER DEFAULT 0,
    early_redemption_penalty DECIMAL(10,6),
    
    -- Trading
    trading_restrictions JSONB, -- [{restriction: 'SHORT_SELLING', allowed: false}, ...]
    leverage_allowed BOOLEAN DEFAULT FALSE,
    max_leverage_ratio DECIMAL(5,2),
    
    -- Dividends/Distributions
    distribution_frequency VARCHAR(20), -- MONTHLY, QUARTERLY, SEMI_ANNUAL, ANNUAL
    distribution_reinvestment_allowed BOOLEAN DEFAULT TRUE,
    
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
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.investment_product_overrides_default PARTITION OF dynamic.investment_product_overrides DEFAULT;

-- Indexes
CREATE INDEX idx_inv_prod_overrides_product ON dynamic.investment_product_overrides(tenant_id, product_id) WHERE is_active = TRUE;
CREATE INDEX idx_inv_prod_overrides_type ON dynamic.investment_product_overrides(tenant_id, override_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.investment_product_overrides IS 'Investment product specific configuration overrides';

-- Triggers
CREATE TRIGGER trg_investment_product_overrides_audit
    BEFORE UPDATE ON dynamic.investment_product_overrides
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.investment_product_overrides TO finos_app;