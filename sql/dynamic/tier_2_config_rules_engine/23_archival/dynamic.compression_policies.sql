-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 23 - Columnar Archival
-- TABLE: dynamic.compression_policies
--
-- DESCRIPTION:
--   Compression policy configuration for archival.
--   Configures compression algorithms and settings per data type.
--
-- CORE DEPENDENCY: 023_columnar_archival.sql
--
-- ============================================================================

CREATE TABLE dynamic.compression_policies (
    policy_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Policy Identification
    policy_code VARCHAR(100) NOT NULL,
    policy_name VARCHAR(200) NOT NULL,
    policy_description TEXT,
    
    -- Applicability
    applicable_schemas VARCHAR(100)[], -- 'core', 'dynamic', 'core_crypto'
    applicable_tables VARCHAR(100)[],
    applicable_column_types VARCHAR(100)[], -- 'TEXT', 'NUMERIC', 'TIMESTAMP', 'JSON'
    
    -- Compression Settings
    compression_algorithm VARCHAR(50) NOT NULL, -- 'ZSTD', 'LZ4', 'GZIP', 'SNAPPY', 'BROTLI'
    compression_level INTEGER, -- 1-22 for ZSTD, 1-9 for GZIP
    
    -- Column-Specific Settings
    column_specific_settings JSONB, -- {"json_column": {"algorithm": "ZSTD", "level": 3}}
    
    -- TimescaleDB Specific
    timescaledb_compression_enabled BOOLEAN DEFAULT TRUE,
    segmentby_columns VARCHAR(100)[], -- Columns to segment by
    orderby_columns VARCHAR(100)[], -- Columns to order by
    
    -- Chunk Compression
    compress_after_days INTEGER DEFAULT 7,
    compression_schedule_cron VARCHAR(100) DEFAULT '0 2 * * *', -- 2 AM daily
    
    -- Decompression
    decompress_on_access BOOLEAN DEFAULT FALSE,
    cache_decompressed_data BOOLEAN DEFAULT TRUE,
    decompression_cache_ttl_hours INTEGER DEFAULT 24,
    
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
    
    CONSTRAINT unique_compression_policy_code UNIQUE (tenant_id, policy_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.compression_policies_default PARTITION OF dynamic.compression_policies DEFAULT;

CREATE INDEX idx_compression_policy_active ON dynamic.compression_policies(tenant_id) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.compression_policies IS 'Compression policy configuration for TimescaleDB and columnar archival. Tier 2 Low-Code';

CREATE TRIGGER trg_compression_policies_audit
    BEFORE UPDATE ON dynamic.compression_policies
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.compression_policies TO finos_app;
