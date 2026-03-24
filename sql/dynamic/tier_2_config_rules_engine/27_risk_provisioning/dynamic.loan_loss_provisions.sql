-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 27 - Risk Provisioning Engine
-- TABLE: dynamic.loan_loss_provisions
--
-- DESCRIPTION:
--   Enterprise-grade loan loss provision calculations and history.
--   Tracks ECL provisions per loan/account with stage transitions.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- COMPLIANCE: IFRS 9, Basel III/IV, EBA Guidelines
-- ============================================================================


CREATE TABLE dynamic.loan_loss_provisions (
    provision_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Reference
    account_id UUID NOT NULL REFERENCES core.accounts(id),
    loan_id UUID, -- If separate from account
    customer_id UUID REFERENCES core.customers(id),
    
    -- ECL Model Reference
    ecl_model_id UUID REFERENCES dynamic.ecl_calculation_engine(model_id),
    
    -- IFRS 9 Stage
    current_stage INTEGER NOT NULL CHECK (current_stage IN (1, 2, 3)),
    previous_stage INTEGER CHECK (previous_stage IN (1, 2, 3)),
    stage_transition_date DATE,
    stage_transition_reason TEXT,
    
    -- ECL Components
    probability_of_default DECIMAL(10,6), -- PD
    loss_given_default DECIMAL(10,6), -- LGD
    exposure_at_default DECIMAL(28,8), -- EAD
    expected_credit_loss DECIMAL(28,8), -- ECL = PD * LGD * EAD
    
    -- Time Dimensions
    reporting_date DATE NOT NULL,
    remaining_maturity_months INTEGER,
    days_past_due INTEGER DEFAULT 0,
    
    -- Provision Details
    provision_amount DECIMAL(28,8) NOT NULL,
    provision_currency CHAR(3) NOT NULL,
    cumulative_provision DECIMAL(28,8), -- Running total
    write_off_amount DECIMAL(28,8) DEFAULT 0,
    recovery_amount DECIMAL(28,8) DEFAULT 0,
    
    -- Calculation Inputs
    outstanding_balance DECIMAL(28,8),
    undrawn_commitments DECIMAL(28,8),
    collateral_value DECIMAL(28,8),
    guarantee_value DECIMAL(28,8),
    
    -- Macroeconomic Scenario
    macro_scenario VARCHAR(20),
    scenario_probability DECIMAL(5,4),
    weighted_ecl DECIMAL(28,8),
    
    -- Status
    provision_status VARCHAR(20) DEFAULT 'CALCULATED' 
        CHECK (provision_status IN ('CALCULATED', 'APPROVED', 'POSTED', 'REVERSED')),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_account_reporting_date UNIQUE (tenant_id, account_id, reporting_date)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.loan_loss_provisions_default PARTITION OF dynamic.loan_loss_provisions DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_provision_tenant ON dynamic.loan_loss_provisions(tenant_id);
CREATE INDEX idx_provision_account ON dynamic.loan_loss_provisions(tenant_id, account_id);
CREATE INDEX idx_provision_date ON dynamic.loan_loss_provisions(tenant_id, reporting_date);
CREATE INDEX idx_provision_stage ON dynamic.loan_loss_provisions(tenant_id, current_stage);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.loan_loss_provisions IS 'Loan loss provision calculations per account - IFRS 9 ECL tracking. Tier 2 - Risk Provisioning Engine.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.loan_loss_provisions TO finos_app;
