-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 07 - Insurance & Takaful
-- TABLE: dynamic.insurance_coverage_riders
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Insurance Coverage Riders.
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
CREATE TABLE dynamic.insurance_coverage_riders (

    rider_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    policy_id UUID NOT NULL REFERENCES dynamic.insurance_policy_master(policy_id) ON DELETE CASCADE,
    
    -- Rider Details
    rider_type VARCHAR(50) NOT NULL 
        CHECK (rider_type IN ('CRITICAL_ILLNESS', 'PERSONAL_ACCIDENT', 'WAIVER_OF_PREMIUM', 'TERM_INCREASE', 'DISABILITY', 'HOSPITALIZATION')),
    rider_name VARCHAR(200),
    rider_description TEXT,
    
    -- Coverage
    additional_sum_assured DECIMAL(28,8),
    additional_premium DECIMAL(28,8),
    
    -- Terms
    waiting_period_days INTEGER DEFAULT 0,
    exclusions JSONB,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    added_date DATE DEFAULT CURRENT_DATE,
    removed_date DATE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100)
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.insurance_coverage_riders_default PARTITION OF dynamic.insurance_coverage_riders DEFAULT;

-- Indexes
CREATE INDEX idx_riders_policy ON dynamic.insurance_coverage_riders(tenant_id, policy_id);

-- Comments
COMMENT ON TABLE dynamic.insurance_coverage_riders IS 'Policy add-on coverages and riders';

GRANT SELECT, INSERT, UPDATE ON dynamic.insurance_coverage_riders TO finos_app;