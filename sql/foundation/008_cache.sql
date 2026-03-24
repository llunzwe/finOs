-- =============================================================================
-- FINOS CORE KERNEL - CACHING LAYER
-- =============================================================================
-- File: 008_cache.sql
-- Description: Application-level caching with TTL
-- =============================================================================

-- SECTION 18: CACHING LAYER
-- =============================================================================

CREATE TABLE core.cache_entries (
    cache_key TEXT PRIMARY KEY,
    tenant_id UUID,
    
    -- Data
    cache_value JSONB NOT NULL,
    value_type VARCHAR(50) DEFAULT 'json',
    
    -- TTL
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    
    -- Metadata
    access_count INTEGER DEFAULT 0,
    last_accessed_at TIMESTAMPTZ,
    
    -- Source
    source_query TEXT,
    source_table VARCHAR(100)
);

CREATE INDEX idx_cache_expires ON core.cache_entries(expires_at) WHERE expires_at < NOW();
CREATE INDEX idx_cache_tenant ON core.cache_entries(tenant_id, cache_key);

COMMENT ON TABLE core.cache_entries IS 'Database-backed caching layer with TTL';

-- Cache cleanup function
CREATE OR REPLACE FUNCTION core.cleanup_expired_cache()
RETURNS INTEGER AS $$
DECLARE
    v_deleted INTEGER;
BEGIN
    DELETE FROM core.cache_entries WHERE expires_at < NOW();
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.cleanup_expired_cache IS 'Removes expired cache entries, returns count deleted';

-- =============================================================================
