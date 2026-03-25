-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Identity & Tenancy
-- TABLE: dynamic.tenant_encryption_policies
--
-- DESCRIPTION:
--   Tenant-specific encryption policy configuration.
--   Configures field-level encryption, key rotation, and data classification.
--   Maps to core.tenant_configs encryption settings.
--
-- CORE DEPENDENCY: 001_identity_and_tenancy.sql
--
-- COMPLIANCE:
--   - GDPR Article 32 (Security of processing)
--   - PCI-DSS (Cardholder data encryption)
--   - SOX (Data protection)
--
-- ============================================================================

CREATE TABLE dynamic.tenant_encryption_policies (
    policy_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Policy Identification
    policy_code VARCHAR(100) NOT NULL,
    policy_name VARCHAR(200) NOT NULL,
    policy_description TEXT,
    
    -- Encryption Scope
    applicable_schemas VARCHAR(100)[], -- 'core', 'dynamic', 'core_crypto'
    applicable_tables VARCHAR(100)[],
    applicable_columns VARCHAR(200)[], -- table.column format
    
    -- Encryption Configuration
    encryption_algorithm VARCHAR(50) DEFAULT 'AES-256-GCM',
    key_derivation_method VARCHAR(50) DEFAULT 'PBKDF2',
    key_rotation_days INTEGER DEFAULT 90,
    
    -- Data Classification
    data_classification VARCHAR(50) NOT NULL, -- 'PII', 'FINANCIAL', 'HEALTH', 'CONFIDENTIAL', 'PUBLIC'
    encryption_required BOOLEAN DEFAULT TRUE,
    
    -- Key Management
    key_storage_type VARCHAR(50) DEFAULT 'HSM', -- HSM, KMS, VAULT, FILE
    key_reference VARCHAR(500), -- Key ID or path
    key_version INTEGER DEFAULT 1,
    
    -- Field-Level Encryption
    encrypt_at_rest BOOLEAN DEFAULT TRUE,
    encrypt_in_transit BOOLEAN DEFAULT TRUE,
    encrypt_in_use BOOLEAN DEFAULT FALSE, -- Homomorphic encryption for computation
    
    -- Tokenization (for PII)
    use_tokenization BOOLEAN DEFAULT FALSE,
    tokenization_format VARCHAR(50), -- 'RANDOM', 'DETERMINISTIC', 'FORMAT_PRESERVING'
    
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
    
    CONSTRAINT unique_encryption_policy_code UNIQUE (tenant_id, policy_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.tenant_encryption_policies_default PARTITION OF dynamic.tenant_encryption_policies DEFAULT;

CREATE INDEX idx_encryption_policy_classification ON dynamic.tenant_encryption_policies(tenant_id, data_classification) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.tenant_encryption_policies IS 'Tenant-specific encryption policies for field-level data protection. Tier 2 Low-Code';

CREATE TRIGGER trg_tenant_encryption_policies_audit
    BEFORE UPDATE ON dynamic.tenant_encryption_policies
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.tenant_encryption_policies TO finos_app;
