-- =============================================================================
-- FINOS CORE KERNEL - PII REGISTRY & DATA PROTECTION
-- =============================================================================
-- File: 003_pii_registry.sql
-- Description: Personally Identifiable Information registry for GDPR compliance
-- Standards: GDPR Article 30, ISO 27001
-- =============================================================================

-- SECTION 6: PII REGISTRY & DATA PROTECTION
-- =============================================================================

CREATE TABLE core.pii_registry (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    column_path TEXT NOT NULL UNIQUE,
    table_name TEXT NOT NULL,
    column_name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('IDENTITY','CONTACT','FINANCIAL','BIOMETRIC','SENSITIVE','AUTHENTICATION')),
    retention_interval INTERVAL,
    encrypted BOOLEAN DEFAULT true,
    masking_required BOOLEAN DEFAULT true,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100)
);

CREATE INDEX idx_pii_registry_table ON core.pii_registry(table_name);
CREATE INDEX idx_pii_registry_category ON core.pii_registry(category);

COMMENT ON TABLE core.pii_registry IS 'Registry of all PII fields for GDPR compliance and encryption tracking';

-- Function to register PII fields
CREATE OR REPLACE FUNCTION core.register_pii_field(
    p_table TEXT,
    p_column TEXT,
    p_category TEXT,
    p_retention INTERVAL DEFAULT NULL,
    p_encrypted BOOLEAN DEFAULT true
)
RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO core.pii_registry (
        column_path, table_name, column_name, category, 
        retention_interval, encrypted, created_by
    ) VALUES (
        format('%s.%s', p_table, p_column),
        p_table, p_column, p_category,
        p_retention, p_encrypted,
        current_setting('app.current_user', TRUE)
    )
    ON CONFLICT (column_path) DO UPDATE SET
        category = EXCLUDED.category,
        retention_interval = EXCLUDED.retention_interval,
        encrypted = EXCLUDED.encrypted,
        updated_at = NOW()
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Encryption/Hash functions with PII registration
CREATE OR REPLACE FUNCTION core.encrypt_data(
    p_data TEXT,
    p_key TEXT
) RETURNS BYTEA AS $$
BEGIN
    RETURN pgp_sym_encrypt(p_data, p_key, 'cipher-algo=aes256');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION core.decrypt_data(
    p_encrypted BYTEA,
    p_key TEXT
) RETURNS TEXT AS $$
BEGIN
    RETURN pgp_sym_decrypt(p_encrypted, p_key);
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION core.hash_data(
    p_data TEXT,
    p_algorithm TEXT DEFAULT 'sha256'
) RETURNS TEXT AS $$
BEGIN
    RETURN encode(digest(p_data, p_algorithm), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION core.encrypt_data IS 'Encrypts data using AES-256 symmetric encryption';
COMMENT ON FUNCTION core.decrypt_data IS 'Decrypts data using symmetric encryption';
COMMENT ON FUNCTION core.hash_data IS 'Creates cryptographic hash of data';

-- Data Masking with Production Guard
CREATE OR REPLACE FUNCTION core.mask_pii(p_value TEXT)
RETURNS TEXT AS $$
BEGIN
    -- Production guard: masking forbidden in production
    IF core.get_environment() IN ('production','prod','live') THEN
        RAISE EXCEPTION 'Data masking is forbidden in production environment. Current environment: %', core.get_environment();
    END IF;
    
    -- Return masked value with hash suffix for reference
    RETURN 'MASKED_' || substr(encode(digest(p_value,'sha256'),'hex'),1,8);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION core.mask_email(p_email TEXT)
RETURNS TEXT AS $$
DECLARE
    v_parts TEXT[];
BEGIN
    IF core.get_environment() IN ('production','prod','live') THEN
        RAISE EXCEPTION 'Data masking is forbidden in production environment';
    END IF;
    
    v_parts := string_to_array(p_email, '@');
    IF array_length(v_parts, 1) = 2 THEN
        RETURN substr(v_parts[1], 1, 2) || '***@' || v_parts[2];
    END IF;
    RETURN core.mask_pii(p_email);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION core.mask_phone(p_phone TEXT)
RETURNS TEXT AS $$
BEGIN
    IF core.get_environment() IN ('production','prod','live') THEN
        RAISE EXCEPTION 'Data masking is forbidden in production environment';
    END IF;
    
    RETURN '***-***-' || substr(p_phone, -4);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION core.mask_pii IS 'Masks PII data with production environment guard';

-- =============================================================================
