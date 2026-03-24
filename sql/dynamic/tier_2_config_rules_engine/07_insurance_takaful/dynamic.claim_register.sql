-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 07 - Insurance Takaful
-- TABLE: dynamic.claim_register
-- COMPLIANCE: IFRS 17
--   - Solvency II
--   - AAOIFI
--   - IAIS
-- ============================================================================


CREATE TABLE dynamic.claim_register (

    claim_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Claim Identification
    claim_number VARCHAR(100) NOT NULL,
    
    -- Policy Reference
    policy_id UUID NOT NULL REFERENCES dynamic.insurance_policy_master(policy_id),
    
    -- Claim Details
    claim_type dynamic.claim_type NOT NULL,
    claim_description TEXT,
    
    -- Dates
    incident_date DATE,
    claim_date DATE NOT NULL,
    reported_date DATE NOT NULL,
    
    -- Amounts
    claim_amount_requested DECIMAL(28,8) NOT NULL,
    claim_amount_approved DECIMAL(28,8),
    claim_amount_paid DECIMAL(28,8),
    
    -- Status
    claim_status dynamic.claim_status DEFAULT 'REGISTERED',
    status_reason TEXT,
    
    -- Workflow
    assigned_adjuster_id UUID,
    assigned_at TIMESTAMPTZ,
    
    -- Fraud
    fraud_score DECIMAL(5,4),
    fraud_flags JSONB,
    referred_to_investigation BOOLEAN DEFAULT FALSE,
    
    -- Settlement
    settlement_date DATE,
    settlement_method VARCHAR(50),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    CONSTRAINT unique_claim_number UNIQUE (tenant_id, claim_number)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.claim_register_default PARTITION OF dynamic.claim_register DEFAULT;

-- Indexes
CREATE INDEX idx_claim_tenant ON dynamic.claim_register(tenant_id);
CREATE INDEX idx_claim_policy ON dynamic.claim_register(tenant_id, policy_id);
CREATE INDEX idx_claim_status ON dynamic.claim_register(tenant_id, claim_status);
CREATE INDEX idx_claim_date ON dynamic.claim_register(claim_date DESC);

-- Comments
COMMENT ON TABLE dynamic.claim_register IS 'Insurance claim header with status tracking';

GRANT SELECT, INSERT, UPDATE ON dynamic.claim_register TO finos_app;