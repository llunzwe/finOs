-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 08 - Customer Management
-- TABLE: dynamic.customer_relationship_map
-- COMPLIANCE: FATF
--   - GDPR/POPIA
--   - KYC
--   - CDD
--   - AML/CFT
-- ============================================================================


CREATE TABLE dynamic.customer_relationship_map (

    relationship_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    primary_customer_id UUID NOT NULL,
    related_customer_id UUID NOT NULL,
    
    -- Relationship Type
    relationship_type VARCHAR(50) NOT NULL 
        CHECK (relationship_type IN ('SPOUSE', 'PARENT', 'CHILD', 'SIBLING', 'SUBSIDIARY', 'PARENT_COMPANY', 'GUARANTOR', 'DIRECTOR', 'BENEFICIAL_OWNER', 'AUTHORIZED_SIGNATORY', 'EMPLOYEE')),
    relationship_description TEXT,
    
    -- Share/Ownership
    share_percentage DECIMAL(5,4),
    voting_percentage DECIMAL(5,4),
    
    -- Effective Period
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    verified BOOLEAN DEFAULT FALSE,
    
    -- Source
    source_document_id UUID REFERENCES dynamic.kyc_document_repository(document_id),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    
    CONSTRAINT unique_relationship UNIQUE (tenant_id, primary_customer_id, related_customer_id, relationship_type)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.customer_relationship_map_default PARTITION OF dynamic.customer_relationship_map DEFAULT;

-- Indexes
CREATE INDEX idx_relationship_primary ON dynamic.customer_relationship_map(tenant_id, primary_customer_id) WHERE is_active = TRUE;
CREATE INDEX idx_relationship_related ON dynamic.customer_relationship_map(tenant_id, related_customer_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.customer_relationship_map IS 'Customer relationship graph for group exposure';

-- Triggers
CREATE TRIGGER trg_customer_relationship_audit
    BEFORE UPDATE ON dynamic.customer_relationship_map
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.customer_relationship_map TO finos_app;