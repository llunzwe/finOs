-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 39 - Risk Management
-- TABLE: dynamic.stress_testing_scenarios
--
-- DESCRIPTION:
--   Enterprise-grade stress testing and ICAAP/ILAAP scenario configuration.
--   Macro-economic shocks, liquidity stress, credit stress scenarios.
--
-- COMPLIANCE: Basel III/IV, EBA Stress Testing, SARB, RBZ
-- ============================================================================


CREATE TABLE dynamic.stress_testing_scenarios (
    scenario_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Scenario Identification
    scenario_code VARCHAR(100) NOT NULL,
    scenario_name VARCHAR(200) NOT NULL,
    scenario_description TEXT,
    
    -- Scenario Classification
    scenario_type VARCHAR(50) NOT NULL 
        CHECK (scenario_type IN ('MACROECONOMIC', 'CREDIT_RISK', 'MARKET_RISK', 'LIQUIDITY_RISK', 'OPERATIONAL_RISK', 'CLIMATE', 'CYBER')),
    severity_level VARCHAR(20) NOT NULL 
        CHECK (severity_level IN ('BASELINE', 'MILD', 'MODERATE', 'SEVERE', 'EXTREME')),
    
    -- Time Horizon
    projection_period_years INTEGER DEFAULT 3,
    shock_application VARCHAR(20) DEFAULT 'IMMEDIATE' 
        CHECK (shock_application IN ('IMMEDIATE', 'GRADUAL', 'PHASED')),
    
    -- Macroeconomic Variables
    gdp_growth_shock DECIMAL(10,6), -- Percentage change
    unemployment_rate_shock DECIMAL(10,6),
    inflation_rate_shock DECIMAL(10,6),
    interest_rate_shock DECIMAL(10,6),
    property_price_shock DECIMAL(10,6),
    exchange_rate_shock DECIMAL(10,6),
    
    -- Credit Risk Parameters
    pd_multiplier DECIMAL(5,2) DEFAULT 1.0,
    lgd_increase_percentage DECIMAL(5,4),
    credit_migration_matrix JSONB,
    
    -- Market Risk Parameters
    equity_price_shock DECIMAL(10,6),
    credit_spread_widening_basis_points INTEGER,
    
    -- Liquidity Risk Parameters
    deposit_run_off_rate DECIMAL(5,4),
    wholesale_funding_stress DECIMAL(5,4),
    collateral_haircut_increase DECIMAL(5,4),
    
    -- Reverse Stress Testing
    is_reverse_stress_test BOOLEAN DEFAULT FALSE,
    target_capital_depletion DECIMAL(5,4), -- Target impact level
    
    -- Regulatory Context
    regulatory_submission VARCHAR(50), -- 'EBA_2024', 'SARB_STRESS_TEST'
    icaap_ilaap_relevant BOOLEAN DEFAULT TRUE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_scenario_code UNIQUE (tenant_id, scenario_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.stress_testing_scenarios_default PARTITION OF dynamic.stress_testing_scenarios DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.stress_testing_scenarios IS 'Stress testing scenarios - macroeconomic shocks, ICAAP/ILAAP. Tier 2 - Risk Management.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.stress_testing_scenarios TO finos_app;
