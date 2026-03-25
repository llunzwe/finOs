-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 15 - Documents & Evidence
-- TABLE: dynamic.signature_algorithm_configs
--
-- DESCRIPTION:
--   Digital signature algorithm configuration.
--   Configures eIDAS-compliant signature methods.
--
-- CORE DEPENDENCY: 015_document_and_evidence_references.sql
--
-- COMPLIANCE:
--   - eIDAS Regulation (EU 910/2014)
--   - ESIGN Act (US)
--   - UETA (US)
--
-- ============================================================================

CREATE TABLE dynamic.signature_algorithm_configs (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Algorithm Identification
    algorithm_code VARCHAR(100) NOT NULL,
    algorithm_name VARCHAR(200) NOT NULL,
    algorithm_description TEXT,
    
    -- Technical Specs
    signature_type VARCHAR(50) NOT NULL, -- 'AES', 'QES', 'QEA', 'ELECTRONIC'
    signature_standard VARCHAR(50) NOT NULL, -- 'PKCS7', 'XML_DSIG', 'JSON_JWS', 'PDF_PAdES'
    hash_algorithm VARCHAR(20) NOT NULL DEFAULT 'SHA-256', -- SHA-256, SHA-384, SHA-512
    encryption_algorithm VARCHAR(50), -- RSA, ECDSA, Ed25519
    key_length_bits INTEGER DEFAULT 2048,
    
    -- Certificate Requirements
    requires_certificate BOOLEAN DEFAULT TRUE,
    certificate_authority VARCHAR(200),
    certificate_type VARCHAR(50), -- 'SOFTWARE', 'HSM', 'QSCD'
    certificate_validity_days INTEGER DEFAULT 365,
    
    -- eIDAS Level
    eidas_level VARCHAR(20), -- 'ELECTRONIC', 'ADVANCED', 'QUALIFIED'
    eidas_legal_effect BOOLEAN DEFAULT FALSE,
    
    -- Document Types
    applicable_document_types VARCHAR(100)[], -- 'CONTRACT', 'STATEMENT', 'MANDATE'
    
    -- Timestamping
    requires_timestamp BOOLEAN DEFAULT TRUE,
    timestamp_authority VARCHAR(200),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_signature_algorithm_code UNIQUE (tenant_id, algorithm_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.signature_algorithm_configs_default PARTITION OF dynamic.signature_algorithm_configs DEFAULT;

CREATE INDEX idx_signature_algorithm_type ON dynamic.signature_algorithm_configs(tenant_id, signature_type) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.signature_algorithm_configs IS 'Digital signature algorithm configuration for eIDAS-compliant signatures. Tier 2 Low-Code';

CREATE TRIGGER trg_signature_algorithm_configs_audit
    BEFORE UPDATE ON dynamic.signature_algorithm_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.signature_algorithm_configs TO finos_app;
