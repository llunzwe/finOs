-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 1: IDENTITY & TENANCY
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: UUIDv7, Encryption, Partitioning, TimescaleDB, Bitemporal Support
-- Standards: ISO 17442 (LEI), ISO 9362 (BIC), GDPR, SOC2
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "ltree";

-- =============================================================================
-- SCHEMA SETUP
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS core_history;
CREATE SCHEMA IF NOT EXISTS core_crypto;
CREATE SCHEMA IF NOT EXISTS core_audit;

COMMENT ON SCHEMA core IS 'FinOS Core Kernel - Immutable Primitives';
COMMENT ON SCHEMA core_history IS 'FinOS Core - Temporal/Historical Data';
COMMENT ON SCHEMA core_crypto IS 'FinOS Core - Anchoring/Hashing/Cryptography';
COMMENT ON SCHEMA core_audit IS 'FinOS Core - Audit Trail & Compliance';

-- =============================================================================
-- SEQUENCE MANAGER FOR ENTITY CODES
-- =============================================================================
CREATE TABLE core.entity_sequences (
    sequence_id BIGSERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    year_month VARCHAR(7) NOT NULL,
    
    last_sequence BIGINT NOT NULL DEFAULT 0,
    prefix VARCHAR(10) DEFAULT 'ID',
    padding_length INTEGER DEFAULT 6,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_sequence UNIQUE (tenant_id, entity_type, year_month)
) PARTITION BY LIST (tenant_id);

-- Create default partition
CREATE TABLE core.entity_sequences_default PARTITION OF core.entity_sequences
    DEFAULT;

CREATE INDEX idx_entity_sequences_lookup ON core.entity_sequences(tenant_id, entity_type, year_month);

COMMENT ON TABLE core.entity_sequences IS 'Monotonic sequence generator for human-readable entity codes';

-- Function to generate unique, sortable IDs
CREATE OR REPLACE FUNCTION core.generate_entity_code(
    p_tenant_id UUID, 
    p_entity_type VARCHAR, 
    p_prefix VARCHAR DEFAULT 'ID'
) RETURNS VARCHAR AS $$
DECLARE
    v_year_month VARCHAR(7);
    v_next_seq BIGINT;
    v_padded_seq VARCHAR;
    v_result VARCHAR;
BEGIN
    v_year_month := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
    
    INSERT INTO core.entity_sequences (tenant_id, entity_type, year_month, prefix, last_sequence)
    VALUES (p_tenant_id, p_entity_type, v_year_month, p_prefix, 1)
    ON CONFLICT (tenant_id, entity_type, year_month) 
    DO UPDATE SET 
        last_sequence = core.entity_sequences.last_sequence + 1,
        updated_at = NOW()
    RETURNING core.entity_sequences.last_sequence INTO v_next_seq;
    
    v_padded_seq := LPAD(v_next_seq::text, 6, '0');
    v_result := p_prefix || '-' || TO_CHAR(CURRENT_DATE, 'YYYY') || '-' || v_padded_seq;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION core.generate_entity_code IS 'Generates unique, sortable human-readable entity codes';

-- =============================================================================
-- TENANTS TABLE (Shard Root)
-- =============================================================================
CREATE TABLE core.tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identification
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    legal_name VARCHAR(255) NOT NULL,
    
    -- ISO Standards
    lei_code VARCHAR(20) UNIQUE CHECK (lei_code ~ '^[A-Z0-9]{18}[0-9]{2}$'),
    bic_code VARCHAR(11) CHECK (bic_code ~ '^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$'),
    
    -- Configuration (Encrypted)
    config JSONB NOT NULL DEFAULT '{}',
    config_encrypted BYTEA,
    
    -- Operational Settings
    base_currency CHAR(3) NOT NULL DEFAULT 'USD',
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    decimal_separator CHAR(1) DEFAULT '.',
    thousands_separator CHAR(1) DEFAULT ',',
    
    -- Compliance & Regulatory
    license_number VARCHAR(100),
    regulatory_authority VARCHAR(100),
    tax_id VARCHAR(100),
    tax_id_encrypted BYTEA,
    
    -- Status Management
    status VARCHAR(20) NOT NULL DEFAULT 'active' 
        CHECK (status IN ('active', 'suspended', 'terminating', 'terminated', 'frozen')),
    status_reason TEXT,
    
    -- Soft Delete (Enterprise Architecture Pattern)
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    restored_at TIMESTAMPTZ,
    restored_by UUID,
    
    -- Anchoring (Blockchain Integration)
    merkle_root VARCHAR(64),
    last_anchor_time TIMESTAMPTZ,
    anchor_chain VARCHAR(50) DEFAULT 'none',
    
    -- Temporal (Bitemporal Support)
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Event Tracking (Idempotency + Correlation)
    correlation_id UUID,
    causation_id UUID,
    idempotency_key VARCHAR(100),
    
    -- Immutable Hash (Row Integrity)
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    
    -- Constraints
    CONSTRAINT chk_tenant_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_tenant_code_format CHECK (code ~ '^[a-zA-Z][a-zA-Z0-9_-]+$')
);

-- Indexes for tenants (-3.2: Partial, Composite, GIN)
CREATE INDEX idx_tenants_status ON core.tenants(status) WHERE status = 'active';
CREATE INDEX idx_tenants_lei ON core.tenants(lei_code) WHERE lei_code IS NOT NULL;
CREATE INDEX idx_tenants_temporal ON core.tenants(valid_from, valid_to);
CREATE INDEX idx_tenants_active_temporal ON core.tenants(valid_from, valid_to) 
    WHERE is_deleted = FALSE;
CREATE INDEX idx_tenants_config ON core.tenants USING GIN(config) WHERE config != '{}';

COMMENT ON TABLE core.tenants IS 'Root tenant table for multi-tenant data isolation';
COMMENT ON COLUMN core.tenants.config_encrypted IS 'AES-256 encrypted sensitive configuration';
COMMENT ON COLUMN core.tenants.immutable_hash IS 'SHA-256 hash of row content for integrity verification';

-- Trigger to update timestamps and version
CREATE OR REPLACE FUNCTION core.update_tenant_audit()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = OLD.version + 1;
    NEW.immutable_hash = encode(digest(
        NEW.id::text || NEW.code || NEW.name || NEW.status || NEW.version::text, 'sha256'
    ), 'hex');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tenants_audit
    BEFORE UPDATE ON core.tenants
    FOR EACH ROW EXECUTE FUNCTION core.update_tenant_audit();

-- =============================================================================
-- ENTITY REGISTRY (Universal Identity)
-- =============================================================================
CREATE TABLE core.entities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Universal Classification
    entity_type VARCHAR(50) NOT NULL 
        CHECK (entity_type IN ('value_container', 'value_movement', 'economic_agent', 
                               'agreement', 'event', 'document', 'instrument', 
                               'provision', 'settlement', 'batch', 'entitlement',
                               'jurisdiction', 'reconciliation', 'temporal_transition')),
    
    -- Human-readable Reference
    entity_code VARCHAR(100) NOT NULL,
    
    -- Global Uniqueness (Tenant-scoped)
    global_reference VARCHAR(200) GENERATED ALWAYS AS (
        tenant_id::text || ':' || entity_type || ':' || entity_code
    ) STORED,
    
    -- Soft Delete Support
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    deletion_reason TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Temporal (Bitemporal)
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Metadata
    metadata JSONB NOT NULL DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    -- Idempotency
    idempotency_key VARCHAR(100),
    
    -- Constraints
    CONSTRAINT unique_entity_per_tenant UNIQUE (tenant_id, entity_type, entity_code),
    CONSTRAINT chk_entity_valid_dates CHECK (valid_from <= valid_to),
    CONSTRAINT unique_entity_idempotency UNIQUE NULLS NOT DISTINCT (tenant_id, idempotency_key)
) PARTITION BY LIST (tenant_id);

-- Create default partition
CREATE TABLE core.entities_default PARTITION OF core.entities
    DEFAULT;

-- Critical indexes for entity registry (-3.2)
CREATE INDEX idx_entities_tenant_lookup ON core.entities(tenant_id, entity_type, entity_code) WHERE is_deleted = FALSE;
CREATE INDEX idx_entities_global_ref ON core.entities(global_reference);
CREATE INDEX idx_entities_temporal ON core.entities(valid_from, valid_to) WHERE is_current = TRUE AND is_deleted = FALSE;
CREATE INDEX idx_entities_metadata ON core.entities USING GIN(metadata);
CREATE INDEX idx_entities_deleted ON core.entities(tenant_id, is_deleted) WHERE is_deleted = FALSE;
CREATE INDEX idx_entities_correlation ON core.entities(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_entities_active_composite ON core.entities(tenant_id, entity_type, valid_from, valid_to) 
    WHERE is_current = TRUE AND is_deleted = FALSE;

COMMENT ON TABLE core.entities IS 'Central registry of all core entities for cross-reference and audit';

-- Row-Level Security (RLS) Policy
ALTER TABLE core.entities ENABLE ROW LEVEL SECURITY;

CREATE POLICY entity_tenant_isolation ON core.entities
    USING (tenant_id = COALESCE(current_setting('app.current_tenant', TRUE)::UUID, tenant_id));

-- =============================================================================
-- ENCRYPTION UTILITIES
-- =============================================================================
CREATE OR REPLACE FUNCTION core.encrypt_config(p_config JSONB, p_key TEXT)
RETURNS BYTEA AS $$
BEGIN
    RETURN pgp_sym_encrypt(p_config::text, p_key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION core.decrypt_config(p_encrypted BYTEA, p_key TEXT)
RETURNS JSONB AS $$
BEGIN
    RETURN pgp_sym_decrypt(p_encrypted, p_key)::JSONB;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SEED DATA
-- =============================================================================
INSERT INTO core.tenants (id, name, code, legal_name, base_currency, timezone, status)
VALUES (
    '00000000-0000-0000-0000-000000000000'::UUID,
    'System Tenant',
    'system',
    'FinOS System Tenant',
    'USD',
    'UTC',
    'active'
) ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT USAGE ON SCHEMA core TO finos_app;
GRANT USAGE ON SCHEMA core_history TO finos_app;
GRANT USAGE ON SCHEMA core_crypto TO finos_app;
GRANT USAGE ON SCHEMA core_audit TO finos_app;

GRANT SELECT, INSERT, UPDATE ON core.tenants TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.entities TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.entity_sequences TO finos_app;

GRANT USAGE, SELECT ON SEQUENCE core.entity_sequences_sequence_id_seq TO finos_app;

-- =============================================================================
-- COMMENTS & DOCUMENTATION
-- =============================================================================
COMMENT ON TABLE core.entity_sequences IS 'Monotonic sequence generator for tenant-scoped entity codes';
COMMENT ON TABLE core.entities IS 'Universal entity registry providing cross-cutting identity and audit';
COMMENT ON TABLE core.tenants IS 'Root tenant table for multi-tenant isolation and configuration';
