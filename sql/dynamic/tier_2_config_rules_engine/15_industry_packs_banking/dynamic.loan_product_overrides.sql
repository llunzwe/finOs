-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 15 - Industry Packs Banking
-- TABLE: dynamic.loan_product_overrides
-- COMPLIANCE: Basel III/IV
--   - NCA
--   - IFRS 9
--   - FSCA
-- ============================================================================


CREATE TABLE dynamic.loan_product_overrides (

    override_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Product Reference
    product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id),
    
    -- Override Scope
    override_name VARCHAR(200) NOT NULL,
    override_description TEXT,
    override_type VARCHAR(50) NOT NULL 
        CHECK (override_type IN ('RETAIL', 'SME', 'CORPORATE', 'MICROFINANCE', 'MORTGAGE', 'VEHICLE', 'PERSONAL', 'PAYDAY')),
    
    -- Loan Structure Overrides
    min_loan_amount DECIMAL(28,8),
    max_loan_amount DECIMAL(28,8),
    min_term_months INTEGER,
    max_term_months INTEGER,
    
    -- Interest Rate Overrides
    min_interest_rate DECIMAL(10,6),
    max_interest_rate DECIMAL(10,6),
    default_interest_rate DECIMAL(10,6),
    rate_type VARCHAR(20) CHECK (rate_type IN ('FIXED', 'FLOATING', 'HYBRID', 'VARIABLE')),
    
    -- Fee Overrides
    arrangement_fee_percentage DECIMAL(10,6),
    arrangement_fee_minimum DECIMAL(28,8),
    arrangement_fee_maximum DECIMAL(28,8),
    
    -- Security Overrides
    collateral_required BOOLEAN,
    min_collateral_coverage_ratio DECIMAL(5,4),
    acceptable_collateral_types UUID[], -- References collateral_type_master
    
    -- Guarantor Requirements
    guarantor_required BOOLEAN DEFAULT FALSE,
    min_guarantor_income_ratio DECIMAL(5,4),
    max_guarantor_exposure_ratio DECIMAL(5,4),
    
    -- Repayment Overrides
    repayment_frequency_options VARCHAR(20)[], -- WEEKLY, MONTHLY, etc.
    allowed_repayment_days INTEGER[], -- e.g., [1, 15] for 1st and 15th
    
    -- Special Features
    payment_holidays_allowed BOOLEAN DEFAULT FALSE,
    max_payment_holidays_per_year INTEGER DEFAULT 0,
    skip_payment_allowed BOOLEAN DEFAULT FALSE,
    
    -- Prepayment Overrides
    prepayment_allowed BOOLEAN,
    prepayment_notice_days INTEGER,
    prepayment_penalty_structure JSONB, -- {sliding_scale: [{month: 12, percentage: 2}, ...]}
    
    -- Restructuring
    restructuring_allowed BOOLEAN DEFAULT TRUE,
    max_restructurings INTEGER DEFAULT 1,
    min_payments_before_restructure INTEGER,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Priority
    priority INTEGER DEFAULT 0, -- Higher priority wins if multiple apply
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.loan_product_overrides_default PARTITION OF dynamic.loan_product_overrides DEFAULT;

-- Indexes
CREATE INDEX idx_loan_overrides_product ON dynamic.loan_product_overrides(tenant_id, product_id) WHERE is_active = TRUE;
CREATE INDEX idx_loan_overrides_type ON dynamic.loan_product_overrides(tenant_id, override_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.loan_product_overrides IS 'Industry-specific loan product configuration overrides';

-- Triggers
CREATE TRIGGER trg_loan_product_overrides_audit
    BEFORE UPDATE ON dynamic.loan_product_overrides
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.loan_product_overrides TO finos_app;