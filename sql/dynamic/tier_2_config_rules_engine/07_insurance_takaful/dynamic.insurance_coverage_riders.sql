-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 07 - Insurance Takaful
-- TABLE: dynamic.insurance_coverage_riders
-- COMPLIANCE: IFRS 17
--   - Solvency II
--   - AAOIFI
--   - IAIS
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

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.insurance_coverage_riders_default PARTITION OF dynamic.insurance_coverage_riders DEFAULT;

-- Indexes
CREATE INDEX idx_riders_policy ON dynamic.insurance_coverage_riders(tenant_id, policy_id);

-- Comments
COMMENT ON TABLE dynamic.insurance_coverage_riders IS 'Policy add-on coverages and riders';

GRANT SELECT, INSERT, UPDATE ON dynamic.insurance_coverage_riders TO finos_app;