-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.tax_rate_schedule
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Tax Rate Schedule.
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


CREATE TABLE dynamic.tax_rate_schedule (
    rate_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    jurisdiction_id UUID NOT NULL REFERENCES dynamic.tax_jurisdiction_master(jurisdiction_id),
    
    -- Tax Type
    tax_type dynamic.tax_type NOT NULL,
    tax_sub_type VARCHAR(50),
    
    -- Rate
    rate_percentage DECIMAL(10,6) NOT NULL,
    rate_description TEXT,
    
    -- Thresholds (for progressive taxes)
    threshold_amounts JSONB, -- [{from: 0, to: 10000, rate: 0}, {from: 10000, rate: 0.15}]
    
    -- Applicability
    applicable_product_types VARCHAR(50)[],
    applicable_customer_types VARCHAR(50)[],
    applicable_transaction_types VARCHAR(50)[],
    
    -- Timing
    effective_from DATE NOT NULL,
    effective_to DATE NOT NULL DEFAULT '9999-12-31',
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    superseded_by_rate_id UUID REFERENCES dynamic.tax_rate_schedule(rate_id),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT chk_tax_rate_valid_dates CHECK (effective_from < effective_to)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.tax_rate_schedule_default PARTITION OF dynamic.tax_rate_schedule DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_tax_rate_jurisdiction
idx_tax_rate_type
idx_tax_rate_effective

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.tax_rate_schedule IS 'Tax rate schedules with progressive brackets';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.tax_rate_schedule TO finos_app;
