-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 15: PROVISIONING & RESERVES
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: IFRS 9 ECL, IAS 37, Solvency II, Risk Staging
-- Standards: IFRS 9, IFRS 17, Solvency II, Basel III
-- =============================================================================

-- =============================================================================
-- PROVISIONS (Expected Credit Loss)
-- =============================================================================
CREATE TABLE core.provisions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Source
    container_id UUID NOT NULL REFERENCES core.value_containers(id),
    agreement_id UUID, -- Optional link to loan/agreement
    
    -- Provision Classification
    provision_type VARCHAR(30) NOT NULL 
        CHECK (provision_type IN ('loan_loss', 'warranty', 'insurance_claim', 'fx_risk', 'legal', 'restructuring', 'decommissioning')),
    accounting_standard VARCHAR(20) NOT NULL 
        CHECK (accounting_standard IN ('IFRS9', 'IFRS17', 'GAAP', 'LOCAL_GAAP', 'SOLVENCY_II')),
    
    -- Calculation Basis
    base_exposure_amount DECIMAL(28,8) NOT NULL,
    provision_rate DECIMAL(10,6) NOT NULL,
    provision_amount DECIMAL(28,8) NOT NULL,
    
    -- IFRS 9 Expected Credit Loss (ECL)
    calculation_method VARCHAR(50) NOT NULL 
        CHECK (calculation_method IN ('expected_credit_loss', 'incurred_loss', 'historical', 'forward_looking', 'probability_weighted')),
    
    -- Credit Risk Components
    probability_of_default DECIMAL(5,4) CHECK (probability_of_default BETWEEN 0 AND 1), -- PD
    loss_given_default DECIMAL(5,4) CHECK (loss_given_default BETWEEN 0 AND 1), -- LGD
    exposure_at_default DECIMAL(28,8), -- EAD
    
    -- IFRS 9 Staging (3-Stage Model)
    staging_bucket INTEGER CHECK (staging_bucket IN (1, 2, 3)),
    staging_rationale TEXT,
    days_past_due INTEGER,
    
    -- Forward-Looking Information
    macroeconomic_scenario VARCHAR(20) CHECK (macroeconomic_scenario IN ('baseline', 'adverse', 'severe')),
    gdp_growth_assumption DECIMAL(5,4),
    unemployment_assumption DECIMAL(5,4),
    
    -- Multi-Scenario ECL
    base_scenario_ecl DECIMAL(28,8),
    adverse_scenario_ecl DECIMAL(28,8),
    severe_scenario_ecl DECIMAL(28,8),
    probability_weighted_ecl DECIMAL(28,8),
    
    -- Effective Date
    effective_date DATE NOT NULL,
    report_date DATE NOT NULL,
    reporting_period VARCHAR(20), -- '2026-Q1', '2026-H1', '2026'
    
    -- Status
    status VARCHAR(20) DEFAULT 'calculated' 
        CHECK (status IN ('calculated', 'reviewed', 'posted', 'adjusted', 'released', 'written_off')),
    
    -- Accounting Movement
    provision_movement_id UUID REFERENCES core.value_movements(id),
    expense_account_code VARCHAR(50),
    provision_account_code VARCHAR(50),
    write_off_movement_id UUID REFERENCES core.value_movements(id),
    
    -- Approval Chain
    calculated_by UUID REFERENCES core.economic_agents(id),
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_by UUID REFERENCES core.economic_agents(id),
    reviewed_at TIMESTAMPTZ,
    approved_by UUID REFERENCES core.economic_agents(id),
    approved_at TIMESTAMPTZ,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER DEFAULT 1,
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    
    -- Constraints
    CONSTRAINT chk_positive_provision CHECK (provision_amount >= 0),
    CONSTRAINT chk_ecl_components CHECK (
        provision_amount = ROUND(base_exposure_amount * probability_of_default * loss_given_default, 2) OR
        calculation_method != 'expected_credit_loss'
    )
);

CREATE INDEX idx_provisions_container ON core.provisions(container_id, status);
CREATE INDEX idx_provisions_staging ON core.provisions(tenant_id, staging_bucket) WHERE staging_bucket IN (2, 3);
CREATE INDEX idx_provisions_report_date ON core.provisions(tenant_id, report_date);
CREATE INDEX idx_provisions_status ON core.provisions(status) WHERE status IN ('calculated', 'reviewed');
CREATE INDEX idx_provisions_correlation ON core.provisions(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core.provisions IS 'IFRS 9 Expected Credit Loss provisions with staging';
COMMENT ON COLUMN core.provisions.staging_bucket IS 'IFRS 9: 1=12-month ECL, 2=Lifetime ECL (not credit-impaired), 3=Lifetime ECL (credit-impaired)';

-- =============================================================================
-- PROVISION HISTORY
-- =============================================================================
CREATE TABLE core_history.provision_history (
    time TIMESTAMPTZ NOT NULL,
    tenant_id UUID NOT NULL,
    
    provision_id UUID NOT NULL,
    container_id UUID NOT NULL,
    
    report_date DATE NOT NULL,
    staging_bucket INTEGER,
    provision_amount DECIMAL(28,8),
    base_exposure DECIMAL(28,8),
    pd DECIMAL(5,4),
    lgd DECIMAL(5,4),
    
    PRIMARY KEY (time, provision_id)
);

SELECT create_hypertable('core_history.provision_history', 'time', 
                         chunk_time_interval => INTERVAL '1 month',
                         if_not_exists => TRUE);

CREATE INDEX idx_provision_history_container ON core_history.provision_history(container_id, time DESC);

-- =============================================================================
-- RESERVE UTILIZATIONS
-- =============================================================================
CREATE TABLE core.reserve_utilizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    provision_id UUID NOT NULL REFERENCES core.provisions(id),
    
    -- Utilization Details
    utilization_type VARCHAR(20) NOT NULL 
        CHECK (utilization_type IN ('claim_paid', 'write_off', 'recovery', 'release', 'reversal')),
    amount DECIMAL(28,8) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    
    -- Original Loss Covered
    original_movement_id UUID REFERENCES core.value_movements(id),
    covered_agreement_id UUID,
    
    -- Accounting
    utilization_date DATE NOT NULL,
    debit_account VARCHAR(50) NOT NULL, -- Provision account
    credit_account VARCHAR(50) NOT NULL, -- Cash or receivable
    movement_id UUID REFERENCES core.value_movements(id),
    
    -- Recovery Details (if applicable)
    recovery_amount DECIMAL(28,8),
    recovery_date DATE,
    recovery_source VARCHAR(100),
    
    -- Approval
    approved_by UUID REFERENCES core.economic_agents(id),
    approved_at TIMESTAMPTZ,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    CONSTRAINT chk_utilization_amount CHECK (amount != 0)
);

CREATE INDEX idx_reserve_util_provision ON core.reserve_utilizations(provision_id, utilization_date);
CREATE INDEX idx_reserve_util_type ON core.reserve_utilizations(tenant_id, utilization_type);

COMMENT ON TABLE core.reserve_utilizations IS 'Utilization of provisions for claims, write-offs, and recoveries';

-- =============================================================================
-- LOSS GIVEN DEFAULT (LGD) MODELS
-- =============================================================================
CREATE TABLE core.lgd_models (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(20) NOT NULL,
    model_type VARCHAR(50) NOT NULL CHECK (model_type IN ('workout', 'market', 'hybrid')),
    
    -- Asset Class
    asset_class VARCHAR(50) NOT NULL 
        CHECK (asset_class IN ('sovereign', 'bank', 'corporate', 'retail', 'mortgage', 'unsecured')),
    
    -- LGD Components
    downturn_lgd DECIMAL(5,4) CHECK (downturn_lgd BETWEEN 0 AND 1),
    long_run_average_lgd DECIMAL(5,4) CHECK (long_run_average_lgd BETWEEN 0 AND 1),
    
    -- Collateral Adjustments
    collateral_type VARCHAR(50),
    collateral_haircut DECIMAL(5,4),
    collateral_volatility DECIMAL(5,4),
    
    -- Model Parameters
    parameters JSONB NOT NULL DEFAULT '{}',
    
    -- Validation
    validation_date DATE,
    validation_status VARCHAR(20),
    next_validation_date DATE,
    
    is_active BOOLEAN DEFAULT TRUE,
    valid_from DATE NOT NULL DEFAULT '1900-01-01',
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    
    CONSTRAINT unique_lgd_model UNIQUE (tenant_id, model_name, model_version, asset_class)
);

COMMENT ON TABLE core.lgd_models IS 'Loss Given Default models for IRB approaches';

-- =============================================================================
-- PROBABILITY OF DEFAULT (PD) MODELS
-- =============================================================================
CREATE TABLE core.pd_models (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(20) NOT NULL,
    model_type VARCHAR(50) NOT NULL CHECK (model_type IN ('point_in_time', 'through_the_cycle', 'hybrid')),
    
    -- Asset Class
    asset_class VARCHAR(50) NOT NULL,
    
    -- PD Components
    one_year_pd DECIMAL(5,4) CHECK (one_year_pd BETWEEN 0 AND 1),
    long_run_average_pd DECIMAL(5,4) CHECK (long_run_average_pd BETWEEN 0 AND 1),
    downturn_pd DECIMAL(5,4) CHECK (downturn_pd BETWEEN 0 AND 1),
    
    -- Model Parameters
    parameters JSONB NOT NULL DEFAULT '{}',
    
    -- Validation
    validation_date DATE,
    validation_status VARCHAR(20),
    next_validation_date DATE,
    
    is_active BOOLEAN DEFAULT TRUE,
    valid_from DATE NOT NULL DEFAULT '1900-01-01',
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    
    CONSTRAINT unique_pd_model UNIQUE (tenant_id, model_name, model_version, asset_class)
);

COMMENT ON TABLE core.pd_models IS 'Probability of Default models for credit risk';

-- =============================================================================
-- EXPOSURE AT DEFAULT (EAD) CALCULATIONS
-- =============================================================================
CREATE TABLE core.ead_calculations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    container_id UUID NOT NULL REFERENCES core.value_containers(id),
    
    -- Current Exposure
    current_exposure DECIMAL(28,8) NOT NULL,
    undrawn_amount DECIMAL(28,8) DEFAULT 0,
    
    -- CCF (Credit Conversion Factor)
    ccf DECIMAL(5,4) DEFAULT 1.0,
    
    -- EAD Calculation
    ead DECIMAL(28,8) GENERATED ALWAYS AS (current_exposure + undrawn_amount * ccf) STORED,
    
    -- Mitigation
    collateral_value DECIMAL(28,8) DEFAULT 0,
    guarantee_value DECIMAL(28,8) DEFAULT 0,
    credit_derivative_value DECIMAL(28,8) DEFAULT 0,
    
    -- Net EAD
    net_ead DECIMAL(28,8) GENERATED ALWAYS AS (
        GREATEST(0, current_exposure + undrawn_amount * ccf - 
                 LEAST(collateral_value + guarantee_value + credit_derivative_value, 
                       current_exposure + undrawn_amount * ccf))
    ) STORED,
    
    -- Calculation Date
    calculation_date DATE NOT NULL,
    effective_maturity DECIMAL(5,2), -- M in IRB formula
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ead_container ON core.ead_calculations(container_id, calculation_date DESC);
CREATE INDEX idx_ead_calculation ON core.ead_calculations(tenant_id, calculation_date);

COMMENT ON TABLE core.ead_calculations IS 'Exposure at Default calculations with CCF';

-- =============================================================================
-- PROVISION CALCULATION FUNCTION
-- =============================================================================
CREATE OR REPLACE FUNCTION core.calculate_ecl(
    p_exposure DECIMAL(28,8),
    p_pd DECIMAL(5,4),
    p_lgd DECIMAL(5,4),
    p_staging INTEGER,
    p_time_horizon_years DECIMAL(5,2) DEFAULT 1.0
) RETURNS DECIMAL(28,8) AS $$
DECLARE
    v_ecl DECIMAL(28,8);
BEGIN
    -- Stage 1: 12-month ECL
    IF p_staging = 1 THEN
        v_ecl := p_exposure * p_pd * p_lgd * LEAST(p_time_horizon_years, 1.0);
    -- Stage 2 & 3: Lifetime ECL
    ELSE
        v_ecl := p_exposure * p_pd * p_lgd * p_time_horizon_years;
    END IF;
    
    RETURN ROUND(v_ecl, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION core.calculate_ecl IS 'Calculates Expected Credit Loss based on IFRS 9';

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.provisions TO finos_app;
GRANT SELECT, INSERT ON core_history.provision_history TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.reserve_utilizations TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.lgd_models TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.pd_models TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.ead_calculations TO finos_app;
GRANT EXECUTE ON FUNCTION core.calculate_ecl TO finos_app;
