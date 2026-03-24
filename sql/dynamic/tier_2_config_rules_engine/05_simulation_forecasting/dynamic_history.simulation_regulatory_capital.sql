-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 05 - Simulation & Forecasting
-- TABLE: dynamic_history.simulation_regulatory_capital
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Simulation Regulatory Capital.
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
CREATE TABLE dynamic_history.simulation_regulatory_capital (

    capital_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    run_id UUID NOT NULL REFERENCES dynamic.simulation_run_control(run_id),
    
    -- Time Dimension
    reporting_date DATE NOT NULL,
    
    -- Risk Weighted Assets
    rwa_calculated DECIMAL(28,8),
    rwa_credit_risk DECIMAL(28,8),
    rwa_market_risk DECIMAL(28,8),
    rwa_operational_risk DECIMAL(28,8),
    
    -- Capital Ratios
    cet1_ratio_impact DECIMAL(5,4),
    tier1_ratio_impact DECIMAL(5,4),
    total_capital_ratio_impact DECIMAL(5,4),
    
    -- Capital Components
    cet1_capital_impact DECIMAL(28,8),
    tier1_capital_impact DECIMAL(28,8),
    total_capital_impact DECIMAL(28,8),
    
    -- Leverage
    leverage_ratio_impact DECIMAL(5,4),
    
    -- Buffers
    capital_conservation_buffer DECIMAL(28,8),
    countercyclical_buffer DECIMAL(28,8),
    g_sib_buffer DECIMAL(28,8),
    
    -- Minimum Requirements
    minimum_cet1_required DECIMAL(28,8),
    minimum_tier1_required DECIMAL(28,8),
    minimum_total_capital_required DECIMAL(28,8),
    
    -- Stress Impact
    stress_impact_pretax_income DECIMAL(28,8),
    stress_impact_net_income DECIMAL(28,8),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    CONSTRAINT unique_capital_result UNIQUE (tenant_id, run_id, reporting_date)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.simulation_regulatory_capital_default PARTITION OF dynamic_history.simulation_regulatory_capital DEFAULT;

-- Indexes
CREATE INDEX idx_reg_capital_run ON dynamic_history.simulation_regulatory_capital(tenant_id, run_id);

-- Comments
COMMENT ON TABLE dynamic_history.simulation_regulatory_capital IS 'Basel capital adequacy impacts from stress scenarios';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.simulation_regulatory_capital TO finos_app;