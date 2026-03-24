-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 35 - Accounts & Deposits
-- TABLE: dynamic.interest_calculation_rules
--
-- DESCRIPTION:
--   Enterprise-grade interest and profit rate calculation engines.
--   Tiered rates, compounding, Sharia-compliant profit calculations.
--
-- COMPLIANCE: IFRS, AAOIFI, Banking Regulations
-- ============================================================================


CREATE TABLE dynamic.interest_calculation_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    
    -- Calculation Type
    calculation_type VARCHAR(50) NOT NULL 
        CHECK (calculation_type IN ('SIMPLE', 'COMPOUND', 'TIERED', 'ISLAMIC_WADIAH', 'ISLAMIC_MUDARABAH', 'ISLAMIC_MURABAHA')),
    
    -- Applicability
    applicable_product_types VARCHAR(50)[], -- ['SAVINGS', 'CHECKING', 'FIXED_DEPOSIT']
    applicable_currencies CHAR(3)[],
    customer_segments VARCHAR(50)[], -- ['RETAIL', 'PREMIUM', 'SME', 'CORPORATE']
    
    -- Interest/Profit Rate Structure
    base_rate DECIMAL(10,6) NOT NULL, -- Annual rate as decimal (e.g., 0.05 for 5%)
    rate_type VARCHAR(20) DEFAULT 'FIXED' 
        CHECK (rate_type IN ('FIXED', 'FLOATING', 'HYBRID')),
    floating_rate_index_id UUID REFERENCES dynamic.floating_rate_index(index_id),
    floating_rate_spread DECIMAL(10,6) DEFAULT 0,
    
    -- Tiered Rates Configuration
    tiered_rates JSONB DEFAULT '[]', -- [{"min_balance": 0, "max_balance": 10000, "rate": 0.01}, ...]
    
    -- Calculation Parameters
    calculation_frequency VARCHAR(20) DEFAULT 'DAILY' 
        CHECK (calculation_frequency IN ('DAILY', 'MONTHLY', 'QUARTERLY', 'ANNUALLY')),
    compounding_frequency VARCHAR(20) DEFAULT 'MONTHLY' 
        CHECK (compounding_frequency IN ('NONE', 'DAILY', 'MONTHLY', 'QUARTERLY', 'ANNUALLY')),
    day_count_convention VARCHAR(20) DEFAULT 'ACTUAL_365' 
        CHECK (day_count_convention IN ('ACTUAL_360', 'ACTUAL_365', 'ACTUAL_ACTUAL', '30_360')),
    
    -- Balance Considerations
    minimum_balance_for_interest DECIMAL(28,8) DEFAULT 0,
    use_average_balance BOOLEAN DEFAULT FALSE,
    use_minimum_balance BOOLEAN DEFAULT FALSE,
    
    -- Islamic Finance Specific
    profit_sharing_ratio DECIMAL(5,4), -- For Mudarabah (customer share)
    wadiah_bonus_rate DECIMAL(10,6), -- For Wadiah accounts
    
    -- Tax Treatment
    withholding_tax_rate DECIMAL(5,4) DEFAULT 0,
    tax_exempt_for_small_savers BOOLEAN DEFAULT FALSE,
    tax_exemption_limit DECIMAL(28,8),
    
    -- Crediting Rules
    interest_crediting_frequency VARCHAR(20) DEFAULT 'MONTHLY' 
        CHECK (interest_crediting_frequency IN ('MONTHLY', 'QUARTERLY', 'ANNUALLY', 'AT_MATURITY')),
    interest_crediting_account_type VARCHAR(50) DEFAULT 'SAME_ACCOUNT' 
        CHECK (interest_crediting_account_type IN ('SAME_ACCOUNT', 'LINKED_ACCOUNT', 'EXTERNAL_ACCOUNT')),
    
    -- Status
    rule_status VARCHAR(20) DEFAULT 'ACTIVE',
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_rule_code UNIQUE (tenant_id, rule_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.interest_calculation_rules_default PARTITION OF dynamic.interest_calculation_rules DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.interest_calculation_rules IS 'Interest and profit rate calculation rules - tiered, compounded, Sharia-compliant. Tier 2 - Accounts & Deposits.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.interest_calculation_rules TO finos_app;
