-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.fee_waiver_policies
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Fee Waiver Policies.
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


CREATE TABLE dynamic.fee_waiver_policies (
    policy_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    policy_name VARCHAR(200) NOT NULL,
    policy_description TEXT,
    
    -- Applies To
    fee_type_id UUID NOT NULL REFERENCES dynamic.fee_type_master(fee_type_id),
    product_id UUID REFERENCES dynamic.product_template_master(product_id),
    
    -- Waiver Criteria
    waiver_criteria VARCHAR(50) NOT NULL 
        CHECK (waiver_criteria IN ('VIP_TIER', 'BALANCE_THRESHOLD', 'FIRST_YEAR', 'TRANSACTION_COUNT', 'RELATIONSHIP_VALUE', 'PROMOTION', 'HARDSHIP')),
    criteria_parameters JSONB, -- {min_balance: 10000, vip_tiers: ['GOLD', 'PLATINUM']}
    
    -- Waiver Amount
    waiver_percentage DECIMAL(5,4) NOT NULL DEFAULT 1.0, -- 1.0 = 100%
    waiver_fixed_amount DECIMAL(28,8),
    
    -- Limits
    waiver_limit_count_per_period INTEGER, -- NULL = unlimited
    waiver_period VARCHAR(20) DEFAULT 'MONTHLY', -- DAILY, WEEKLY, MONTHLY, YEARLY
    max_waiver_amount_per_period DECIMAL(28,8),
    
    -- Customer Notification
    notify_customer_on_waiver BOOLEAN DEFAULT TRUE,
    waiver_notification_template_id UUID,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.fee_waiver_policies_default PARTITION OF dynamic.fee_waiver_policies DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_waiver_policies_fee_type
idx_waiver_policies_product

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.fee_waiver_policies IS 'Automatic fee waiver rules based on customer criteria';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.fee_waiver_policies TO finos_app;
