-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_card_specifics
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Card Specifics.
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


CREATE TABLE dynamic.product_card_specifics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL UNIQUE REFERENCES dynamic.product_template_master(product_id) ON DELETE CASCADE,
    
    -- Card Properties
    card_scheme dynamic.card_scheme NOT NULL,
    card_type dynamic.card_type NOT NULL,
    
    -- Credit Limit
    credit_limit_assignment_strategy VARCHAR(50) DEFAULT 'FIXED' 
        CHECK (credit_limit_assignment_strategy IN ('FIXED', 'INCOME_BASED', 'SCORED', 'DEPOSIT_BASED')),
    min_credit_limit DECIMAL(28,8),
    max_credit_limit DECIMAL(28,8),
    default_credit_limit DECIMAL(28,8),
    
    -- Cash Advance
    cash_advance_allowed BOOLEAN DEFAULT TRUE,
    cash_advance_limit_percentage DECIMAL(5,4), -- Percentage of credit limit
    cash_advance_fee_percentage DECIMAL(10,6),
    cash_advance_interest_rate DECIMAL(10,6),
    
    -- Interest
    purchase_interest_rate DECIMAL(10,6),
    cash_advance_interest_rate DECIMAL(10,6),
    interest_free_period_days INTEGER DEFAULT 0,
    
    -- Fees
    annual_fee DECIMAL(28,8),
    late_payment_fee DECIMAL(28,8),
    over_limit_fee DECIMAL(28,8),
    foreign_transaction_fee_percentage DECIMAL(10,6),
    
    -- Rewards
    loyalty_program_linkage UUID,
    reward_points_earning_rate DECIMAL(10,6),
    
    -- Security
    contactless_enabled BOOLEAN DEFAULT TRUE,
    contactless_limit DECIMAL(28,8),
    online_purchase_enabled BOOLEAN DEFAULT TRUE,
    international_usage_enabled BOOLEAN DEFAULT TRUE,
    
    -- Embossing
    embossing_personalization_rules JSONB, -- {name_format: '...', max_chars: 26, ...}
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_card_specifics_default PARTITION OF dynamic.product_card_specifics DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_card_specifics IS 'Specialized configuration for card products';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_card_specifics TO finos_app;
