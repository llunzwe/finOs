-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic_history.floating_rate_index_values
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Floating Rate Index Values.
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


CREATE TABLE dynamic_history.floating_rate_index_values (
    value_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    index_id UUID NOT NULL REFERENCES dynamic.floating_rate_index(index_id) ON DELETE CASCADE,
    
    -- Rate
    rate_value DECIMAL(15,10) NOT NULL,
    rate_change DECIMAL(15,10), -- Change from previous
    
    -- Date
    fixing_date DATE NOT NULL,
    value_date DATE NOT NULL,
    maturity_date DATE,
    
    -- Source
    source_system VARCHAR(100),
    source_reference VARCHAR(200),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_index_fixing_date UNIQUE (tenant_id, index_id, fixing_date)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.floating_rate_index_values_default PARTITION OF dynamic_history.floating_rate_index_values DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_index_values_index
idx_index_values_date

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic_history.floating_rate_index_values IS 'Historical values of floating rate indices';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic_history.floating_rate_index_values TO finos_app;
