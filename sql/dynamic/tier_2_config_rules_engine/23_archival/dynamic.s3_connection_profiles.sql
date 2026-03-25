-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 23 - Columnar Archival
-- TABLE: dynamic.s3_connection_profiles
--
-- DESCRIPTION:
--   S3 connection profile configuration for archival.
--   Configures cloud storage endpoints, credentials, and bucket settings.
--
-- CORE DEPENDENCY: 023_columnar_archival.sql
--
-- ============================================================================

CREATE TABLE dynamic.s3_connection_profiles (
    profile_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Profile Identification
    profile_code VARCHAR(100) NOT NULL,
    profile_name VARCHAR(200) NOT NULL,
    profile_description TEXT,
    
    -- Provider Configuration
    provider VARCHAR(50) NOT NULL, -- 'AWS', 'AZURE', 'GCP', 'MINIO', 'WASABI'
    endpoint_url VARCHAR(500), -- For non-AWS S3-compatible stores
    region VARCHAR(50),
    
    -- Bucket Configuration
    bucket_name VARCHAR(100) NOT NULL,
    bucket_prefix VARCHAR(200) DEFAULT 'finos/',
    storage_class VARCHAR(50) DEFAULT 'STANDARD', -- STANDARD, IA, GLACIER, etc.
    
    -- Authentication
    auth_type VARCHAR(50) DEFAULT 'IAM_ROLE', -- IAM_ROLE, ACCESS_KEY, STS_ASSUME_ROLE
    access_key_id VARCHAR(100), -- Encrypted
    secret_access_key VARCHAR(200), -- Encrypted
    iam_role_arn VARCHAR(500),
    
    -- Security
    encryption_enabled BOOLEAN DEFAULT TRUE,
    encryption_type VARCHAR(50) DEFAULT 'SSE-S3', -- SSE-S3, SSE-KMS, SSE-C
    kms_key_id VARCHAR(500),
    
    -- Transfer Settings
    multipart_upload_threshold_mb INTEGER DEFAULT 100,
    max_concurrent_uploads INTEGER DEFAULT 10,
    transfer_acceleration BOOLEAN DEFAULT FALSE,
    
    -- Retention
    lifecycle_policy_enabled BOOLEAN DEFAULT TRUE,
    transition_to_ia_days INTEGER,
    transition_to_glacier_days INTEGER,
    expiration_days INTEGER,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    last_connection_test_at TIMESTAMPTZ,
    connection_test_status VARCHAR(20), -- SUCCESS, FAILED
    
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
    
    CONSTRAINT unique_s3_profile_code UNIQUE (tenant_id, profile_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.s3_connection_profiles_default PARTITION OF dynamic.s3_connection_profiles DEFAULT;

CREATE INDEX idx_s3_profile_provider ON dynamic.s3_connection_profiles(tenant_id, provider) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.s3_connection_profiles IS 'S3 connection profile configuration for cloud archival storage. Tier 2 Low-Code';

CREATE TRIGGER trg_s3_connection_profiles_audit
    BEFORE UPDATE ON dynamic.s3_connection_profiles
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.s3_connection_profiles TO finos_app;
