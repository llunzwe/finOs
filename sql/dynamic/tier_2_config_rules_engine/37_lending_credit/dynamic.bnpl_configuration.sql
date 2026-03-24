-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 37 - Lending & Credit
-- TABLE: dynamic.bnpl_configuration
--
-- DESCRIPTION:
--   Enterprise-grade Buy Now Pay Later (BNPL) configuration.
--   Consumer and B2B BNPL, merchant integration, checkout financing.
--
-- COMPLIANCE: Consumer Credit Regulations, GDPR, PCI DSS
-- ============================================================================


CREATE TABLE dynamic.bnpl_configuration (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Configuration
    config_name VARCHAR(200) NOT NULL,
    bnpl_type VARCHAR(50) NOT NULL 
        CHECK (bnpl_type IN ('PAY_IN_4', 'PAY_IN_3', 'CUSTOM_INSTALLMENTS', 'B2B_NET_TERMS', 'FLEET_CARD')),
    
    -- Target Market
    target_segment VARCHAR(50) DEFAULT 'CONSUMER' 
        CHECK (target_segment IN ('CONSUMER', 'SME', 'CORPORATE')),
    
    -- Transaction Limits
    minimum_transaction_amount DECIMAL(28,8) DEFAULT 10.00,
    maximum_transaction_amount DECIMAL(28,8) DEFAULT 1000.00,
    
    -- Installment Structure
    number_of_installments INTEGER DEFAULT 4,
    installment_frequency VARCHAR(20) DEFAULT 'BIWEEKLY' 
        CHECK (installment_frequency IN ('WEEKLY', 'BIWEEKLY', 'MONTHLY')),
    first_payment_upfront BOOLEAN DEFAULT TRUE,
    first_payment_percentage DECIMAL(5,4) DEFAULT 0.25, -- 25%
    
    -- Fees & Interest
    merchant_fee_percentage DECIMAL(5,4) DEFAULT 0.06, -- 6% merchant fee
    customer_interest_rate DECIMAL(10,6) DEFAULT 0, -- 0% for standard BNPL
    late_fee_amount DECIMAL(28,8),
    late_fee_percentage DECIMAL(5,4),
    late_fee_cap DECIMAL(28,8),
    
    -- Credit Check
    soft_credit_check_only BOOLEAN DEFAULT TRUE,
    minimum_credit_score INTEGER,
    maximum_debt_to_income DECIMAL(5,4),
    
    -- Merchant Integration
    integration_type VARCHAR(50) DEFAULT 'EMBEDDED' 
        CHECK (integration_type IN ('EMBEDDED', 'REDIRECT', 'POPUP')),
    checkout_flow VARCHAR(50) DEFAULT 'SEAMLESS',
    
    -- Repayment
    auto_debit_enabled BOOLEAN DEFAULT TRUE,
    supported_payment_methods VARCHAR(50)[] DEFAULT ARRAY['DEBIT_CARD', 'BANK_ACCOUNT'],
    
    -- Collections
    grace_period_days INTEGER DEFAULT 3,
    collections_trigger_days INTEGER DEFAULT 7,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.bnpl_configuration_default PARTITION OF dynamic.bnpl_configuration DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.bnpl_configuration IS 'Buy Now Pay Later configuration - consumer and B2B BNPL, checkout financing. Tier 2 - Lending & Credit.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.bnpl_configuration TO finos_app;
