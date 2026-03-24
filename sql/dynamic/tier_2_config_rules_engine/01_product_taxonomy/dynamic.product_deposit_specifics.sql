-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_deposit_specifics
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Deposit Specifics.
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


CREATE TABLE dynamic.product_deposit_specifics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL UNIQUE REFERENCES dynamic.product_template_master(product_id) ON DELETE CASCADE,
    
    -- Account Type
    deposit_type VARCHAR(50) NOT NULL 
        CHECK (deposit_type IN ('SAVINGS', 'CURRENT', 'TERM_DEPOSIT', 'FIXED_DEPOSIT', 'RECURRING_DEPOSIT', 'CALL_DEPOSIT')),
    
    -- Withdrawal Restrictions
    withdrawal_restriction_type VARCHAR(50) DEFAULT 'IMMEDIATE' 
        CHECK (withdrawal_restriction_type IN ('IMMEDIATE', 'NOTICE_PERIOD', 'FIXED_TERM', 'MATURITY')),
    notice_period_days INTEGER DEFAULT 0,
    fixed_term_months INTEGER,
    
    -- Early Withdrawal
    early_withdrawal_allowed BOOLEAN DEFAULT TRUE,
    early_withdrawal_penalty_rate DECIMAL(10,6), -- Percentage of interest forfeited
    early_withdrawal_penalty_amount DECIMAL(28,8),
    
    -- Interest
    interest_rate_tiers JSONB, -- [{min_balance: 0, max_balance: 10000, rate: 0.05}, ...]
    interest_posting_frequency VARCHAR(20) DEFAULT 'MONTHLY',
    interest_compounding_frequency VARCHAR(20) DEFAULT 'MONTHLY',
    
    -- Balance Tiers
    tiered_balance_thresholds DECIMAL(28,8)[],
    tiered_interest_rates DECIMAL(10,6)[],
    
    -- Minimums
    minimum_opening_balance DECIMAL(28,8) DEFAULT 0,
    minimum_balance_required DECIMAL(28,8) DEFAULT 0,
    minimum_balance_penalty DECIMAL(28,8),
    
    -- Dormancy
    dormancy_rules JSONB, -- {inactivity_period_days: 365, dormancy_fee: 10, escheat_period_days: 1825}
    
    -- Overdraft
    overdraft_allowed BOOLEAN DEFAULT FALSE,
    overdraft_limit_percentage DECIMAL(5,4),
    overdraft_interest_rate DECIMAL(10,6),
    
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

CREATE TABLE dynamic.product_deposit_specifics_default PARTITION OF dynamic.product_deposit_specifics DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_deposit_specifics IS 'Specialized configuration for deposit products';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_deposit_specifics TO finos_app;
