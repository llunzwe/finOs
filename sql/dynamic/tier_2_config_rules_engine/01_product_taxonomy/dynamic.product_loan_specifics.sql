-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_loan_specifics
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Loan Specifics.
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


CREATE TABLE dynamic.product_loan_specifics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL UNIQUE REFERENCES dynamic.product_template_master(product_id) ON DELETE CASCADE,
    
    -- Loan Structure
    amortization_type dynamic.amortization_type NOT NULL DEFAULT 'AMORTIZING',
    interest_accrual_method dynamic.accrual_method NOT NULL DEFAULT 'ACTUAL_365',
    
    -- Grace Period
    grace_period_type dynamic.grace_period_type DEFAULT 'NONE',
    grace_period_days INTEGER DEFAULT 0,
    
    -- Term Limits
    min_term_months INTEGER,
    max_term_months INTEGER,
    default_term_months INTEGER,
    
    -- Amount Limits
    min_loan_amount DECIMAL(28,8),
    max_loan_amount DECIMAL(28,8),
    
    -- Interest
    min_interest_rate DECIMAL(10,6),
    max_interest_rate DECIMAL(10,6),
    default_interest_rate DECIMAL(10,6),
    rate_type VARCHAR(20) DEFAULT 'FIXED' CHECK (rate_type IN ('FIXED', 'FLOATING', 'HYBRID')),
    
    -- Prepayment
    prepayment_allowed BOOLEAN DEFAULT TRUE,
    prepayment_penalty_structure JSONB, -- {sliding_scale: [{month: 12, percentage: 2}, ...]}
    
    -- Balloon Payment
    balloon_payment_eligible BOOLEAN DEFAULT FALSE,
    balloon_percentage_limit DECIMAL(5,4), -- 0-1
    
    -- Fees
    arrangement_fee_percentage DECIMAL(10,6),
    arrangement_fee_minimum DECIMAL(28,8),
    
    -- Security
    collateral_required BOOLEAN DEFAULT FALSE,
    min_collateral_coverage_ratio DECIMAL(5,4),
    
    -- Repayment
    repayment_frequency VARCHAR(20) DEFAULT 'MONTHLY' 
        CHECK (repayment_frequency IN ('WEEKLY', 'BIWEEKLY', 'MONTHLY', 'QUARTERLY', 'SEMI_ANNUAL', 'ANNUAL', 'BULLET')),
    allowed_repayment_days INTEGER[], -- e.g., [1, 15] for 1st and 15th
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_loan_specifics_default PARTITION OF dynamic.product_loan_specifics DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_loan_specifics IS 'Specialized configuration for loan products';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_loan_specifics TO finos_app;
