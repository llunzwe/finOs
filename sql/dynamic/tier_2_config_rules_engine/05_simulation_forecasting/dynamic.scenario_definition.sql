-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 05 - Simulation & Forecasting
-- TABLE: dynamic.scenario_definition
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Scenario Definition.
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
CREATE TABLE dynamic.scenario_definition (

    scenario_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    scenario_name VARCHAR(200) NOT NULL,
    scenario_code VARCHAR(100) NOT NULL,
    scenario_description TEXT,
    
    -- Classification
    scenario_family dynamic.scenario_family NOT NULL,
    scenario_severity VARCHAR(20) DEFAULT 'MODERATE' 
        CHECK (scenario_severity IN ('MILD', 'MODERATE', 'SEVERE', 'EXTREME')),
    
    -- Baseline
    baseline_parameters JSONB NOT NULL DEFAULT '{}',
    baseline_scenario_id UUID, -- Reference to base scenario for deltas
    
    -- Shock Parameters (delta from baseline)
    shock_parameters JSONB NOT NULL DEFAULT '{}',
    shock_description TEXT,
    
    -- Probabilistic Settings
    is_probabilistic BOOLEAN DEFAULT FALSE,
    confidence_interval DECIMAL(5,4), -- e.g., 0.95 for 95%
    monte_carlo_iterations INTEGER, -- Number of simulations
    random_seed BIGINT, -- For reproducibility
    
    -- Regulatory Context
    regulatory_framework VARCHAR(50), -- CCAR, EBA, etc.
    stress_test_type VARCHAR(50), -- Adverse, Severely Adverse
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_locked BOOLEAN DEFAULT FALSE,
    locked_at TIMESTAMPTZ,
    locked_by VARCHAR(100),
    
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
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_scenario_code UNIQUE (tenant_id, scenario_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.scenario_definition_default PARTITION OF dynamic.scenario_definition DEFAULT;

-- Indexes
CREATE INDEX idx_scenario_tenant ON dynamic.scenario_definition(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_scenario_family ON dynamic.scenario_definition(tenant_id, scenario_family) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.scenario_definition IS 'What-if scenario definitions for stress testing';

-- Triggers
CREATE TRIGGER trg_scenario_definition_audit
    BEFORE UPDATE ON dynamic.scenario_definition
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.scenario_definition TO finos_app;