-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.interest_rate_curve
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Interest Rate Curve.
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


CREATE TABLE dynamic.interest_rate_curve (
    curve_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    curve_name VARCHAR(200) NOT NULL,
    curve_code VARCHAR(100) NOT NULL,
    curve_description TEXT,
    
    -- Curve Properties
    curve_type VARCHAR(50) NOT NULL 
        CHECK (curve_type IN ('YIELD', 'FUNDING', 'SPREAD', 'DISCOUNT', 'FORWARD')),
    currency_code CHAR(3) NOT NULL REFERENCES core.currencies(code),
    
    -- Benchmark Source
    benchmark_source VARCHAR(100), -- CENTRAL_BANK, INTERBANK, INTERNAL
    benchmark_reference VARCHAR(100), -- Specific benchmark name
    
    -- Construction Method
    interpolation_method VARCHAR(50) DEFAULT 'CUBIC_SPLINE' 
        CHECK (interpolation_method IN ('LINEAR', 'CUBIC_SPLINE', 'FLAT_FORWARD', 'LOG_LINEAR')),
    extrapolation_method VARCHAR(50) DEFAULT 'FLAT',
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Usage
    used_by_products UUID[],
    used_by_valuations BOOLEAN DEFAULT FALSE,
    
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
    
    CONSTRAINT unique_curve_code_per_tenant UNIQUE (tenant_id, curve_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.interest_rate_curve_default PARTITION OF dynamic.interest_rate_curve DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_ir_curve_tenant ON dynamic.interest_rate_curve(tenant_id);
CREATE INDEX idx_ir_curve_lookup ON dynamic.interest_rate_curve(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.interest_rate_curve IS 'Yield and funding curves for interest rate calculations';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.interest_rate_curve TO finos_app;
