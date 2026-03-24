-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 19: CAPITAL & LIQUIDITY POSITION TRACKING
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: RWA, LCR, NSFR, Basel III/IV Compliance
-- Standards: Basel III/IV, CRR/CRD IV, CRR II, CRR III
-- =============================================================================

-- =============================================================================
-- EXPOSURE POSITIONS (Credit, Counterparty, Market, Operational)
-- =============================================================================
CREATE TABLE core.exposure_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Position Context
    entity_id UUID NOT NULL REFERENCES core.legal_entities(id),
    container_id UUID REFERENCES core.value_containers(id),
    agreement_id UUID,
    
    -- Exposure Classification (Basel Asset Classes)
    exposure_type VARCHAR(20) NOT NULL 
        CHECK (exposure_type IN ('credit', 'counterparty', 'market', 'operational', 'securitization', 'settlement')),
    asset_class VARCHAR(50) NOT NULL 
        CHECK (asset_class IN ('sovereign', 'bank', 'corporate', 'retail', 'mortgage', ' SME', 
                              'past_due', 'high_volatility', 'equity', 'other')),
    
    -- Exposure Amounts
    on_balance_sheet_amount DECIMAL(28,8) NOT NULL DEFAULT 0,
    off_balance_sheet_amount DECIMAL(28,8) NOT NULL DEFAULT 0,
    undrawn_amount DECIMAL(28,8) NOT NULL DEFAULT 0,
    gross_exposure DECIMAL(28,8) NOT NULL DEFAULT 0,
    
    -- Credit Risk Mitigation (CRM)
    collateral_value DECIMAL(28,8) NOT NULL DEFAULT 0,
    collateral_type VARCHAR(50),
    guarantee_value DECIMAL(28,8) NOT NULL DEFAULT 0,
    guarantee_provider_type VARCHAR(50), -- 'sovereign', 'bank', 'corporate'
    credit_derivative_value DECIMAL(28,8) NOT NULL DEFAULT 0,
    
    -- Net Exposure
    net_exposure DECIMAL(28,8) GENERATED ALWAYS AS (
        GREATEST(0, gross_exposure - LEAST(collateral_value + guarantee_value + credit_derivative_value, gross_exposure))
    ) STORED,
    
    -- Credit Risk Components
    probability_of_default DECIMAL(5,4) CHECK (probability_of_default BETWEEN 0 AND 1), -- PD
    loss_given_default DECIMAL(5,4) CHECK (loss_given_default BETWEEN 0 AND 1), -- LGD
    exposure_at_default DECIMAL(28,8), -- EAD
    maturity_years DECIMAL(5,2),
    
    -- Expected Credit Loss (IFRS 9)
    expected_credit_loss DECIMAL(28,8),
    ecl_stage INTEGER CHECK (ecl_stage IN (1, 2, 3)),
    
    -- Value Date
    value_date DATE NOT NULL,
    reporting_date DATE NOT NULL,
    
    -- Calculation Method
    calculation_method VARCHAR(50) DEFAULT 'standardized' 
        CHECK (calculation_method IN ('standardized', 'irb_foundation', 'irb_advanced', 'simplified')),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    created_by VARCHAR(100),
    
    CONSTRAINT unique_exposure UNIQUE (tenant_id, entity_id, container_id, exposure_type, value_date)
);

CREATE INDEX idx_exposure_entity ON core.exposure_positions(entity_id, value_date DESC);
CREATE INDEX idx_exposure_asset_class ON core.exposure_positions(tenant_id, asset_class, value_date);
CREATE INDEX idx_exposure_type ON core.exposure_positions(tenant_id, exposure_type, value_date);
CREATE INDEX idx_exposure_ecl ON core.exposure_positions(ecl_stage) WHERE ecl_stage IN (2, 3);

COMMENT ON TABLE core.exposure_positions IS 'Exposure positions for RWA calculations per Basel';

-- =============================================================================
-- RISK WEIGHTED ASSETS (RWA)
-- =============================================================================
CREATE TABLE core.risk_weighted_assets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Reference
    exposure_id UUID REFERENCES core.exposure_positions(id),
    entity_id UUID NOT NULL REFERENCES core.legal_entities(id),
    
    -- Risk Weights
    risk_weight DECIMAL(5,4) NOT NULL CHECK (risk_weight BETWEEN 0 AND 12.5), -- 0% to 1250%
    rwa_amount DECIMAL(28,8) NOT NULL,
    
    -- Components (for IRB)
    pd_used DECIMAL(5,4),
    lgd_used DECIMAL(5,4),
    correlation_factor DECIMAL(5,4),
    maturity_adjustment DECIMAL(5,4),
    
    -- Asset Class Details
    asset_class VARCHAR(50) NOT NULL,
    asset_subclass VARCHAR(50),
    
    -- RW Source
    risk_weight_source VARCHAR(50), -- 'standardized_table', 'external_rating', 'irb_model'
    external_rating VARCHAR(20),
    rating_agency VARCHAR(50),
    
    -- Reporting
    reporting_date DATE NOT NULL,
    calculation_method VARCHAR(20) NOT NULL,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID
);

CREATE INDEX idx_rwa_exposure ON core.risk_weighted_assets(exposure_id);
CREATE INDEX idx_rwa_entity ON core.risk_weighted_assets(entity_id, reporting_date DESC);
CREATE INDEX idx_rwa_reporting ON core.risk_weighted_assets(tenant_id, reporting_date);

COMMENT ON TABLE core.risk_weighted_assets IS 'Risk-weighted assets for capital adequacy calculations';

-- =============================================================================
-- CAPITAL POSITIONS
-- =============================================================================
CREATE TABLE core.capital_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    entity_id UUID NOT NULL REFERENCES core.legal_entities(id),
    
    -- Reporting Date
    reporting_date DATE NOT NULL,
    reporting_period VARCHAR(20),
    
    -- Total RWA
    total_credit_rwa DECIMAL(28,8) NOT NULL DEFAULT 0,
    total_market_rwa DECIMAL(28,8) NOT NULL DEFAULT 0,
    total_operational_rwa DECIMAL(28,8) NOT NULL DEFAULT 0,
    total_rwa DECIMAL(28,8) NOT NULL DEFAULT 0,
    
    -- CET1 Capital (Common Equity Tier 1)
    common_shares DECIMAL(28,8) DEFAULT 0,
    share_premium DECIMAL(28,8) DEFAULT 0,
    retained_earnings DECIMAL(28,8) DEFAULT 0,
    accumulated_other_comprehensive_income DECIMAL(28,8) DEFAULT 0,
    other_reserves DECIMAL(28,8) DEFAULT 0,
    minority_interest_cet1 DECIMAL(28,8) DEFAULT 0,
    cet1_before_deductions DECIMAL(28,8) DEFAULT 0,
    
    -- CET1 Deductions
    goodwill_deduction DECIMAL(28,8) DEFAULT 0,
    intangible_assets_deduction DECIMAL(28,8) DEFAULT 0,
    deferred_tax_assets_deduction DECIMAL(28,8) DEFAULT 0,
    other_cet1_deductions DECIMAL(28,8) DEFAULT 0,
    total_cet1_deductions DECIMAL(28,8) DEFAULT 0,
    
    -- CET1
    total_cet1 DECIMAL(28,8) NOT NULL DEFAULT 0,
    
    -- Additional Tier 1
    additional_tier_1_instruments DECIMAL(28,8) DEFAULT 0,
    tier_1_minority_interest DECIMAL(28,8) DEFAULT 0,
    additional_tier_1_deductions DECIMAL(28,8) DEFAULT 0,
    total_additional_tier_1 DECIMAL(28,8) DEFAULT 0,
    
    -- Tier 1
    total_tier_1 DECIMAL(28,8) GENERATED ALWAYS AS (total_cet1 + total_additional_tier_1) STORED,
    
    -- Tier 2
    tier_2_instruments DECIMAL(28,8) DEFAULT 0,
    tier_2_minority_interest DECIMAL(28,8) DEFAULT 0,
    tier_2_deductions DECIMAL(28,8) DEFAULT 0,
    total_tier_2 DECIMAL(28,8) DEFAULT 0,
    
    -- Total Capital
    total_capital DECIMAL(28,8) GENERATED ALWAYS AS (total_tier_1 + total_tier_2) STORED,
    
    -- Capital Ratios
    cet1_ratio DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN total_rwa > 0 THEN (total_cet1 / total_rwa) * 100 ELSE 0 END
    ) STORED,
    tier_1_ratio DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN total_rwa > 0 THEN (total_tier_1 / total_rwa) * 100 ELSE 0 END
    ) STORED,
    total_capital_ratio DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN total_rwa > 0 THEN (total_capital / total_rwa) * 100 ELSE 0 END
    ) STORED,
    
    -- Minimum Requirements (Basel III)
    min_cet1_required DECIMAL(5,2) DEFAULT 4.5,
    min_tier_1_required DECIMAL(5,2) DEFAULT 6.0,
    min_total_capital_required DECIMAL(5,2) DEFAULT 8.0,
    capital_conservation_buffer DECIMAL(5,2) DEFAULT 2.5,
    countercyclical_buffer DECIMAL(5,2) DEFAULT 0,
    g_sib_buffer DECIMAL(5,2) DEFAULT 0,
    
    -- Compliance
    cet1_compliant BOOLEAN GENERATED ALWAYS AS (
        cet1_ratio >= min_cet1_required + capital_conservation_buffer + countercyclical_buffer + g_sib_buffer
    ) STORED,
    tier_1_compliant BOOLEAN GENERATED ALWAYS AS (
        tier_1_ratio >= min_tier_1_required + capital_conservation_buffer + countercyclical_buffer + g_sib_buffer
    ) STORED,
    total_capital_compliant BOOLEAN GENERATED ALWAYS AS (
        total_capital_ratio >= min_total_capital_required + capital_conservation_buffer + countercyclical_buffer + g_sib_buffer
    ) STORED,
    
    -- Leverage Ratio
    total_exposure_leverage DECIMAL(28,8) DEFAULT 0,
    leverage_ratio DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN total_exposure_leverage > 0 THEN (total_tier_1 / total_exposure_leverage) * 100 ELSE 0 END
    ) STORED,
    
    -- Audit
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    calculated_by VARCHAR(100),
    reviewed_by VARCHAR(100),
    approved_by VARCHAR(100),
    
    CONSTRAINT unique_capital_position UNIQUE (tenant_id, entity_id, reporting_date)
);

CREATE INDEX idx_capital_positions_entity ON core.capital_positions(entity_id, reporting_date DESC);
CREATE INDEX idx_capital_positions_compliance ON core.capital_positions(tenant_id, cet1_compliant, tier_1_compliant, total_capital_compliant) 
    WHERE cet1_compliant = FALSE OR tier_1_compliant = FALSE OR total_capital_compliant = FALSE;
CREATE INDEX idx_capital_positions_ratios ON core.capital_positions(reporting_date, cet1_ratio, tier_1_ratio, total_capital_ratio);

COMMENT ON TABLE core.capital_positions IS 'Capital adequacy positions per Basel III/IV';
COMMENT ON COLUMN core.capital_positions.cet1_ratio IS 'Common Equity Tier 1 ratio (must be >= 4.5% + buffers)';

-- =============================================================================
-- LIQUIDITY COVERAGE RATIO (LCR)
-- =============================================================================
CREATE TABLE core.lcr_calculations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    entity_id UUID NOT NULL REFERENCES core.legal_entities(id),
    
    -- Time Bucket
    time_bucket VARCHAR(20) NOT NULL 
        CHECK (time_bucket IN ('overnight', '1_week', '1_month', '3_months', '1_year', 'over_1_year')),
    
    -- High Quality Liquid Assets (HQLA)
    level_1_hqla DECIMAL(28,8) DEFAULT 0, -- Cash, central bank reserves
    level_2a_hqla DECIMAL(28,8) DEFAULT 0, -- Sovereigns rated AA- or above
    level_2b_hqla DECIMAL(28,8) DEFAULT 0, -- Corporate bonds, equities (with haircut)
    level_2b_cap DECIMAL(28,8) GENERATED ALWAYS AS ((level_1_hqla + level_2a_hqla) * 0.4) STORED,
    total_hqla DECIMAL(28,8) GENERATED ALWAYS AS (
        level_1_hqla + level_2a_hqla + LEAST(level_2b_hqla, (level_1_hqla + level_2a_hqla) * 0.4)
    ) STORED,
    
    -- Cash Outflows (Stressed Scenario)
    retail_deposits_stable DECIMAL(28,8) DEFAULT 0,
    retail_deposits_less_stable DECIMAL(28,8) DEFAULT 0,
    unsecured_wholesale_funding DECIMAL(28,8) DEFAULT 0,
    secured_funding DECIMAL(28,8) DEFAULT 0,
    derivatives_outflows DECIMAL(28,8) DEFAULT 0,
    commitments_outflows DECIMAL(28,8) DEFAULT 0,
    other_outflows DECIMAL(28,8) DEFAULT 0,
    total_outflows DECIMAL(28,8) DEFAULT 0,
    
    -- Cash Inflows
    retail_loans DECIMAL(28,8) DEFAULT 0,
    wholesale_loans DECIMAL(28,8) DEFAULT 0,
    derivatives_inflows DECIMAL(28,8) DEFAULT 0,
    other_inflows DECIMAL(28,8) DEFAULT 0,
    total_inflows DECIMAL(28,8) GENERATED ALWAYS AS (
        LEAST(retail_loans + wholesale_loans + derivatives_inflows + other_inflows, 0.75 * total_outflows)
    ) STORED,
    
    -- LCR Calculation
    net_cash_outflows DECIMAL(28,8) GENERATED ALWAYS AS (total_outflows - total_inflows) STORED,
    lcr_ratio DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN net_cash_outflows > 0 THEN (total_hqla / net_cash_outflows) * 100 ELSE 999.99 END
    ) STORED,
    
    -- Compliance
    min_lcr_required DECIMAL(5,2) DEFAULT 100.00,
    lcr_compliant BOOLEAN GENERATED ALWAYS AS (lcr_ratio >= 100.00) STORED,
    
    -- Reporting
    reporting_date DATE NOT NULL,
    stress_scenario VARCHAR(50) DEFAULT 'standard', -- 'standard', 'adverse', 'severe'
    currency CHAR(3) DEFAULT 'USD',
    
    -- Audit
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_liquidity_position UNIQUE (tenant_id, entity_id, time_bucket, reporting_date, stress_scenario)
);

CREATE INDEX idx_lcr_entity ON core.lcr_calculations(entity_id, reporting_date DESC);
CREATE INDEX idx_lcr_compliance ON core.lcr_calculations(tenant_id, lcr_compliant) WHERE lcr_compliant = FALSE;
CREATE INDEX idx_lcr_buckets ON core.lcr_calculations(entity_id, time_bucket, reporting_date);

COMMENT ON TABLE core.lcr_calculations IS 'Liquidity Coverage Ratio calculations per Basel III';
COMMENT ON COLUMN core.lcr_calculations.lcr_ratio IS 'Liquidity Coverage Ratio (must be >= 100%)';

-- =============================================================================
-- NET STABLE FUNDING RATIO (NSFR)
-- =============================================================================
CREATE TABLE core.stable_funding_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    entity_id UUID NOT NULL REFERENCES core.legal_entities(id),
    
    -- Available Stable Funding (ASF)
    regulatory_capital_asf DECIMAL(28,8) DEFAULT 0,
    stable_retail_deposits DECIMAL(28,8) DEFAULT 0,
    less_stable_retail_deposits DECIMAL(28,8) DEFAULT 0,
    wholesale_funding_asf DECIMAL(28,8) DEFAULT 0,
    other_liabilities_asf DECIMAL(28,8) DEFAULT 0,
    total_asf DECIMAL(28,8) DEFAULT 0,
    
    -- Required Stable Funding (RSF)
    hqla_rsf DECIMAL(28,8) DEFAULT 0,
    retail_loans_rsf DECIMAL(28,8) DEFAULT 0,
    wholesale_loans_rsf DECIMAL(28,8) DEFAULT 0,
    securities_rsf DECIMAL(28,8) DEFAULT 0,
    other_assets_rsf DECIMAL(28,8) DEFAULT 0,
    derivatives_rsf DECIMAL(28,8) DEFAULT 0,
    off_balance_sheet_rsf DECIMAL(28,8) DEFAULT 0,
    total_rsf DECIMAL(28,8) DEFAULT 0,
    
    -- NSFR
    nsfr_ratio DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN total_rsf > 0 THEN (total_asf / total_rsf) * 100 ELSE 0 END
    ) STORED,
    
    -- Compliance
    min_nsfr_required DECIMAL(5,2) DEFAULT 100.00,
    nsfr_compliant BOOLEAN GENERATED ALWAYS AS (nsfr_ratio >= 100.00) STORED,
    
    -- Reporting
    reporting_date DATE NOT NULL,
    currency CHAR(3) DEFAULT 'USD',
    
    -- Audit
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    
    CONSTRAINT unique_nsfr_position UNIQUE (tenant_id, entity_id, reporting_date)
);

CREATE INDEX idx_nsfr_entity ON core.stable_funding_positions(entity_id, reporting_date DESC);
CREATE INDEX idx_nsfr_compliance ON core.stable_funding_positions(tenant_id, nsfr_compliant) WHERE nsfr_compliant = FALSE;

COMMENT ON TABLE core.stable_funding_positions IS 'Net Stable Funding Ratio calculations';

-- =============================================================================
-- STRESS SCENARIOS
-- =============================================================================
CREATE TABLE core.stress_scenarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Scenario Definition
    scenario_name VARCHAR(100) NOT NULL,
    scenario_type VARCHAR(50) NOT NULL CHECK (scenario_type IN ('adverse', 'severe', 'idiosyncratic', 'systemic')),
    scenario_description TEXT,
    
    -- Parameters
    parameters JSONB NOT NULL, -- {
                               --   "interest_rate_shock": 0.02,
                               --   "unemployment_rate": 0.10,
                               --   "gdp_shock": -0.05,
                               --   "property_price_decline": 0.20,
                               --   "equity_price_decline": 0.30
                               -- }
    
    -- Impact
    impact_on_cet1 DECIMAL(28,8),
    impact_on_total_capital DECIMAL(28,8),
    impact_on_rwa DECIMAL(28,8),
    impact_on_liquidity DECIMAL(28,8),
    
    -- Results
    stressed_cet1_ratio DECIMAL(5,2),
    stressed_total_capital_ratio DECIMAL(5,2),
    stressed_lcr DECIMAL(5,2),
    
    -- Reverse Stress Test
    reverse_stress_test BOOLEAN DEFAULT FALSE,
    business_model_viability_affected BOOLEAN DEFAULT FALSE,
    
    -- Date
    scenario_date DATE NOT NULL,
    horizon_years INTEGER DEFAULT 3,
    
    -- Status
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'approved', 'rejected')),
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID
);

CREATE INDEX idx_stress_scenarios_type ON core.stress_scenarios(tenant_id, scenario_type, scenario_date DESC);
CREATE INDEX idx_stress_scenarios_status ON core.stress_scenarios(status) WHERE status = 'approved';
CREATE INDEX idx_stress_scenarios_correlation ON core.stress_scenarios(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core.stress_scenarios IS 'Stress test scenarios and results';

-- =============================================================================
-- LEVERAGE RATIO EXPOSURES
-- =============================================================================
CREATE TABLE core.leverage_exposures (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    entity_id UUID NOT NULL REFERENCES core.legal_entities(id),
    
    -- Exposure Components
    on_balance_sheet_exposure DECIMAL(28,8) DEFAULT 0,
    derivative_exposure DECIMAL(28,8) DEFAULT 0,
    sft_exposure DECIMAL(28,8) DEFAULT 0, -- Securities financing transactions
    off_balance_sheet_exposure DECIMAL(28,8) DEFAULT 0,
    
    -- Total Exposure
    total_exposure DECIMAL(28,8) GENERATED ALWAYS AS (
        on_balance_sheet_exposure + derivative_exposure + sft_exposure + off_balance_sheet_exposure
    ) STORED,
    
    -- Tier 1 Capital (from capital_positions)
    tier_1_capital DECIMAL(28,8),
    
    -- Leverage Ratio
    leverage_ratio DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN total_exposure > 0 THEN (tier_1_capital / total_exposure) * 100 ELSE 0 END
    ) STORED,
    
    -- Compliance (Basel III minimum: 3%)
    min_leverage_required DECIMAL(5,2) DEFAULT 3.00,
    leverage_compliant BOOLEAN GENERATED ALWAYS AS (leverage_ratio >= 3.00) STORED,
    
    -- Reporting
    reporting_date DATE NOT NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    
    CONSTRAINT unique_leverage_exposure UNIQUE (tenant_id, entity_id, reporting_date)
);

CREATE INDEX idx_leverage_entity ON core.leverage_exposures(entity_id, reporting_date DESC);
CREATE INDEX idx_leverage_compliance ON core.leverage_exposures(tenant_id, leverage_compliant) WHERE leverage_compliant = FALSE;

COMMENT ON TABLE core.leverage_exposures IS 'Leverage ratio exposure calculations';

-- =============================================================================
-- REGULATORY REPORTING SNAPSHOTS
-- =============================================================================
CREATE TABLE core.regulatory_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    entity_id UUID NOT NULL REFERENCES core.legal_entities(id),
    
    -- Reporting Context
    reporting_date DATE NOT NULL,
    report_type VARCHAR(50) NOT NULL CHECK (report_type IN ('COREP', 'FINREP', 'LCR', 'NSFR', 'Leverage', 'Large_Exposures')),
    report_template VARCHAR(50),
    
    -- Consolidated Data
    snapshot_data JSONB NOT NULL,
    
    -- Validation
    validation_status VARCHAR(20) DEFAULT 'pending' CHECK (validation_status IN ('pending', 'valid', 'errors', 'warnings')),
    validation_errors JSONB,
    
    -- Submission
    submitted BOOLEAN DEFAULT FALSE,
    submitted_at TIMESTAMPTZ,
    submitted_by VARCHAR(100),
    submission_reference VARCHAR(100),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    
    CONSTRAINT unique_regulatory_snapshot UNIQUE (tenant_id, entity_id, reporting_date, report_type)
);

CREATE INDEX idx_regulatory_snapshots_type ON core.regulatory_snapshots(entity_id, report_type, reporting_date DESC);

COMMENT ON TABLE core.regulatory_snapshots IS 'Consolidated regulatory reporting snapshots';

-- =============================================================================
-- CAPITAL ADEQUACY VIEW
-- =============================================================================
CREATE OR REPLACE VIEW core.capital_adequacy_summary AS
SELECT 
    cp.tenant_id,
    cp.entity_id,
    cp.reporting_date,
    
    -- Capital
    cp.total_cet1,
    cp.total_tier_1,
    cp.total_capital,
    
    -- RWA
    cp.total_rwa,
    
    -- Ratios
    cp.cet1_ratio,
    cp.tier_1_ratio,
    cp.total_capital_ratio,
    
    -- Requirements
    cp.min_cet1_required + cp.capital_conservation_buffer + cp.countercyclical_buffer + cp.g_sib_buffer AS total_cet1_requirement,
    cp.min_tier_1_required + cp.capital_conservation_buffer + cp.countercyclical_buffer + cp.g_sib_buffer AS total_tier_1_requirement,
    cp.min_total_capital_required + cp.capital_conservation_buffer + cp.countercyclical_buffer + cp.g_sib_buffer AS total_capital_requirement,
    
    -- Compliance
    cp.cet1_compliant,
    cp.tier_1_compliant,
    cp.total_capital_compliant,
    
    -- Leverage
    le.leverage_ratio,
    le.leverage_compliant,
    
    -- Liquidity
    lcr.lcr_ratio,
    lcr.lcr_compliant,
    sf.nsfr_ratio,
    sf.nsfr_compliant
    
FROM core.capital_positions cp
LEFT JOIN core.leverage_exposures le ON le.entity_id = cp.entity_id AND le.reporting_date = cp.reporting_date
LEFT JOIN core.lcr_calculations lcr ON lcr.entity_id = cp.entity_id AND lcr.reporting_date = cp.reporting_date AND lcr.time_bucket = '1_month'
LEFT JOIN core.stable_funding_positions sf ON sf.entity_id = cp.entity_id AND sf.reporting_date = cp.reporting_date;

COMMENT ON VIEW core.capital_adequacy_summary IS 'Comprehensive capital and liquidity adequacy summary';

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.exposure_positions TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.risk_weighted_assets TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.capital_positions TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.lcr_calculations TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.stable_funding_positions TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.stress_scenarios TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.leverage_exposures TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.regulatory_snapshots TO finos_app;
GRANT SELECT ON core.capital_adequacy_summary TO finos_app;
