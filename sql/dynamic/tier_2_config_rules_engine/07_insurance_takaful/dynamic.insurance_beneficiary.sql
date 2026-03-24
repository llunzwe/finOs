-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 07 - Insurance Takaful
-- TABLE: dynamic.insurance_beneficiary
-- COMPLIANCE: IFRS 17
--   - Solvency II
--   - AAOIFI
--   - IAIS
-- ============================================================================


CREATE TABLE dynamic.insurance_beneficiary (

    beneficiary_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    policy_id UUID NOT NULL REFERENCES dynamic.insurance_policy_master(policy_id) ON DELETE CASCADE,
    
    -- Beneficiary Details
    beneficiary_name VARCHAR(200) NOT NULL,
    beneficiary_type VARCHAR(20) DEFAULT 'INDIVIDUAL' 
        CHECK (beneficiary_type IN ('INDIVIDUAL', 'ENTITY', 'ESTATE', 'TRUST')),
    relationship VARCHAR(50),
    
    -- Identification
    identification_type VARCHAR(50),
    identification_number VARCHAR(100),
    date_of_birth DATE,
    
    -- Allocation
    allocation_percentage DECIMAL(5,4) NOT NULL CHECK (allocation_percentage BETWEEN 0 AND 1),
    succession_order INTEGER DEFAULT 1, -- 1=Primary, 2=Contingent
    
    -- Contact
    contact_address TEXT,
    contact_phone VARCHAR(50),
    contact_email VARCHAR(255),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.insurance_beneficiary_default PARTITION OF dynamic.insurance_beneficiary DEFAULT;

-- Indexes
CREATE INDEX idx_beneficiary_policy ON dynamic.insurance_beneficiary(tenant_id, policy_id);

-- Comments
COMMENT ON TABLE dynamic.insurance_beneficiary IS 'Policy nominees and beneficiaries';

GRANT SELECT, INSERT, UPDATE ON dynamic.insurance_beneficiary TO finos_app;