-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 05 - Simulation Forecasting
-- TABLE: dynamic_history.simulation_aggregate_results
-- COMPLIANCE: Basel III/IV
--   - IFRS 9
--   - CCAR
--   - Solvency II
-- ============================================================================


CREATE TABLE dynamic_history.simulation_aggregate_results (

    result_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    run_id UUID NOT NULL REFERENCES dynamic.simulation_run_control(run_id),
    
    -- Aggregation Level
    aggregation_level VARCHAR(50) NOT NULL, -- PORTFOLIO, PRODUCT, SEGMENT, etc.
    aggregation_key VARCHAR(200) NOT NULL,
    
    -- Time Dimension
    projection_month INTEGER,
    projection_date DATE,
    
    -- Balance Aggregates
    total_balance DECIMAL(28,8),
    total_principal DECIMAL(28,8),
    total_interest_accrued DECIMAL(28,8),
    
    -- Income Aggregates
    total_interest_income DECIMAL(28,8),
    total_fee_income DECIMAL(28,8),
    
    -- Risk Aggregates
    total_ecl DECIMAL(28,8),
    total_expected_loss DECIMAL(28,8),
    stage_1_balance DECIMAL(28,8),
    stage_2_balance DECIMAL(28,8),
    stage_3_balance DECIMAL(28,8),
    
    -- Counts
    account_count INTEGER,
    default_count INTEGER,
    prepayment_count INTEGER,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_aggregate_result UNIQUE (tenant_id, run_id, aggregation_level, aggregation_key, projection_month)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.simulation_aggregate_results_default PARTITION OF dynamic_history.simulation_aggregate_results DEFAULT;

-- Indexes
CREATE INDEX idx_aggregate_run ON dynamic_history.simulation_aggregate_results(tenant_id, run_id);

-- Comments
COMMENT ON TABLE dynamic_history.simulation_aggregate_results IS 'Aggregated simulation results by portfolio/product';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.simulation_aggregate_results TO finos_app;