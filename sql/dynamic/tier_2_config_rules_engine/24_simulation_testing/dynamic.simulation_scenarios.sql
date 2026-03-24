-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 24 - Simulation Testing
-- TABLE: dynamic.simulation_scenarios
-- COMPLIANCE: ISTQB
--   - Basel
--   - SOX
--   - ITIL
-- ============================================================================


CREATE TABLE dynamic.simulation_scenarios (

    scenario_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Scenario Identity
    scenario_name VARCHAR(200) NOT NULL,
    scenario_description TEXT,
    scenario_type VARCHAR(50) NOT NULL 
        CHECK (scenario_type IN ('CUSTOMER_LIFETIME', 'BANK_PORTFOLIO', 'REGULATORY_STRESS', 'MARKET_CONDITIONS', 'CUSTOM')),
    
    -- Product Context
    product_version_id UUID REFERENCES dynamic.product_versions(version_id),
    
    -- Simulation Configuration
    simulation_config JSONB NOT NULL DEFAULT '{}',
    -- Example: {
    --   projection_years: 30,
    --   time_granularity: 'monthly',
    --   monte_carlo_runs: 1000,
    --   random_seed: 12345
    -- }
    
    -- Customer Simulation (for CUSTOMER_LIFETIME type)
    customer_simulation JSONB DEFAULT '{}',
    -- Example: {
    --   customer_count: 10000,
    --   acquisition_rate: 0.05,
    --   churn_rate: 0.02,
    --   behavior_models: ['conservative', 'moderate', 'aggressive']
    -- }
    
    -- Economic Assumptions
    economic_assumptions JSONB DEFAULT '{}',
    -- Example: {
    --   interest_rate_scenarios: [
    --     {name: 'base', rate: 0.05, probability: 0.5},
    --     {name: 'high', rate: 0.08, probability: 0.3},
    --     {name: 'low', rate: 0.03, probability: 0.2}
    --   ],
    --   gdp_growth: 0.025,
    --   inflation: 0.02,
    --   unemployment: 0.05
    -- }
    
    -- Risk Assumptions
    risk_assumptions JSONB DEFAULT '{}',
    -- Example: {
    --   default_probability_curves: [...],
    --   loss_given_default: 0.40,
    --   correlation_factors: {...}
    -- }
    
    -- Output Configuration
    output_metrics TEXT[] DEFAULT ARRAY['NPV', 'IRR', 'EXPECTED_LOSS', 'PROVISION', 'RAROC'],
    output_granularity VARCHAR(20) DEFAULT 'monthly',
    output_formats TEXT[] DEFAULT ARRAY['json', 'csv', 'charts'],
    
    -- Execution
    status VARCHAR(20) DEFAULT 'draft' 
        CHECK (status IN ('draft', 'queued', 'running', 'completed', 'failed', 'cancelled')),
    
    progress_percentage INTEGER DEFAULT 0 CHECK (progress_percentage BETWEEN 0 AND 100),
    current_run_number INTEGER,
    
    -- Results Storage
    results_summary JSONB,
    results_detailed JSONB,
    result_charts JSONB, -- Chart.js compatible data
    result_files TEXT[], -- URLs to generated files
    
    -- Performance
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    execution_time_seconds INTEGER,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.simulation_scenarios_default PARTITION OF dynamic.simulation_scenarios DEFAULT;

-- Indexes
CREATE INDEX idx_simulation_scenarios_tenant ON dynamic.simulation_scenarios(tenant_id, status) 
    WHERE status IN ('draft', 'queued', 'running');
CREATE INDEX idx_simulation_scenarios_product ON dynamic.simulation_scenarios(tenant_id, product_version_id);

-- Comments
COMMENT ON TABLE dynamic.simulation_scenarios IS 
    'Bank + Customer simulations with lifetime projection capabilities';

-- Triggers
CREATE TRIGGER trg_simulation_scenarios_update
    BEFORE UPDATE ON dynamic.simulation_scenarios
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_simulation_testing_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.simulation_scenarios TO finos_app;