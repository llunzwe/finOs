-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 05 - Simulation Forecasting
-- TABLE: dynamic.scenario_macro_economic_factors
-- COMPLIANCE: Basel III/IV
--   - IFRS 9
--   - CCAR
--   - Solvency II
-- ============================================================================


CREATE TABLE dynamic.scenario_macro_economic_factors (

    factor_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    scenario_id UUID NOT NULL REFERENCES dynamic.scenario_definition(scenario_id) ON DELETE CASCADE,
    
    -- Factor Definition
    factor_name VARCHAR(100) NOT NULL, -- GDP, UNEMPLOYMENT, INFLATION, etc.
    factor_code VARCHAR(50) NOT NULL,
    factor_description TEXT,
    
    -- Factor Value
    factor_value DECIMAL(15,8) NOT NULL,
    factor_unit VARCHAR(50), -- PERCENT, INDEX, CURRENCY, etc.
    
    -- Time Series Data
    time_series_data JSONB, -- [{period: '2024-Q1', value: 2.5}, ...]
    time_series_granularity VARCHAR(20) DEFAULT 'QUARTERLY' 
        CHECK (time_series_granularity IN ('MONTHLY', 'QUARTERLY', 'ANNUAL')),
    
    -- Projections
    projection_start_date DATE NOT NULL,
    projection_end_date DATE NOT NULL,
    projection_periods INTEGER NOT NULL,
    
    -- Source
    data_source VARCHAR(100),
    data_quality_score DECIMAL(3,2), -- 0-1
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    CONSTRAINT unique_scenario_factor UNIQUE (tenant_id, scenario_id, factor_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.scenario_macro_economic_factors_default PARTITION OF dynamic.scenario_macro_economic_factors DEFAULT;

-- Indexes
CREATE INDEX idx_macro_factors_scenario ON dynamic.scenario_macro_economic_factors(tenant_id, scenario_id);

-- Comments
COMMENT ON TABLE dynamic.scenario_macro_economic_factors IS 'Macro-economic variable projections by scenario';

GRANT SELECT, INSERT, UPDATE ON dynamic.scenario_macro_economic_factors TO finos_app;