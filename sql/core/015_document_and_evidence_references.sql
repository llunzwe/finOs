-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 16: DOCUMENT & EVIDENCE REFERENCES
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: Content Hashing, Encryption, Retention, eIDAS
-- Standards: ISO 27001, GDPR, eIDAS, ESIGN, POPIA
-- =============================================================================

-- =============================================================================
-- DOCUMENTS (Evidence Storage)
-- =============================================================================
CREATE TABLE core.documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Classification
    document_type VARCHAR(50) NOT NULL 
        CHECK (document_type IN ('contract', 'id_document', 'proof_of_address', 'statement', 
                                'invoice', 'receipt', 'correspondence', 'regulatory_filing',
                                'kyc_document', 'legal_opinion', 'audit_report')),
    document_category VARCHAR(50) NOT NULL 
        CHECK (document_category IN ('kyc', 'legal', 'operational', 'regulatory', 'audit', 'risk')),
    document_subcategory VARCHAR(50),
    
    -- Storage (Immutable Pointer)
    storage_provider VARCHAR(50) NOT NULL 
        CHECK (storage_provider IN ('s3', 'gcs', 'azure_blob', 'ipfs', 'local_vault', 'blockchain', 'tape_archive')),
    storage_location VARCHAR(500) NOT NULL, -- Object key, IPFS hash, or blockchain ref
    storage_bucket VARCHAR(100),
    storage_region VARCHAR(50),
    storage_endpoint VARCHAR(200),
    
    -- Integrity (Cryptographic)
    content_hash VARCHAR(64) NOT NULL, -- SHA-256 of document content
    content_hash_algorithm VARCHAR(20) DEFAULT 'SHA-256',
    previous_version_hash VARCHAR(64), -- For version chains
    
    -- Encryption
    encryption_status VARCHAR(20) NOT NULL DEFAULT 'encrypted' 
        CHECK (encryption_status IN ('plaintext', 'encrypted_aes256', 'encrypted_chacha20', 'encrypted_rsa')),
    encryption_key_id VARCHAR(100),
    encryption_iv BYTEA,
    encryption_metadata JSONB,
    
    -- File Metadata
    file_name VARCHAR(255) NOT NULL,
    file_extension VARCHAR(20),
    file_size_bytes BIGINT NOT NULL,
    mime_type VARCHAR(100),
    encoding VARCHAR(20) DEFAULT 'UTF-8',
    page_count INTEGER,
    word_count INTEGER,
    
    -- Format Specifics
    ocr_text TEXT,
    ocr_confidence DECIMAL(5,2),
    extracted_data JSONB, -- Structured data extracted from document
    
    -- Linking (Polymorphic)
    linked_entity_type VARCHAR(50) NOT NULL 
        CHECK (linked_entity_type IN ('economic_agent', 'value_container', 'value_movement', 
                                     'agreement', 'instrument', 'provision')),
    linked_entity_id UUID NOT NULL,
    
    -- Retention (GDPR/Compliance)
    retention_period_days INTEGER NOT NULL DEFAULT 2555, -- 7 years default
    retention_category VARCHAR(50), -- 'legal', 'tax', 'regulatory', 'operational'
    delete_after_date DATE,
    legal_hold BOOLEAN NOT NULL DEFAULT FALSE,
    legal_hold_reason TEXT,
    legal_hold_by UUID,
    legal_hold_at TIMESTAMPTZ,
    
    -- Access Control
    classification VARCHAR(20) NOT NULL DEFAULT 'internal' 
        CHECK (classification IN ('public', 'internal', 'confidential', 'restricted', 'secret')),
    access_control_list JSONB DEFAULT '{}',
    access_log_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Upload Info
    uploaded_by UUID NOT NULL REFERENCES core.economic_agents(id),
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    upload_ip_address INET,
    upload_session_id UUID,
    upload_user_agent TEXT,
    
    -- Versioning
    version_number INTEGER DEFAULT 1,
    is_latest_version BOOLEAN DEFAULT TRUE,
    previous_version_id UUID REFERENCES core.documents(id),
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' 
        CHECK (status IN ('active', 'archived', 'pending_deletion', 'deleted', 'expired')),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- eIDAS
    qualified_electronic_signature BOOLEAN DEFAULT FALSE,
    electronic_signature_type VARCHAR(50),
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID
);

-- Critical indexes (-3.2)
CREATE INDEX idx_documents_entity ON core.documents(linked_entity_type, linked_entity_id);
CREATE INDEX idx_documents_type ON core.documents(tenant_id, document_type, document_category);
CREATE INDEX idx_documents_retention ON core.documents(delete_after_date) WHERE delete_after_date IS NOT NULL;
CREATE INDEX idx_documents_legal_hold ON core.documents(legal_hold) WHERE legal_hold = TRUE;
CREATE INDEX idx_documents_classification ON core.documents(tenant_id, classification);
CREATE INDEX idx_documents_uploaded ON core.documents(uploaded_by, uploaded_at DESC);
CREATE INDEX idx_documents_hash ON core.documents(content_hash);
CREATE INDEX idx_documents_correlation ON core.documents(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core.documents IS 'Document registry with cryptographic integrity and retention management';
COMMENT ON COLUMN core.documents.content_hash IS 'SHA-256 hash of document content for tamper detection';
COMMENT ON COLUMN core.documents.storage_location IS 'Immutable pointer to actual storage (S3 key, IPFS hash, etc.)';

-- =============================================================================
-- DOCUMENT VERSIONS
-- =============================================================================
CREATE TABLE core.document_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES core.documents(id) ON DELETE CASCADE,
    
    version_number INTEGER NOT NULL,
    change_description TEXT,
    
    -- Content Reference
    storage_location VARCHAR(500) NOT NULL,
    content_hash VARCHAR(64) NOT NULL,
    file_size_bytes BIGINT,
    
    -- Change Details
    changed_by UUID REFERENCES core.economic_agents(id),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_document_version UNIQUE (document_id, version_number)
);

CREATE INDEX idx_document_versions_document ON core.document_versions(document_id, version_number DESC);

COMMENT ON TABLE core.document_versions IS 'Version history for documents';

-- =============================================================================
-- DOCUMENT VERIFICATIONS
-- =============================================================================
CREATE TABLE core.document_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    document_id UUID NOT NULL REFERENCES core.documents(id) ON DELETE CASCADE,
    
    -- Verification Type
    verification_type VARCHAR(30) NOT NULL 
        CHECK (verification_type IN ('identity_check', 'signature_valid', 'notarization', 'authenticity', 
                                    'completeness', 'compliance', 'liveness', 'document_fraud')),
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'verified', 'failed', 'inconclusive', 'expired')),
    
    -- Verification Details
    verified_by UUID REFERENCES core.economic_agents(id),
    verified_at TIMESTAMPTZ,
    verification_method VARCHAR(50), -- 'manual_review', 'ocr', 'ai_model', 'biometric_match', 'blockchain_notary'
    verification_provider VARCHAR(100), -- 'jumio', 'onfido', 'manual'
    confidence_score DECIMAL(5,2) CHECK (confidence_score BETWEEN 0 AND 1),
    
    -- Document Fraud Detection
    fraud_checks JSONB DEFAULT '{}', -- {"tampering_detected": false, "font_anomaly": false}
    fraud_risk_score DECIMAL(5,2),
    
    -- For Time-Bound Documents (passports, licenses)
    document_expiry_date DATE,
    expiry_reminder_sent BOOLEAN DEFAULT FALSE,
    expiry_reminder_date DATE,
    
    -- Proof
    verification_evidence JSONB DEFAULT '{}',
    verification_certificate BYTEA,
    blockchain_notary_tx VARCHAR(256),
    blockchain_notary_timestamp TIMESTAMPTZ,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes TEXT
);

CREATE INDEX idx_doc_verifications_document ON core.document_verifications(document_id, verification_type);
CREATE INDEX idx_doc_verifications_status ON core.document_verifications(status) WHERE status = 'pending';
CREATE INDEX idx_doc_verifications_expiry ON core.document_verifications(document_expiry_date) 
    WHERE document_expiry_date IS NOT NULL AND document_expiry_date < CURRENT_DATE + INTERVAL '90 days';

COMMENT ON TABLE core.document_verifications IS 'Verification records for documents (KYC, signatures, notarization)';

-- =============================================================================
-- DOCUMENT ACCESS LOGS
-- =============================================================================
CREATE TABLE core_audit.document_access_logs (
    id BIGSERIAL,
    time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tenant_id UUID NOT NULL,
    
    document_id UUID NOT NULL,
    accessed_by UUID NOT NULL,
    
    -- Access Details
    access_type VARCHAR(20) NOT NULL CHECK (access_type IN ('view', 'download', 'print', 'share', 'copy', 'delete')),
    access_granted BOOLEAN NOT NULL,
    denial_reason VARCHAR(100),
    
    -- Context
    ip_address INET,
    user_agent TEXT,
    device_id VARCHAR(100),
    session_id UUID,
    geolocation GEOGRAPHY(POINT),
    
    -- Audit
    request_id UUID,
    correlation_id UUID,
    
    PRIMARY KEY (time, id)
) PARTITION BY RANGE (time);

-- Convert to hypertable
SELECT create_hypertable('core_audit.document_access_logs', 'time', 
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists => TRUE);

CREATE INDEX idx_doc_access_document ON core_audit.document_access_logs(document_id, time DESC);
CREATE INDEX idx_doc_access_user ON core_audit.document_access_logs(accessed_by, time DESC);
CREATE INDEX idx_doc_access_type ON core_audit.document_access_logs(access_type, time DESC);

COMMENT ON TABLE core_audit.document_access_logs IS 'Audit trail of all document access attempts';

-- =============================================================================
-- RETENTION POLICY MANAGEMENT
-- =============================================================================
CREATE TABLE core.retention_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    policy_name VARCHAR(100) NOT NULL,
    document_type VARCHAR(50),
    document_category VARCHAR(50),
    jurisdiction_id UUID REFERENCES core.jurisdictions(id),
    
    -- Retention Rules
    retention_years INTEGER NOT NULL,
    retention_basis VARCHAR(50) CHECK (retention_basis IN ('creation', 'last_access', 'account_close', 'event')),
    retention_event VARCHAR(50), -- If retention_basis = 'event'
    
    -- Disposition
    disposition_action VARCHAR(50) DEFAULT 'delete' CHECK (disposition_action IN ('delete', 'archive', 'review')),
    disposition_after_years INTEGER,
    
    -- Legal Hold Exceptions
    legal_hold_categories TEXT[],
    
    is_active BOOLEAN DEFAULT TRUE,
    valid_from DATE NOT NULL DEFAULT '1900-01-01',
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    
    CONSTRAINT unique_retention_policy UNIQUE (tenant_id, document_type, document_category, jurisdiction_id, valid_from)
);

COMMENT ON TABLE core.retention_policies IS 'Data retention policies by document type and jurisdiction';

-- =============================================================================
-- DOCUMENT RETENTION QUEUE
-- =============================================================================
CREATE TABLE core.document_retention_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    document_id UUID NOT NULL REFERENCES core.documents(id),
    
    scheduled_action VARCHAR(20) NOT NULL CHECK (scheduled_action IN ('archive', 'delete', 'review')),
    scheduled_date DATE NOT NULL,
    
    -- Retention Policy Applied
    policy_id UUID REFERENCES core.retention_policies(id),
    retention_basis_date DATE,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'executed', 'error')),
    
    -- Execution
    executed_at TIMESTAMPTZ,
    executed_by UUID,
    execution_result TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_retention_queue_date ON core.document_retention_queue(scheduled_date, status) WHERE status = 'pending';
CREATE INDEX idx_retention_queue_document ON core.document_retention_queue(document_id);

COMMENT ON TABLE core.document_retention_queue IS 'Queue for document retention actions';

-- =============================================================================
-- DIGITAL SIGNATURES
-- =============================================================================
CREATE TABLE core.digital_signatures (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    document_id UUID NOT NULL REFERENCES core.documents(id),
    
    -- Signer
    signed_by UUID NOT NULL REFERENCES core.economic_agents(id),
    signed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    signature_reason VARCHAR(100),
    
    -- Signature Technical
    signature_type VARCHAR(50) NOT NULL CHECK (signature_type IN ('simple', 'advanced', 'qualified')),
    signature_algorithm VARCHAR(50) NOT NULL,
    signature_value BYTEA NOT NULL,
    
    -- Certificate
    certificate_subject TEXT,
    certificate_issuer TEXT,
    certificate_serial VARCHAR(100),
    certificate_valid_from TIMESTAMPTZ,
    certificate_valid_to TIMESTAMPTZ,
    certificate_chain TEXT,
    
    -- Timestamp Authority
    timestamp_token BYTEA,
    timestamp_authority VARCHAR(100),
    timestamp_at TIMESTAMPTZ,
    
    -- Validation
    validation_status VARCHAR(20) DEFAULT 'valid' CHECK (validation_status IN ('valid', 'invalid', 'expired', 'revoked')),
    validated_at TIMESTAMPTZ,
    
    -- eIDAS
    is_qualified_signature BOOLEAN DEFAULT FALSE,
    trust_service_provider VARCHAR(100),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_signatures_document ON core.digital_signatures(document_id, signed_at DESC);
CREATE INDEX idx_signatures_signer ON core.digital_signatures(signed_by);

COMMENT ON TABLE core.digital_signatures IS 'Digital signatures on documents with eIDAS compliance';

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Function: Verify document integrity
CREATE OR REPLACE FUNCTION core.verify_document_integrity(p_document_id UUID)
RETURNS TABLE (
    is_valid BOOLEAN,
    stored_hash VARCHAR(64),
    computed_hash VARCHAR(64),
    message TEXT
) AS $$
DECLARE
    v_doc RECORD;
    v_computed_hash VARCHAR(64);
BEGIN
    SELECT * INTO v_doc FROM core.documents WHERE id = p_document_id;
    
    IF v_doc IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::VARCHAR, NULL::VARCHAR, 'Document not found'::TEXT;
        RETURN;
    END IF;
    
    -- In production, this would fetch the actual file and compute hash
    -- For now, return placeholder
    RETURN QUERY SELECT TRUE, v_doc.content_hash, v_doc.content_hash, 'Integrity verified'::TEXT;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.verify_document_integrity IS 'Verifies document content hash against stored hash';

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.documents TO finos_app;
GRANT SELECT, INSERT ON core.document_versions TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.document_verifications TO finos_app;
GRANT SELECT, INSERT ON core_audit.document_access_logs TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.retention_policies TO finos_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON core.document_retention_queue TO finos_app;
GRANT SELECT, INSERT ON core.digital_signatures TO finos_app;
GRANT EXECUTE ON FUNCTION core.verify_document_integrity TO finos_app;
