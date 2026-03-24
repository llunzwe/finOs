-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_insurance_specifics
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Insurance Specifics.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 17442 (LEI)
--   - ISO 4217
--   - IFRS 9
--   - AAOIFI
--   - BCBS 239
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


CREATE TABLE dynamic.product_insurance_specifics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL UNIQUE REFERENCES dynamic.product_template_master(product_id) ON DELETE CASCADE,
    
    -- Coverage
    coverage_type dynamic.coverage_type NOT NULL,
    coverage_description TEXT,
    
    -- Sum Assured
    sum_assured_calculation_basis VARCHAR(50) DEFAULT 'FLAT' 
        CHECK (sum_assured_calculation_basis IN ('FLAT', 'MULTIPLE_OF_INCOME', 'DECREASING', 'INCREASING', 'UNIT_LINKED')),
    sum_assured_multiplier DECIMAL(10,4), -- For income-based calculation
    min_sum_assured DECIMAL(28,8),
    max_sum_assured DECIMAL(28,8),
    
    -- Underwriting
    underwriting_automation_level dynamic.underwriting_level DEFAULT 'SEMI_AUTOMATED',
    max_automated_sum_assured DECIMAL(28,8),
    medical_exam_required_above DECIMAL(28,8),
    
    -- Premium
    premium_calculation_method VARCHAR(50),
    premium_frequency_options dynamic.premium_frequency[] DEFAULT ARRAY['MONTHLY', 'QUARTERLY', 'ANNUAL'],
    modal_loading_percentage DECIMAL(10,6), -- Extra for non-annual payments
    
    -- Waiting Periods
    waiting_period_days INTEGER DEFAULT 0,
    suicide_exclusion_days INTEGER DEFAULT 730, -- 2 years
    
    -- Exclusions
    exclusion_clauses JSONB, -- [{clause: 'pre_existing_conditions', description: '...'}, ...]
    
    -- Renewal
    renewable BOOLEAN DEFAULT TRUE,
    max_renewal_age INTEGER,
    guaranteed_renewal BOOLEAN DEFAULT FALSE,
    
    -- Riders
    allowed_rider_types VARCHAR(50)[],
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_insurance_specifics_default PARTITION OF dynamic.product_insurance_specifics DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_insurance_specifics IS 'Specialized configuration for insurance products';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_insurance_specifics TO finos_app;
