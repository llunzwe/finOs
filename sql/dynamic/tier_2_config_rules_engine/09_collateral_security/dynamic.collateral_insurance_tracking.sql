-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 09 - Collateral Security
-- TABLE: dynamic.collateral_insurance_tracking
-- COMPLIANCE: Basel III
--   - UNCITRAL
--   - LMA
--   - CMA
-- ============================================================================


CREATE TABLE dynamic.collateral_insurance_tracking (

    insurance_tracking_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    collateral_id UUID NOT NULL REFERENCES dynamic.collateral_master(collateral_id),
    
    -- Policy Details
    policy_number VARCHAR(100) NOT NULL,
    insurer_name VARCHAR(200) NOT NULL,
    insurer_reference VARCHAR(100),
    
    -- Coverage
    coverage_type VARCHAR(50) NOT NULL, -- FIRE, THEFT, COMPREHENSIVE, etc.
    coverage_amount DECIMAL(28,8) NOT NULL,
    coverage_currency CHAR(3) NOT NULL,
    
    -- Dates
    policy_start_date DATE NOT NULL,
    policy_end_date DATE NOT NULL,
    
    -- Premium
    premium_amount DECIMAL(28,8),
    premium_frequency VARCHAR(20),
    
    -- Lien
    bank_noted_as_loss_payee BOOLEAN DEFAULT TRUE,
    loss_payee_details TEXT,
    
    -- Status
    policy_status VARCHAR(20) DEFAULT 'ACTIVE' 
        CHECK (policy_status IN ('ACTIVE', 'EXPIRED', 'CANCELLED', 'CLAIM_PENDING')),
    
    -- Documents
    policy_document_url VARCHAR(500),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.collateral_insurance_tracking_default PARTITION OF dynamic.collateral_insurance_tracking DEFAULT;

-- Indexes
CREATE INDEX idx_insurance_collateral ON dynamic.collateral_insurance_tracking(tenant_id, collateral_id);
CREATE INDEX idx_insurance_expiry ON dynamic.collateral_insurance_tracking(tenant_id, policy_end_date) WHERE policy_status = 'ACTIVE';

-- Comments
COMMENT ON TABLE dynamic.collateral_insurance_tracking IS 'Insurance coverage tracking for collateral assets';

GRANT SELECT, INSERT, UPDATE ON dynamic.collateral_insurance_tracking TO finos_app;