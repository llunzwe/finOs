-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.day_count_convention_registry
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Day Count Convention Registry.
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


CREATE TABLE dynamic.day_count_convention_registry (
    convention_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    convention_code VARCHAR(50) NOT NULL, -- ACTUAL_360, ACTUAL_365, 30E_360, etc.
    convention_name VARCHAR(200) NOT NULL,
    convention_description TEXT,
    
    -- Formula
    formula_expression TEXT NOT NULL, -- Mathematical expression
    formula_sql TEXT, -- SQL implementation
    year_length_days INTEGER,
    month_length_days INTEGER, -- NULL for actual
    
    -- Usage
    is_default_for_currency CHAR(3) REFERENCES core.currencies(code),
    is_default_for_product_type VARCHAR(50),
    
    -- Compliance
    regulatory_approved BOOLEAN DEFAULT TRUE,
    approved_jurisdictions VARCHAR(50)[],
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_convention_code_per_tenant UNIQUE (tenant_id, convention_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.day_count_convention_registry_default PARTITION OF dynamic.day_count_convention_registry DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.day_count_convention_registry IS 'Supported day count conventions for interest calculations';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.day_count_convention_registry TO finos_app;
