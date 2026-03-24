-- =============================================================================
-- FINOS CORE KERNEL - PEER-STYLE READ CACHING (Datomic Model)
-- =============================================================================
-- File: core/022_peer_caching.sql
-- Description: Datomic-inspired peer caching with content-addressable storage,
--              in-memory indexes, and cache invalidation
-- Features: Peer registry, cache segments, content hashing, invalidation streams
-- Standards: Datomic Peer Architecture, Content-Addressable Storage
-- =============================================================================

-- =============================================================================
-- PEER REGISTRY (Tracks all application peers/nodes)
-- =============================================================================
CREATE TABLE core.peer_registry (
    peer_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Peer Identification
    peer_name VARCHAR(100) NOT NULL,
    peer_type VARCHAR(50) NOT NULL CHECK (peer_type IN ('read_replica', 'query_peer', 'transactor', 'analytics_peer', 'backup_peer')),
    
    -- Connection Details
    host_address INET,
    port INTEGER,
    connection_string TEXT,
    
    -- Capabilities
    supports_queries BOOLEAN DEFAULT TRUE,
    supports_transactions BOOLEAN DEFAULT FALSE,
    supports_analytics BOOLEAN DEFAULT FALSE,
    max_connections INTEGER DEFAULT 100,
    
    -- Cache Configuration
    cache_size_mb INTEGER DEFAULT 1024,
    cache_strategy VARCHAR(20) DEFAULT 'lru' CHECK (cache_strategy IN ('lru', 'lfu', 'fifo')),
    
    -- Status
    status VARCHAR(20) DEFAULT 'initializing' CHECK (status IN ('initializing', 'active', 'degraded', 'offline', 'retired')),
    last_heartbeat_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Metrics
    queries_served BIGINT DEFAULT 0,
    cache_hits BIGINT DEFAULT 0,
    cache_misses BIGINT DEFAULT 0,
    avg_query_time_ms DECIMAL(10,3),
    
    -- Heartbeat Data
    current_tx_id BIGINT,  -- Last transaction this peer has seen
    memory_usage_mb DECIMAL(10,2),
    cpu_usage_percent DECIMAL(5,2),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_peer_registry_tenant ON core.peer_registry(tenant_id, status) WHERE status IN ('active', 'degraded');
CREATE INDEX idx_peer_registry_type ON core.peer_registry(peer_type, status);
CREATE INDEX idx_peer_registry_heartbeat ON core.peer_registry(last_heartbeat_at) WHERE status = 'active';

COMMENT ON TABLE core.peer_registry IS 'Registry of all Datomic-style peers in the FinOS cluster';
COMMENT ON COLUMN core.peer_registry.current_tx_id IS 'The highest transaction ID this peer has cached - used for cache invalidation';

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION core.update_peer_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_peer_registry_update
    BEFORE UPDATE ON core.peer_registry
    FOR EACH ROW EXECUTE FUNCTION core.update_peer_timestamp();

-- =============================================================================
-- CACHE SEGMENTS (In-memory index segments cached by peers)
-- =============================================================================
CREATE TABLE core.cache_segments (
    segment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Segment Identification (Content-Addressable)
    segment_hash VARCHAR(64) NOT NULL,  -- SHA-256 of segment content
    segment_type VARCHAR(50) NOT NULL CHECK (segment_type IN ('eavt_index', 'avet_index', 'datom_chunk', 'entity_snapshot', 'query_result', 'materialized_view')),
    
    -- Content Reference
    entity_id UUID,  -- For entity-specific segments
    attribute_name VARCHAR(200),  -- For attribute-specific segments
    tx_range_start BIGINT,  -- Transactions covered by this segment
    tx_range_end BIGINT,
    
    -- Storage
    storage_backend VARCHAR(20) DEFAULT 'database' CHECK (storage_backend IN ('database', 'redis', 's3', 'local_ssd', 'memory')),
    storage_location TEXT,  -- Path/URL to segment data
    compression_method VARCHAR(20) DEFAULT 'zstd',
    compressed_size_bytes BIGINT,
    uncompressed_size_bytes BIGINT,
    
    -- Content Metadata
    datom_count INTEGER,
    entity_count INTEGER,
    content_checksum VARCHAR(64),
    
    -- Cache Statistics
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    accessed_at TIMESTAMPTZ,
    access_count INTEGER DEFAULT 0,
    
    -- Peer Distribution
    cached_by_peers UUID[],  -- Array of peer_ids that have this segment
    
    -- TTL
    expires_at TIMESTAMPTZ,
    
    CONSTRAINT unique_segment_hash UNIQUE (tenant_id, segment_hash)
);

CREATE INDEX idx_cache_segments_tenant ON core.cache_segments(tenant_id, segment_type);
CREATE INDEX idx_cache_segments_hash ON core.cache_segments(segment_hash);
CREATE INDEX idx_cache_segments_entity ON core.cache_segments(tenant_id, entity_id) WHERE entity_id IS NOT NULL;
CREATE INDEX idx_cache_segments_tx_range ON core.cache_segments(tenant_id, tx_range_start, tx_range_end);
CREATE INDEX idx_cache_segments_expires ON core.cache_segments(expires_at);

COMMENT ON TABLE core.cache_segments IS 'Content-addressable cache segments for Datomic-style peer caching';
COMMENT ON COLUMN core.cache_segments.segment_hash IS 'SHA-256 hash of segment content - enables content-addressable retrieval';

-- =============================================================================
-- PEER CACHE INDEX (What each peer has cached)
-- =============================================================================
CREATE TABLE core.peer_cache_index (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    peer_id UUID NOT NULL REFERENCES core.peer_registry(peer_id) ON DELETE CASCADE,
    segment_id UUID NOT NULL REFERENCES core.cache_segments(segment_id) ON DELETE CASCADE,
    
    -- Local Cache Metadata
    local_cache_key TEXT,  -- Key used in peer's local cache
    cached_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_accessed_at TIMESTAMPTZ,
    access_count INTEGER DEFAULT 0,
    
    -- Priority for eviction
    priority_score DECIMAL(10,4) DEFAULT 0,  -- Higher = keep longer
    
    UNIQUE(peer_id, segment_id)
);

CREATE INDEX idx_peer_cache_index_peer ON core.peer_cache_index(peer_id, cached_at);
CREATE INDEX idx_peer_cache_index_segment ON core.peer_cache_index(segment_id);
CREATE INDEX idx_peer_cache_index_access ON core.peer_cache_index(peer_id, last_accessed_at DESC);

COMMENT ON TABLE core.peer_cache_index IS 'Tracks which segments are cached by which peers';

-- =============================================================================
-- CACHE INVALIDATION STREAM (Real-time invalidation events)
-- =============================================================================
CREATE TABLE core.cache_invalidation_stream (
    invalidation_id BIGSERIAL,
    event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- What changed
    tx_id BIGINT NOT NULL,
    entity_id UUID,
    attribute_name VARCHAR(200),
    segment_types VARCHAR(50)[],  -- Which segment types are affected
    
    -- Invalidation scope
    tenant_id UUID NOT NULL,
    affected_peers UUID[],  -- NULL = all peers
    
    -- Invalidation type
    invalidation_type VARCHAR(20) DEFAULT 'entity' CHECK (invalidation_type IN ('entity', 'attribute', 'transaction', 'full_cache', 'segment_hash')),
    segment_hash VARCHAR(64),  -- For direct hash invalidation
    
    -- Processing
    processed_by_peers UUID[] DEFAULT '{}',
    processed_at TIMESTAMPTZ,
    
    PRIMARY KEY (invalidation_id, event_time)
) PARTITION BY RANGE (event_time);

-- Create default partition
CREATE TABLE core.cache_invalidation_stream_default PARTITION OF core.cache_invalidation_stream DEFAULT;

-- Note: Table is already partitioned by range, cannot convert to hypertable
-- Partition management will be handled by pg_partman or manual maintenance

CREATE INDEX idx_invalidation_stream_tx ON core.cache_invalidation_stream(tx_id);
CREATE INDEX idx_invalidation_stream_entity ON core.cache_invalidation_stream(tenant_id, entity_id) WHERE entity_id IS NOT NULL;
CREATE INDEX idx_invalidation_stream_unprocessed ON core.cache_invalidation_stream(event_time) WHERE processed_at IS NULL;

COMMENT ON TABLE core.cache_invalidation_stream IS 'Real-time cache invalidation stream for peer synchronization';

-- =============================================================================
-- CONTENT-ADDRESSABLE STORAGE INTERFACE
-- =============================================================================

-- Function: Store a cache segment (content-addressable)
CREATE OR REPLACE FUNCTION core.store_cache_segment(
    p_tenant_id UUID,
    p_segment_type VARCHAR,
    p_content JSONB,
    p_entity_id UUID DEFAULT NULL,
    p_attribute_name VARCHAR DEFAULT NULL,
    p_tx_range_start BIGINT DEFAULT NULL,
    p_tx_range_end BIGINT DEFAULT NULL,
    p_storage_backend VARCHAR DEFAULT 'database',
    p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (segment_id UUID, segment_hash VARCHAR) AS $$
DECLARE
    v_segment_id UUID;
    v_segment_hash VARCHAR(64);
    v_content_text TEXT;
    v_compressed BYTEA;
    v_uncompressed_size BIGINT;
    v_compressed_size BIGINT;
BEGIN
    -- Serialize content to text
    v_content_text := p_content::TEXT;
    v_uncompressed_size := length(v_content_text);
    
    -- Calculate content hash (content-addressable)
    v_segment_hash := encode(digest(v_content_text, 'sha256'), 'hex');
    
    -- Compress content
    v_compressed := pg_catalog.lzcompress(v_content_text::bytea);
    v_compressed_size := octet_length(v_compressed);
    
    -- Try to insert, or return existing if hash collision (same content)
    INSERT INTO core.cache_segments (
        tenant_id, segment_hash, segment_type, entity_id, attribute_name,
        tx_range_start, tx_range_end, storage_backend, storage_location,
        compression_method, compressed_size_bytes, uncompressed_size_bytes,
        datom_count, expires_at
    ) VALUES (
        p_tenant_id, v_segment_hash, p_segment_type, p_entity_id, p_attribute_name,
        p_tx_range_start, p_tx_range_end, p_storage_backend, 
        encode(v_compressed, 'base64'),  -- Store compressed content inline for database backend
        'lz4', v_compressed_size, v_uncompressed_size,
        jsonb_array_length(p_content), p_expires_at
    )
    ON CONFLICT (tenant_id, segment_hash) 
    DO UPDATE SET 
        accessed_at = NOW(),
        access_count = cache_segments.access_count + 1
    RETURNING cache_segments.segment_id INTO v_segment_id;
    
    RETURN QUERY SELECT v_segment_id, v_segment_hash;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.store_cache_segment IS 'Stores a cache segment with content-addressable hashing';

-- Function: Retrieve a cache segment by hash
CREATE OR REPLACE FUNCTION core.retrieve_cache_segment(
    p_segment_hash VARCHAR,
    p_peer_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_segment RECORD;
    v_content TEXT;
BEGIN
    SELECT * INTO v_segment FROM core.cache_segments WHERE segment_hash = p_segment_hash;
    
    IF v_segment IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Decompress content
    v_content := pg_catalog.lzdecompress(decode(v_segment.storage_location, 'base64'))::TEXT;
    
    -- Update access statistics
    UPDATE core.cache_segments 
    SET access_count = access_count + 1, accessed_at = NOW()
    WHERE segment_id = v_segment.segment_id;
    
    -- If peer specified, update peer cache index
    IF p_peer_id IS NOT NULL THEN
        INSERT INTO core.peer_cache_index (peer_id, segment_id, last_accessed_at)
        VALUES (p_peer_id, v_segment.segment_id, NOW())
        ON CONFLICT (peer_id, segment_id) 
        DO UPDATE SET last_accessed_at = NOW(), access_count = peer_cache_index.access_count + 1;
    END IF;
    
    RETURN v_content::JSONB;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.retrieve_cache_segment IS 'Retrieves a cache segment by its content hash';

-- =============================================================================
-- PEER CACHE MANAGEMENT
-- =============================================================================

-- Function: Register a new peer
CREATE OR REPLACE FUNCTION core.register_peer(
    p_tenant_id UUID,
    p_peer_name VARCHAR,
    p_peer_type VARCHAR,
    p_host_address INET,
    p_port INTEGER,
    p_cache_size_mb INTEGER DEFAULT 1024
)
RETURNS UUID AS $$
DECLARE
    v_peer_id UUID;
BEGIN
    INSERT INTO core.peer_registry (
        tenant_id, peer_name, peer_type, host_address, port,
        cache_size_mb, status, started_at
    ) VALUES (
        p_tenant_id, p_peer_name, p_peer_type, p_host_address, p_port,
        p_cache_size_mb, 'active', NOW()
    )
    RETURNING peer_id INTO v_peer_id;
    
    RETURN v_peer_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Peer heartbeat
CREATE OR REPLACE FUNCTION core.peer_heartbeat(
    p_peer_id UUID,
    p_current_tx_id BIGINT,
    p_memory_usage_mb DECIMAL,
    p_cpu_usage_percent DECIMAL
)
RETURNS VOID AS $$
BEGIN
    UPDATE core.peer_registry
    SET 
        last_heartbeat_at = NOW(),
        current_tx_id = p_current_tx_id,
        memory_usage_mb = p_memory_usage_mb,
        cpu_usage_percent = p_cpu_usage_percent,
        status = CASE 
            WHEN p_cpu_usage_percent > 90 OR p_memory_usage_mb > cache_size_mb * 0.95 THEN 'degraded'
            ELSE 'active'
        END
    WHERE peer_id = p_peer_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Get best peer for query
CREATE OR REPLACE FUNCTION core.get_best_query_peer(
    p_tenant_id UUID,
    p_query_type VARCHAR DEFAULT 'standard'
)
RETURNS TABLE (
    peer_id UUID,
    peer_name VARCHAR,
    host_address INET,
    port INTEGER,
    current_tx_id BIGINT,
    estimated_latency_ms DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pr.peer_id,
        pr.peer_name,
        pr.host_address,
        pr.port,
        pr.current_tx_id,
        CASE 
            WHEN pr.status = 'degraded' THEN 100.0
            WHEN pr.avg_query_time_ms IS NULL THEN 10.0
            ELSE pr.avg_query_time_ms
        END AS estimated_latency_ms
    FROM core.peer_registry pr
    WHERE pr.tenant_id = p_tenant_id
      AND pr.status IN ('active', 'degraded')
      AND pr.supports_queries = TRUE
      AND pr.last_heartbeat_at > NOW() - INTERVAL '30 seconds'
    ORDER BY 
        CASE p_query_type
            WHEN 'analytics' THEN CASE WHEN pr.supports_analytics THEN 0 ELSE 1 END
            ELSE 0
        END,
        pr.avg_query_time_ms NULLS LAST,
        pr.queries_served DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.get_best_query_peer IS 'Returns the best available peer for executing a query';

-- =============================================================================
-- CACHE INVALIDATION
-- =============================================================================

-- Function: Invalidate cache for entity
CREATE OR REPLACE FUNCTION core.invalidate_entity_cache(
    p_tenant_id UUID,
    p_entity_id UUID,
    p_tx_id BIGINT,
    p_affected_peers UUID[] DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_invalidation_id BIGINT;
BEGIN
    INSERT INTO core.cache_invalidation_stream (
        tx_id, tenant_id, entity_id, invalidation_type, affected_peers, segment_types
    ) VALUES (
        p_tx_id, p_tenant_id, p_entity_id, 'entity', p_affected_peers, 
        ARRAY['eavt_index', 'entity_snapshot', 'datom_chunk']
    )
    RETURNING invalidation_id INTO v_invalidation_id;
    
    -- Mark affected segments for expiration
    UPDATE core.cache_segments
    SET expires_at = NOW() + INTERVAL '5 seconds'  -- Short grace period
    WHERE tenant_id = p_tenant_id
      AND entity_id = p_entity_id
      AND segment_type IN ('eavt_index', 'entity_snapshot', 'datom_chunk');
    
    RETURN v_invalidation_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Process invalidation events for a peer
CREATE OR REPLACE FUNCTION core.get_peer_invalidations(
    p_peer_id UUID,
    p_last_processed_id BIGINT DEFAULT 0
)
RETURNS TABLE (
    invalidation_id BIGINT,
    tx_id BIGINT,
    invalidation_type VARCHAR,
    entity_id UUID,
    attribute_name VARCHAR,
    segment_hash VARCHAR
) AS $$
DECLARE
    v_peer_tx_id BIGINT;
    v_tenant_id UUID;
BEGIN
    -- Get peer's current transaction position
    SELECT current_tx_id, tenant_id INTO v_peer_tx_id, v_tenant_id
    FROM core.peer_registry WHERE peer_id = p_peer_id;
    
    RETURN QUERY
    SELECT 
        cis.invalidation_id,
        cis.tx_id,
        cis.invalidation_type,
        cis.entity_id,
        cis.attribute_name,
        cis.segment_hash
    FROM core.cache_invalidation_stream cis
    WHERE cis.invalidation_id > p_last_processed_id
      AND cis.tx_id > v_peer_tx_id
      AND (cis.affected_peers IS NULL OR p_peer_id = ANY(cis.affected_peers))
      AND (cis.tenant_id = v_tenant_id OR cis.tenant_id IS NULL)
    ORDER BY cis.invalidation_id
    LIMIT 1000;
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================================================
-- EAVT INDEX CACHING
-- =============================================================================

-- Function: Build and cache EAVT index segment for an entity
CREATE OR REPLACE FUNCTION core.build_eavt_cache_segment(
    p_tenant_id UUID,
    p_entity_id UUID,
    p_as_of_tx BIGINT DEFAULT NULL
)
RETURNS TABLE (segment_id UUID, segment_hash VARCHAR, datom_count INTEGER) AS $$
DECLARE
    v_segment_id UUID;
    v_segment_hash VARCHAR(64);
    v_content JSONB;
    v_count INTEGER;
BEGIN
    -- Build EAVT data
    SELECT 
        jsonb_agg(
            jsonb_build_object(
                'e', datom_entity_id,
                'a', datom_attribute,
                'v', datom_value,
                'tx', event_id,
                'op', datom_operation,
                't', event_time
            ) ORDER BY datom_attribute, event_id
        ),
        COUNT(*)
    INTO v_content, v_count
    FROM core_crypto.immutable_events
    WHERE tenant_id = p_tenant_id
      AND datom_entity_id = p_entity_id
      AND (p_as_of_tx IS NULL OR event_id <= p_as_of_tx)
      AND datom_operation = '+';
    
    IF v_count = 0 THEN
        RETURN;
    END IF;
    
    -- Store segment
    SELECT s.segment_id, s.segment_hash INTO v_segment_id, v_segment_hash
    FROM core.store_cache_segment(
        p_tenant_id, 'eavt_index', v_content,
        p_entity_id, NULL, 1, p_as_of_tx
    ) s;
    
    RETURN QUERY SELECT v_segment_id, v_segment_hash, v_count;
END;
$$ LANGUAGE plpgsql;

-- Function: Get cached EAVT data (or build if not cached)
CREATE OR REPLACE FUNCTION core.get_cached_eavt(
    p_tenant_id UUID,
    p_entity_id UUID,
    p_as_of_tx BIGINT DEFAULT NULL,
    p_peer_id UUID DEFAULT NULL
)
RETURNS TABLE (
    attribute VARCHAR,
    value JSONB,
    tx_id BIGINT,
    valid_time TIMESTAMPTZ
) AS $$
DECLARE
    v_segment_hash VARCHAR(64);
    v_content JSONB;
    v_segment_id UUID;
BEGIN
    -- Look for existing segment
    SELECT cs.segment_hash, cs.segment_id INTO v_segment_hash, v_segment_id
    FROM core.cache_segments cs
    WHERE cs.tenant_id = p_tenant_id
      AND cs.entity_id = p_entity_id
      AND cs.segment_type = 'eavt_index'
      AND (p_as_of_tx IS NULL OR cs.tx_range_end >= p_as_of_tx)
      AND (cs.expires_at IS NULL OR cs.expires_at > NOW())
    ORDER BY cs.tx_range_end DESC
    LIMIT 1;
    
    -- If not found, build it
    IF v_segment_hash IS NULL THEN
        SELECT s.segment_hash, s.segment_id INTO v_segment_hash, v_segment_id
        FROM core.build_eavt_cache_segment(p_tenant_id, p_entity_id, p_as_of_tx) s;
    END IF;
    
    -- Retrieve content
    IF v_segment_hash IS NOT NULL THEN
        v_content := core.retrieve_cache_segment(v_segment_hash, p_peer_id);
        
        RETURN QUERY
        SELECT 
            d->>'a'::VARCHAR,
            d->'v',
            (d->>'tx')::BIGINT,
            (d->>'t')::TIMESTAMPTZ
        FROM jsonb_array_elements(v_content) AS d;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================================================
-- QUERY RESULT CACHING
-- =============================================================================

-- Function: Cache query result
CREATE OR REPLACE FUNCTION core.cache_query_result(
    p_tenant_id UUID,
    p_query_hash VARCHAR,  -- Hash of query SQL + parameters
    p_result JSONB,
    p_ttl_seconds INTEGER DEFAULT 300,
    p_peer_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_segment_id UUID;
    v_expires_at TIMESTAMPTZ;
BEGIN
    v_expires_at := NOW() + (p_ttl_seconds || ' seconds')::INTERVAL;
    
    SELECT s.segment_id INTO v_segment_id
    FROM core.store_cache_segment(
        p_tenant_id, 'query_result', p_result,
        NULL, NULL, NULL, NULL, 'database', v_expires_at
    ) s;
    
    -- Update the hash to be the query hash (not content hash) for query results
    UPDATE core.cache_segments
    SET segment_hash = p_query_hash  -- Override with query hash for lookup
    WHERE segment_id = v_segment_id;
    
    -- Register with peer if specified
    IF p_peer_id IS NOT NULL THEN
        INSERT INTO core.peer_cache_index (peer_id, segment_id, cached_at)
        VALUES (p_peer_id, v_segment_id, NOW())
        ON CONFLICT DO NOTHING;
    END IF;
    
    RETURN v_segment_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Get cached query result
CREATE OR REPLACE FUNCTION core.get_cached_query_result(
    p_query_hash VARCHAR
)
RETURNS JSONB AS $$
DECLARE
    v_content JSONB;
BEGIN
    SELECT core.retrieve_cache_segment(p_query_hash) INTO v_content
    FROM core.cache_segments
    WHERE segment_hash = p_query_hash
      AND (expires_at IS NULL OR expires_at > NOW());
    
    RETURN v_content;
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================================================
-- MAINTENANCE FUNCTIONS
-- =============================================================================

-- Function: Clean up expired cache segments
CREATE OR REPLACE FUNCTION core.cleanup_expired_cache_segments()
RETURNS TABLE (deleted_count INTEGER, freed_bytes BIGINT) AS $$
DECLARE
    v_deleted INTEGER;
    v_freed BIGINT;
BEGIN
    SELECT COUNT(*), COALESCE(SUM(compressed_size_bytes), 0)
    INTO v_deleted, v_freed
    FROM core.cache_segments
    WHERE expires_at < NOW() - INTERVAL '1 hour';  -- Grace period
    
    DELETE FROM core.cache_segments
    WHERE expires_at < NOW() - INTERVAL '1 hour';
    
    RETURN QUERY SELECT v_deleted, v_freed;
END;
$$ LANGUAGE plpgsql;

-- Function: Get cache statistics for a tenant
CREATE OR REPLACE FUNCTION core.get_cache_statistics(
    p_tenant_id UUID
)
RETURNS TABLE (
    segment_type VARCHAR,
    segment_count BIGINT,
    total_compressed_bytes BIGINT,
    total_uncompressed_bytes BIGINT,
    avg_compression_ratio DECIMAL(5,2),
    total_access_count BIGINT,
    oldest_segment TIMESTAMPTZ,
    newest_segment TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cs.segment_type,
        COUNT(*)::BIGINT,
        SUM(cs.compressed_size_bytes)::BIGINT,
        SUM(cs.uncompressed_size_bytes)::BIGINT,
        ROUND(AVG(cs.uncompressed_size_bytes::DECIMAL / NULLIF(cs.compressed_size_bytes, 0)), 2),
        SUM(cs.access_count)::BIGINT,
        MIN(cs.created_at),
        MAX(cs.created_at)
    FROM core.cache_segments cs
    WHERE cs.tenant_id = p_tenant_id
    GROUP BY cs.segment_type;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: Retire stale peers
CREATE OR REPLACE FUNCTION core.retire_stale_peers(
    p_max_heartbeat_age INTERVAL DEFAULT INTERVAL '5 minutes'
)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE core.peer_registry
    SET status = 'offline'
    WHERE status = 'active'
      AND last_heartbeat_at < NOW() - p_max_heartbeat_age;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.peer_registry TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.cache_segments TO finos_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON core.peer_cache_index TO finos_app;
GRANT SELECT, INSERT ON core.cache_invalidation_stream TO finos_app;

GRANT EXECUTE ON FUNCTION core.store_cache_segment TO finos_app;
GRANT EXECUTE ON FUNCTION core.retrieve_cache_segment TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.register_peer TO finos_app;
GRANT EXECUTE ON FUNCTION core.peer_heartbeat TO finos_app;
GRANT EXECUTE ON FUNCTION core.get_best_query_peer TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.invalidate_entity_cache TO finos_app;
GRANT EXECUTE ON FUNCTION core.get_peer_invalidations TO finos_app;
GRANT EXECUTE ON FUNCTION core.build_eavt_cache_segment TO finos_app;
GRANT EXECUTE ON FUNCTION core.get_cached_eavt TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.cache_query_result TO finos_app;
GRANT EXECUTE ON FUNCTION core.get_cached_query_result TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.cleanup_expired_cache_segments TO finos_app;
GRANT EXECUTE ON FUNCTION core.get_cache_statistics TO finos_app;
GRANT EXECUTE ON FUNCTION core.retire_stale_peers TO finos_app;

-- =============================================================================
