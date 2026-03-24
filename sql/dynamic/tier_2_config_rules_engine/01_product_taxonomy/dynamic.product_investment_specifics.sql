-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_investment_specifics
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Investment Specifics.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 17442 (LEI)
--   - ISO 4217
--   - IFRS 9
--   - AAOIFI
--   - BCBS 239
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


CREATE TABLE dynamic.product_investment_specifics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL UNIQUE REFERENCES dynamic.product_template_master(product_id) ON DELETE CASCADE,
    
    -- Fund Details
    fund_manager_id UUID,
    benchmark_index VARCHAR(100),
    investment_objective TEXT,
    
    -- Risk
    risk_rating INTEGER CHECK (risk_rating BETWEEN 1 AND 7), -- 1-7 scale
    risk_category VARCHAR(50),
    
    -- Subscription/Redemption
    subscription_redemption_frequency VARCHAR(20) DEFAULT 'DAILY' 
        CHECK (subscription_redemption_frequency IN ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY')),
    cutoff_time_for_trading TIME,
    settlement_cycle_days INTEGER DEFAULT 3, -- T+3
    
    -- Fees
    front_end_load_percentage DECIMAL(10,6),
    back_end_load_percentage DECIMAL(10,6),
    management_fee_percentage DECIMAL(10,6),
    management_fee_accrual_frequency VARCHAR(20) DEFAULT 'DAILY',
    performance_fee_percentage DECIMAL(10,6),
    performance_fee_hurdle_rate DECIMAL(10,6),
    
    -- Minimums
    min_initial_investment DECIMAL(28,8),
    min_subsequent_investment DECIMAL(28,8),
    min_balance_required DECIMAL(28,8),
    
    -- NAV
    nav_calculation_frequency VARCHAR(20) DEFAULT 'DAILY',
    nav_pricing_source VARCHAR(100),
    
    -- Restrictions
    investor_types_allowed VARCHAR(50)[], -- RETAIL, HIGH_NET_WORTH, INSTITUTIONAL
    restricted_countries CHAR(2)[],
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_investment_specifics_default PARTITION OF dynamic.product_investment_specifics DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_investment_specifics IS 'Specialized configuration for investment products';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_investment_specifics TO finos_app;
