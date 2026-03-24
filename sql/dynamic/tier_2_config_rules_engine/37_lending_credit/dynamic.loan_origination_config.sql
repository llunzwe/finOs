-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 37 - Lending & Credit
-- TABLE: dynamic.loan_origination_config
--
-- DESCRIPTION:
--   Enterprise-grade loan origination and underwriting configuration.
--   AI/ML scoring, automated approval workflows, decision engines.
--
-- COMPLIANCE: IFRS 9, Basel III/IV, Consumer Protection, Credit Regulations
-- ============================================================================


CREATE TABLE dynamic.loan_origination_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Configuration Identification
    config_name VARCHAR(200) NOT NULL,
    config_type VARCHAR(50) NOT NULL 
        CHECK (config_type IN ('TERM_LOAN', 'REVOLVING_CREDIT', 'OVERDRAFT', 'MORTGAGE', 'BNPL', 'INVOICE_FINANCE', 'SUPPLY_CHAIN_FINANCE')),
    
    -- Product Linkage
    product_id UUID REFERENCES dynamic.product_template_master(product_id),
    
    -- Underwriting Configuration
    underwriting_type VARCHAR(50) DEFAULT 'AUTOMATED' 
        CHECK (underwriting_type IN ('AUTOMATED', 'MANUAL', 'HYBRID')),
    automated_decision_engine VARCHAR(100), -- Engine/model reference
    
    -- AI/ML Scoring
    ai_scoring_enabled BOOLEAN DEFAULT FALSE,
    ai_scoring_model_id VARCHAR(100),
    ml_feature_set TEXT[], -- Features used for scoring
    
    -- Credit Score Requirements
    minimum_credit_score INTEGER,
    maximum_credit_score INTEGER,
    credit_bureau_providers VARCHAR(100)[], -- ['TransUnion', 'Experian', 'Compuscan']
    
    -- Income & Affordability
    minimum_income_requirement DECIMAL(28,8),
    income_verification_method VARCHAR(50), -- 'BANK_STATEMENT', 'PAYSLIP', 'API'
    debt_to_income_ratio_limit DECIMAL(5,4), -- e.g., 0.40 for 40%
    
    -- Loan Parameters
    minimum_loan_amount DECIMAL(28,8) NOT NULL,
    maximum_loan_amount DECIMAL(28,8) NOT NULL,
    loan_amount_multiplier_of_income DECIMAL(5,2), -- e.g., 3x annual income
    
    -- Term Options
    minimum_term_months INTEGER NOT NULL,
    maximum_term_months INTEGER NOT NULL,
    allowed_terms_months INTEGER[], -- e.g., [12, 24, 36, 48, 60]
    
    -- Interest Rate Configuration
    interest_rate_type VARCHAR(20) DEFAULT 'FIXED' 
        CHECK (interest_rate_type IN ('FIXED', 'VARIABLE', 'HYBRID')),
    base_interest_rate DECIMAL(10,6),
    rate_floor DECIMAL(10,6),
    rate_ceiling DECIMAL(10,6),
    risk_based_pricing_enabled BOOLEAN DEFAULT TRUE,
    
    -- Fees
    arrangement_fee_percentage DECIMAL(5,4),
    arrangement_fee_minimum DECIMAL(28,8),
    early_repayment_fee_percentage DECIMAL(5,4),
    
    -- Collateral Requirements
    collateral_required BOOLEAN DEFAULT FALSE,
    collateral_types VARCHAR(50)[], -- ['PROPERTY', 'VEHICLE', 'CASH']
    minimum_ltv_ratio DECIMAL(5,4), -- Loan to Value
    maximum_ltv_ratio DECIMAL(5,4),
    
    -- Guarantor Requirements
    guarantor_required BOOLEAN DEFAULT FALSE,
    minimum_guarantor_income DECIMAL(28,8),
    
    -- Approval Workflow
    auto_approval_limit DECIMAL(28,8), -- Max amount for auto-approval
    manual_review_threshold_score INTEGER,
    escalation_rules JSONB DEFAULT '{}',
    
    -- Documentation
    required_documents TEXT[],
    digital_signature_enabled BOOLEAN DEFAULT TRUE,
    
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

CREATE TABLE dynamic.loan_origination_config_default PARTITION OF dynamic.loan_origination_config DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.loan_origination_config IS 'Loan origination and underwriting configuration - AI/ML scoring, automated approval. Tier 2 - Lending & Credit.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.loan_origination_config TO finos_app;
