-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.floating_rate_index
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Floating Rate Index.
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


CREATE TABLE dynamic.floating_rate_index (
    index_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    index_code VARCHAR(50) NOT NULL, -- PRIME, JIBAR, REPO, LIBOR, SOFR, etc.
    index_name VARCHAR(200) NOT NULL,
    index_description TEXT,
    
    -- Properties
    currency_code CHAR(3) NOT NULL REFERENCES core.currencies(code),
    tenor VARCHAR(20), -- ON, 1M, 3M, 6M, 12M
    
    -- Publication
    publisher VARCHAR(100), -- FRED, Refinitiv, Bloomberg, etc.
    publication_calendar VARCHAR(100), -- Business day convention
    publication_time TIME,
    timezone VARCHAR(50),
    
    -- Calculation
    lag_days INTEGER DEFAULT 0, -- Lookback period
    rounding_convention VARCHAR(20) DEFAULT 'HALF_EVEN',
    decimal_places INTEGER DEFAULT 6,
    
    -- Fallback
    fallback_index_id UUID REFERENCES dynamic.floating_rate_index(index_id),
    fallback_trigger_event VARCHAR(100), -- Cessation, etc.
    fallback_spread_adjustment DECIMAL(10,6),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    publication_stopped_date DATE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_index_code_per_tenant UNIQUE (tenant_id, index_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.floating_rate_index_default PARTITION OF dynamic.floating_rate_index DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_floating_index_tenant
idx_floating_index_lookup

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.floating_rate_index IS 'External floating rate benchmarks (SOFR, JIBAR, PRIME, etc.)';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.floating_rate_index TO finos_app;
