-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 24 - Simulation Testing
-- TABLE: dynamic.test_cases
-- COMPLIANCE: ISTQB
--   - Basel
--   - SOX
--   - ITIL
-- ============================================================================


CREATE TABLE dynamic.test_cases (

    case_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    suite_id UUID NOT NULL REFERENCES dynamic.test_suites(suite_id),
    
    -- Test Identity
    test_name VARCHAR(200) NOT NULL,
    test_description TEXT,
    priority VARCHAR(20) DEFAULT 'medium' 
        CHECK (priority IN ('critical', 'high', 'medium', 'low')),
    
    -- Test Definition
    test_type VARCHAR(50) NOT NULL 
        CHECK (test_type IN ('API', 'CONTRACT', 'SQL', 'PERFORMANCE', 'SECURITY_SCAN')),
    
    -- Request/Action
    request_config JSONB NOT NULL DEFAULT '{}',
    -- API: {method: 'POST', endpoint: '/auth', body: {...}, headers: {...}}
    -- SQL: {query: 'SELECT ...', expected_result: [...]}
    -- Contract: {contract_id: '...', entry_point: 'onDebit', params: {...}}
    
    -- Expected Result
    expected_result JSONB NOT NULL DEFAULT '{}',
    -- {status_code: 200, response_contains: {...}, assertions: [...]}
    
    -- Pre/Post Conditions
    pre_conditions JSONB DEFAULT '[]',
    post_conditions JSONB DEFAULT '[]',
    
    -- Test Data
    test_data_jsonb JSONB DEFAULT '{}',
    -- {accounts: [...], cards: [...], balances: {...}}
    
    -- Dependencies
    depends_on UUID[], -- Other test cases that must pass first
    
    -- Execution
    execution_order INTEGER DEFAULT 0,
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.test_cases_default PARTITION OF dynamic.test_cases DEFAULT;

-- Indexes
CREATE INDEX idx_test_cases_suite ON dynamic.test_cases(tenant_id, suite_id, execution_order);

-- Triggers
CREATE TRIGGER trg_test_cases_update
    BEFORE UPDATE ON dynamic.test_cases
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_simulation_testing_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.test_cases TO finos_app;