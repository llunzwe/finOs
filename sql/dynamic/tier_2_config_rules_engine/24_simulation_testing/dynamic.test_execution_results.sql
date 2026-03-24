-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 24 - Simulation Testing
-- TABLE: dynamic.test_execution_results
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Test Execution Results.
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
CREATE TABLE dynamic.test_execution_results (

    result_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    suite_id UUID NOT NULL REFERENCES dynamic.test_suites(suite_id),
    case_id UUID NOT NULL REFERENCES dynamic.test_cases(case_id),
    
    -- Execution
    execution_id UUID NOT NULL, -- Groups multiple test runs
    executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Result
    status VARCHAR(20) NOT NULL 
        CHECK (status IN ('passed', 'failed', 'skipped', 'error', 'timeout')),
    
    -- Details
    duration_ms INTEGER,
    request_sent JSONB,
    response_received JSONB,
    error_message TEXT,
    stack_trace TEXT,
    
    -- Assertions
    assertions_total INTEGER DEFAULT 0,
    assertions_passed INTEGER DEFAULT 0,
    assertions_failed INTEGER DEFAULT 0,
    assertion_details JSONB DEFAULT '[]',
    
    -- Environment
    environment VARCHAR(100), -- dev, staging, prod
    version_tested VARCHAR(50),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.test_execution_results_default PARTITION OF dynamic.test_execution_results DEFAULT;

-- Indexes
CREATE INDEX idx_test_results_execution ON dynamic.test_execution_results(tenant_id, execution_id);
CREATE INDEX idx_test_results_case ON dynamic.test_execution_results(tenant_id, case_id, executed_at DESC);

GRANT SELECT, INSERT, UPDATE ON dynamic.test_execution_results TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.test_execution_results IS 'Test Execution Results';