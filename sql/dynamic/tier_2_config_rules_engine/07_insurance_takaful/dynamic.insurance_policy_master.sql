-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 07 - Insurance Takaful
-- TABLE: dynamic.insurance_policy_master
-- COMPLIANCE: IFRS 17
--   - Solvency II
--   - AAOIFI
--   - IAIS
-- ============================================================================


CREATE TABLE dynamic.insurance_policy_master (

    policy_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Policy Identification
    policy_number VARCHAR(100) NOT NULL,
    policy_code VARCHAR(100),
    
    -- Product Reference
    product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id),
    
    -- Parties
    policyholder_id UUID NOT NULL, -- Reference to customer
    agent_id UUID, -- Selling agent
    branch_id UUID,
    
    -- Dates
    inception_date DATE NOT NULL,
    expiry_date DATE,
    renewal_date DATE,
    cancellation_date DATE,
    
    -- Coverage
    sum_assured DECIMAL(28,8) NOT NULL,
    coverage_type dynamic.coverage_type NOT NULL,
    coverage_details JSONB,
    
    -- Premium
    premium_amount DECIMAL(28,8) NOT NULL,
    premium_frequency dynamic.premium_frequency NOT NULL,
    modal_premium DECIMAL(28,8), -- Adjusted for frequency
    
    -- Status
    policy_status VARCHAR(20) DEFAULT 'IN_FORCE' 
        CHECK (policy_status IN ('IN_FORCE', 'LAPSED', 'PAID_UP', 'SURRENDERED', 'MATURED', 'CANCELLED', 'EXPIRED')),
    
    -- Underwriting
    underwriting_decision dynamic.underwriting_level DEFAULT 'STANDARD',
    loading_percentage DECIMAL(10,6), -- Extra premium for risk
    exclusion_clauses JSONB,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_policy_number UNIQUE (tenant_id, policy_number)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.insurance_policy_master_default PARTITION OF dynamic.insurance_policy_master DEFAULT;

-- Indexes
CREATE INDEX idx_policy_tenant ON dynamic.insurance_policy_master(tenant_id);
CREATE INDEX idx_policy_holder ON dynamic.insurance_policy_master(tenant_id, policyholder_id);
CREATE INDEX idx_policy_status ON dynamic.insurance_policy_master(tenant_id, policy_status);
CREATE INDEX idx_policy_expiry ON dynamic.insurance_policy_master(expiry_date) WHERE policy_status = 'IN_FORCE';

-- Comments
COMMENT ON TABLE dynamic.insurance_policy_master IS 'Insurance policy header with lifecycle status';

-- Triggers
CREATE TRIGGER trg_insurance_policy_audit
    BEFORE UPDATE ON dynamic.insurance_policy_master
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.insurance_policy_master TO finos_app;