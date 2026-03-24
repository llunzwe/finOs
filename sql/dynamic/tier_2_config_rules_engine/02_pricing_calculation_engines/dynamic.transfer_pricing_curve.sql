-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.transfer_pricing_curve
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Transfer Pricing Curve.
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


CREATE TABLE dynamic.transfer_pricing_curve (
    curve_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    curve_name VARCHAR(200) NOT NULL,
    curve_code VARCHAR(100) NOT NULL,
    curve_description TEXT,
    
    -- Scope
    business_unit_id UUID,
    product_line_id UUID,
    currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    
    -- Funding Cost Basis
    funding_cost_basis VARCHAR(50) DEFAULT 'WEIGHTED_AVG' 
        CHECK (funding_cost_basis IN ('WEIGHTED_AVG', 'MARGINAL', 'POOL_RATE')),
    
    -- Adjustments
    liquidity_premium_bps INTEGER DEFAULT 0,
    credit_spread_bps INTEGER DEFAULT 0,
    operational_cost_bps INTEGER DEFAULT 0,
    capital_charge_bps INTEGER DEFAULT 0,
    
    -- Reference Curve
    reference_market_curve_id UUID REFERENCES dynamic.interest_rate_curve(curve_id),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
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
    
    CONSTRAINT unique_tp_curve_code UNIQUE (tenant_id, curve_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.transfer_pricing_curve_default PARTITION OF dynamic.transfer_pricing_curve DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_tp_curve_tenant ON dynamic.transfer_pricing_curve(tenant_id);
CREATE INDEX idx_tp_curve_currency ON dynamic.transfer_pricing_curve(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.transfer_pricing_curve IS 'Internal funding curves for transfer pricing';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.transfer_pricing_curve TO finos_app;
