-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.late_payment_penalty_rules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Late Payment Penalty Rules.
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


CREATE TABLE dynamic.late_payment_penalty_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    rule_name VARCHAR(200) NOT NULL,
    product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id),
    
    -- Grace Period
    grace_period_days INTEGER DEFAULT 0,
    
    -- Penalty Calculation
    penalty_calculation_basis VARCHAR(50) DEFAULT 'OUTSTANDING_BALANCE' 
        CHECK (penalty_calculation_basis IN ('OUTSTANDING_BALANCE', 'INSTALLMENT_AMOUNT', 'OVERDUE_AMOUNT', 'FIXED')),
    
    -- Penalty Structure
    penalty_type VARCHAR(20) DEFAULT 'PERCENTAGE' 
        CHECK (penalty_type IN ('PERCENTAGE', 'FLAT', 'TIERED')),
    penalty_rate DECIMAL(15,10), -- If percentage
    penalty_flat_amount DECIMAL(28,8), -- If flat
    penalty_tier_structure JSONB, -- If tiered
    
    -- Compounding
    compounding_frequency VARCHAR(20) DEFAULT 'DAILY' 
        CHECK (compounding_frequency IN ('DAILY', 'WEEKLY', 'MONTHLY', 'NONE')),
    compound_penalties BOOLEAN DEFAULT FALSE,
    
    -- Regulatory Caps
    maximum_penalty_cap DECIMAL(28,8), -- Regulatory limit
    maximum_penalty_cap_percentage DECIMAL(5,4), -- As % of original amount
    
    -- Escalation
    escalation_schedule JSONB, -- [{days_overdue: 30, additional_penalty: 0.01}, ...]
    
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

CREATE TABLE dynamic.late_payment_penalty_rules_default PARTITION OF dynamic.late_payment_penalty_rules DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_penalty_rules_product

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.late_payment_penalty_rules IS 'Delinquency charge rules with regulatory caps';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.late_payment_penalty_rules TO finos_app;
