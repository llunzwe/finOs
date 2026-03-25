-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Peer Caching
-- TABLE: dynamic.peer_registration_configs
--
-- DESCRIPTION:
--   Peer registration configuration for query peers.
--   Configures peer nodes, capabilities, and load balancing.
--
-- CORE DEPENDENCY: 022_peer_caching.sql
--
-- ============================================================================

CREATE TABLE dynamic.peer_registration_configs (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Peer Identification
    peer_code VARCHAR(100) NOT NULL,
    peer_name VARCHAR(200) NOT NULL,
    peer_description TEXT,
    
    -- Network Configuration
    peer_endpoint VARCHAR(500) NOT NULL, -- URL or connection string
    peer_region VARCHAR(100), -- AWS/Azure region
    peer_zone VARCHAR(100), -- Availability zone
    
    -- Peer Capabilities
    peer_role VARCHAR(50) DEFAULT 'QUERY', -- QUERY, INDEX, ARCHIVE, FULL
    supported_query_types VARCHAR(50)[], -- 'DATOM', 'RELATIONAL', 'ANALYTICAL'
    max_concurrent_queries INTEGER DEFAULT 100,
    
    -- Capacity
    cpu_cores INTEGER,
    memory_gb INTEGER,
    storage_gb INTEGER,
    network_bandwidth_mbps INTEGER,
    
    -- Load Balancing
    weight INTEGER DEFAULT 100, -- Load balancer weight
    priority INTEGER DEFAULT 100, -- Failover priority
    health_check_enabled BOOLEAN DEFAULT TRUE,
    health_check_interval_seconds INTEGER DEFAULT 30,
    
    -- Caching Scope
    cached_segments VARCHAR(100)[], -- Which cache segments this peer serves
    cache_ttl_seconds INTEGER DEFAULT 3600,
    
    -- Authentication
    auth_method VARCHAR(50) DEFAULT 'MUTUAL_TLS', -- MUTUAL_TLS, TOKEN, CERTIFICATE
    auth_config JSONB, -- Credentials/keys (encrypted)
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_registered BOOLEAN DEFAULT FALSE,
    last_heartbeat_at TIMESTAMPTZ,
    health_status VARCHAR(20) DEFAULT 'UNKNOWN', -- HEALTHY, DEGRADED, UNAVAILABLE
    
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
    
    CONSTRAINT unique_peer_config_code UNIQUE (tenant_id, peer_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.peer_registration_configs_default PARTITION OF dynamic.peer_registration_configs DEFAULT;

CREATE INDEX idx_peer_config_role ON dynamic.peer_registration_configs(tenant_id, peer_role) WHERE is_active = TRUE AND is_current = TRUE;
CREATE INDEX idx_peer_config_health ON dynamic.peer_registration_configs(tenant_id, health_status) WHERE is_active = TRUE;

COMMENT ON TABLE dynamic.peer_registration_configs IS 'Peer registration configuration for query peer nodes. Tier 2 Low-Code';

CREATE TRIGGER trg_peer_registration_configs_audit
    BEFORE UPDATE ON dynamic.peer_registration_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.peer_registration_configs TO finos_app;
