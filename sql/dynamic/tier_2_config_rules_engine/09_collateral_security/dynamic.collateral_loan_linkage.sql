-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 09 - Collateral Security
-- TABLE: dynamic.collateral_loan_linkage
-- COMPLIANCE: Basel III
--   - UNCITRAL
--   - LMA
--   - CMA
-- ============================================================================


CREATE TABLE dynamic.collateral_loan_linkage (

    linkage_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    collateral_id UUID NOT NULL REFERENCES dynamic.collateral_master(collateral_id),
    loan_container_id UUID NOT NULL REFERENCES core.value_containers(id),
    
    -- Linkage Details
    linkage_type VARCHAR(20) DEFAULT 'PRIMARY' 
        CHECK (linkage_type IN ('PRIMARY', 'ADDITIONAL', 'CROSS_COLLATERAL')),
    coverage_percentage DECIMAL(5,4) DEFAULT 1.0, -- Portion of collateral pledged
    
    -- Coverage Amount
    maximum_liability_amount DECIMAL(28,8),
    currency_code CHAR(3) NOT NULL,
    
    -- Status
    linkage_status VARCHAR(20) DEFAULT 'ACTIVE' 
        CHECK (linkage_status IN ('ACTIVE', 'RELEASED', 'ENFORCED')),
    
    -- Dates
    linked_date DATE NOT NULL DEFAULT CURRENT_DATE,
    released_date DATE,
    release_reason TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    
    CONSTRAINT unique_collateral_loan_link UNIQUE (tenant_id, collateral_id, loan_container_id)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.collateral_loan_linkage_default PARTITION OF dynamic.collateral_loan_linkage DEFAULT;

-- Indexes
CREATE INDEX idx_collateral_loan ON dynamic.collateral_loan_linkage(tenant_id, loan_container_id) WHERE linkage_status = 'ACTIVE';
CREATE INDEX idx_collateral_link ON dynamic.collateral_loan_linkage(tenant_id, collateral_id) WHERE linkage_status = 'ACTIVE';

-- Comments
COMMENT ON TABLE dynamic.collateral_loan_linkage IS 'Links collateral to loan accounts with coverage details';

GRANT SELECT, INSERT, UPDATE ON dynamic.collateral_loan_linkage TO finos_app;