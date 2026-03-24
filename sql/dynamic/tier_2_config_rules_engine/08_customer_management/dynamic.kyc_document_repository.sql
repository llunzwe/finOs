-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 08 - Customer Management
-- TABLE: dynamic.kyc_document_repository
-- COMPLIANCE: FATF
--   - GDPR/POPIA
--   - KYC
--   - CDD
--   - AML/CFT
-- ============================================================================


CREATE TABLE dynamic.kyc_document_repository (

    document_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    customer_id UUID NOT NULL,
    
    -- Document Details
    document_type VARCHAR(50) NOT NULL, -- ID, PROOF_OF_ADDRESS, INCOME, etc.
    document_sub_type VARCHAR(50), -- PASSPORT, DRIVERS_LICENSE, etc.
    document_number VARCHAR(100),
    
    -- Issuer
    issuing_authority VARCHAR(200),
    issuing_country CHAR(2),
    
    -- Dates
    issue_date DATE,
    expiry_date DATE,
    
    -- Storage
    document_url VARCHAR(500),
    document_hash VARCHAR(64), -- SHA-256 of file
    encrypted_storage BOOLEAN DEFAULT FALSE,
    
    -- Verification
    verification_status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (verification_status IN ('PENDING', 'VERIFIED', 'REJECTED', 'EXPIRED')),
    verified_by VARCHAR(100),
    verified_at TIMESTAMPTZ,
    verification_method VARCHAR(50), -- MANUAL, OCR, THIRD_PARTY_API
    verification_notes TEXT,
    
    -- OCR Data
    extracted_data JSONB,
    ocr_confidence_score DECIMAL(5,4),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_active_doc UNIQUE (tenant_id, customer_id, document_type, verification_status) WHERE verification_status IN ('PENDING', 'VERIFIED')

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.kyc_document_repository_default PARTITION OF dynamic.kyc_document_repository DEFAULT;

-- Indexes
CREATE INDEX idx_kyc_doc_customer ON dynamic.kyc_document_repository(tenant_id, customer_id);
CREATE INDEX idx_kyc_doc_expiry ON dynamic.kyc_document_repository(tenant_id, expiry_date) WHERE verification_status = 'VERIFIED';
CREATE INDEX idx_kyc_doc_status ON dynamic.kyc_document_repository(tenant_id, verification_status);

-- Comments
COMMENT ON TABLE dynamic.kyc_document_repository IS 'Customer KYC document tracking with verification status';

-- Triggers
CREATE TRIGGER trg_kyc_document_audit
    BEFORE UPDATE ON dynamic.kyc_document_repository
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.kyc_document_repository TO finos_app;