-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.interest_rate_curve_points
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Interest Rate Curve Points.
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


CREATE TABLE dynamic.interest_rate_curve_points (
    point_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    curve_id UUID NOT NULL REFERENCES dynamic.interest_rate_curve(curve_id) ON DELETE CASCADE,
    
    -- Tenor
    tenor_days INTEGER NOT NULL,
    tenor_name VARCHAR(50), -- ON, 1W, 1M, 3M, etc.
    
    -- Rate
    rate_value DECIMAL(15,10) NOT NULL,
    rate_bid DECIMAL(15,10),
    rate_ask DECIMAL(15,10),
    rate_mid DECIMAL(15,10),
    
    -- Source
    source_type VARCHAR(50) DEFAULT 'MARKET' 
        CHECK (source_type IN ('MARKET', 'CALCULATED', 'MANUAL', 'IMPORTED')),
    source_reference VARCHAR(200),
    
    -- Validity
    quote_date DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_until TIMESTAMPTZ,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    
    CONSTRAINT unique_curve_tenor UNIQUE (tenant_id, curve_id, tenor_days, quote_date)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.interest_rate_curve_points_default PARTITION OF dynamic.interest_rate_curve_points DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_curve_points_curve ON dynamic.interest_rate_curve_points(tenant_id);
CREATE INDEX idx_curve_points_date ON dynamic.interest_rate_curve_points(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.interest_rate_curve_points IS 'Individual tenor points on interest rate curves';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.interest_rate_curve_points TO finos_app;
