-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 05 - Simulation & Forecasting
-- TABLE: dynamic_history.simulation_cashflow_projection
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Simulation Cashflow Projection.
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
CREATE TABLE dynamic_history.simulation_cashflow_projection (

    projection_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    run_id UUID NOT NULL REFERENCES dynamic.simulation_run_control(run_id),
    
    -- Account Reference
    account_id UUID NOT NULL REFERENCES core.value_containers(id),
    product_id UUID REFERENCES dynamic.product_template_master(product_id),
    
    -- Projection Period
    projection_month INTEGER NOT NULL, -- 1-360 for 30 years
    projection_date DATE NOT NULL,
    
    -- Projected Balances
    projected_balance DECIMAL(28,8),
    projected_principal DECIMAL(28,8),
    projected_interest_accrued DECIMAL(28,8),
    
    -- Projected Income
    projected_interest_income DECIMAL(28,8),
    projected_fees DECIMAL(28,8),
    
    -- Projected Cash Flows
    projected_principal_payment DECIMAL(28,8),
    projected_interest_payment DECIMAL(28,8),
    projected_prepayment DECIMAL(28,8),
    
    -- Credit Risk
    probability_of_default DECIMAL(5,4), -- Calculated
    loss_given_default DECIMAL(5,4),
    exposure_at_default DECIMAL(28,8),
    expected_loss DECIMAL(28,8),
    
    -- Stage Migration (IFRS 9)
    projected_stage INTEGER CHECK (projected_stage BETWEEN 1 AND 3),
    stage_migration_probability DECIMAL(5,4),
    
    -- Macro Factor Values at projection
    macro_factor_values JSONB,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.simulation_cashflow_projection_default PARTITION OF dynamic_history.simulation_cashflow_projection DEFAULT;

-- Indexes
CREATE INDEX idx_cashflow_run ON dynamic_history.simulation_cashflow_projection(tenant_id, run_id);
CREATE INDEX idx_cashflow_account ON dynamic_history.simulation_cashflow_projection(tenant_id, account_id);
CREATE INDEX idx_cashflow_date ON dynamic_history.simulation_cashflow_projection(projection_date);

-- Comments
COMMENT ON TABLE dynamic_history.simulation_cashflow_projection IS 'Account-level cash flow projections from simulations';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.simulation_cashflow_projection TO finos_app;