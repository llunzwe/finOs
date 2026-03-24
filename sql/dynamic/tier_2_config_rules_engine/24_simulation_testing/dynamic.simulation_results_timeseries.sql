-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 24 - Simulation Testing
-- TABLE: dynamic.simulation_results_timeseries
-- COMPLIANCE: ISTQB
--   - Basel
--   - SOX
--   - ITIL
-- ============================================================================


CREATE TABLE dynamic.simulation_results_timeseries (

    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    scenario_id UUID NOT NULL REFERENCES dynamic.simulation_scenarios(scenario_id),
    
    -- Time Point
    period_date DATE NOT NULL,
    period_number INTEGER NOT NULL,
    
    -- Run Number (for Monte Carlo)
    run_number INTEGER DEFAULT 1,
    
    -- Metrics
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(28,8),
    metric_unit VARCHAR(50),
    
    -- Dimensions
    segment VARCHAR(100), -- customer segment, product variant, etc.
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.simulation_results_timeseries_default PARTITION OF dynamic.simulation_results_timeseries DEFAULT;

-- Indexes
CREATE INDEX idx_sim_timeseries_scenario ON dynamic.simulation_results_timeseries(tenant_id, scenario_id, period_date);
CREATE INDEX idx_sim_timeseries_metric ON dynamic.simulation_results_timeseries(tenant_id, metric_name);

GRANT SELECT, INSERT, UPDATE ON dynamic.simulation_results_timeseries TO finos_app;