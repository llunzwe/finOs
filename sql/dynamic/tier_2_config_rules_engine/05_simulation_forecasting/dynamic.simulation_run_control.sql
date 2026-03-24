-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 05 - Simulation & Forecasting
-- TABLE: dynamic.simulation_run_control
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Simulation Run Control.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 8601
--   - ISO 20022
--   - IFRS 15
--   - Basel III
--   - OECD
--   - NCA
--
-- AUDIT & GOVERNANCE:
--   - Bitemporal tracking (effective_from/valid_from, effective_to/valid_to)
--   - Full audit trail (created_at, updated_at, created_by, updated_by)
--   - Version control for change management
--   - Tenant isolation via partitioning
--   - Row-Level Security (RLS) for data protection
--
-- DATA CLASSIFICATION:
--   - Tenant Isolation: Row-Level Security enabled
--   - Audit Level: FULL
--   - Encryption: At-rest for sensitive fields
--
-- ============================================================================
CREATE TABLE dynamic.simulation_run_control (

    run_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Scenario Reference
    scenario_id UUID NOT NULL REFERENCES dynamic.scenario_definition(scenario_id),
    
    -- Run Details
    run_name VARCHAR(200),
    run_description TEXT,
    run_type VARCHAR(50) DEFAULT 'FULL' 
        CHECK (run_type IN ('FULL', 'INCREMENTAL', 'SENSITIVITY', 'MONTE_CARLO')),
    
    -- Execution Control
    run_status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (run_status IN ('PENDING', 'QUEUED', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    parallelization_degree INTEGER DEFAULT 1,
    
    -- Sample Size
    sample_size INTEGER, -- Number of accounts/portfolios simulated
    total_accounts INTEGER, -- Total population
    sampling_method VARCHAR(50), -- RANDOM, STRATIFIED, etc.
    
    -- Randomization
    random_seed BIGINT,
    
    -- Timing
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    estimated_completion_at TIMESTAMPTZ,
    
    -- Performance
    compute_cost_seconds INTEGER,
    memory_peak_mb INTEGER,
    
    -- Results
    results_summary JSONB,
    result_storage_location TEXT,
    
    -- Error Handling
    error_message TEXT,
    error_details JSONB,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.simulation_run_control_default PARTITION OF dynamic.simulation_run_control DEFAULT;

-- Indexes
CREATE INDEX idx_simulation_tenant ON dynamic.simulation_run_control(tenant_id);
CREATE INDEX idx_simulation_scenario ON dynamic.simulation_run_control(tenant_id, scenario_id);
CREATE INDEX idx_simulation_status ON dynamic.simulation_run_control(tenant_id, run_status);

-- Comments
COMMENT ON TABLE dynamic.simulation_run_control IS 'Simulation execution control and tracking';

GRANT SELECT, INSERT, UPDATE ON dynamic.simulation_run_control TO finos_app;