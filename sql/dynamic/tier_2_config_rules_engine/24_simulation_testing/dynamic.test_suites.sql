-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 24 - Simulation Testing
-- TABLE: dynamic.test_suites
-- COMPLIANCE: ISTQB
--   - Basel
--   - SOX
--   - ITIL
-- ============================================================================


CREATE TABLE dynamic.test_suites (

    suite_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Suite Identity
    suite_name VARCHAR(200) NOT NULL,
    suite_description TEXT,
    suite_type VARCHAR(50) NOT NULL 
        CHECK (suite_type IN ('UNIT', 'INTEGRATION', 'E2E', 'REGRESSION', 'PERFORMANCE', 'SECURITY')),
    
    -- Scope
    test_scope JSONB DEFAULT '{}',
    -- Example: {
    --   apis: ['posting', 'authorization'],
    --   products: ['credit_card', 'debit_card'],
    --   features: ['jit_funding', 'velocity_limits']
    -- }
    
    -- Configuration
    config_jsonb JSONB DEFAULT '{}',
    -- Example: {
    --   parallel_execution: true,
    --   max_concurrent_tests: 10,
    --   timeout_seconds: 30,
    --   retry_failed: true
    -- }
    
    -- Status
    status VARCHAR(20) DEFAULT 'draft' 
        CHECK (status IN ('draft', 'active', 'deprecated')),
    
    -- Execution Stats
    last_run_at TIMESTAMPTZ,
    last_run_status VARCHAR(20),
    last_run_duration_ms INTEGER,
    
    total_runs INTEGER DEFAULT 0,
    success_rate DECIMAL(5,2), -- Percentage
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.test_suites_default PARTITION OF dynamic.test_suites DEFAULT;

-- Indexes
CREATE INDEX idx_test_suites_tenant ON dynamic.test_suites(tenant_id, status) WHERE status = 'active';

-- Comments
COMMENT ON TABLE dynamic.test_suites IS 
    'Marqeta Simulations 2.0 + Vault simulator + Postman-compatible test suites';

-- Triggers
CREATE TRIGGER trg_test_suites_update
    BEFORE UPDATE ON dynamic.test_suites
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_simulation_testing_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.test_suites TO finos_app;