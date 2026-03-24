-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 09 - Collateral Security
-- TABLE: dynamic.collateral_master
-- COMPLIANCE: Basel III
--   - UNCITRAL
--   - LMA
--   - CMA
-- ============================================================================


CREATE TABLE dynamic.collateral_master (

    collateral_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    collateral_reference VARCHAR(100) NOT NULL,
    collateral_description TEXT,
    
    -- Type
    collateral_type_id UUID NOT NULL REFERENCES dynamic.collateral_type_master(collateral_type_id),
    
    -- Owner
    owner_id UUID NOT NULL, -- Customer who owns the collateral
    owner_reference VARCHAR(100),
    
    -- Details (Type-specific)
    collateral_details JSONB, -- Varies by type: {property_address: '...', vehicle_reg: '...', etc.}
    
    -- Location
    location_address TEXT,
    location_country CHAR(2),
    custody_location VARCHAR(200),
    custody_reference VARCHAR(100),
    
    -- Status
    collateral_status VARCHAR(20) DEFAULT 'AVAILABLE' 
        CHECK (collateral_status IN ('AVAILABLE', 'PLEDGED', 'RELEASED', 'LIQUIDATED', 'INSURED', 'IN_TRANSIT')),
    
    -- Insurance
    insurance_policy_number VARCHAR(100),
    insurance_expiry_date DATE,
    insurance_coverage_amount DECIMAL(28,8),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_collateral_ref UNIQUE (tenant_id, collateral_reference)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.collateral_master_default PARTITION OF dynamic.collateral_master DEFAULT;

-- Indexes
CREATE INDEX idx_collateral_tenant ON dynamic.collateral_master(tenant_id);
CREATE INDEX idx_collateral_owner ON dynamic.collateral_master(tenant_id, owner_id);
CREATE INDEX idx_collateral_status ON dynamic.collateral_master(tenant_id, collateral_status);
CREATE INDEX idx_collateral_type ON dynamic.collateral_master(tenant_id, collateral_type_id);

-- Comments
COMMENT ON TABLE dynamic.collateral_master IS 'Collateral asset register';

-- Triggers
CREATE TRIGGER trg_collateral_master_audit
    BEFORE UPDATE ON dynamic.collateral_master
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.collateral_master TO finos_app;