-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Peer Caching
-- TABLE: dynamic.cache_warming_configs
--
-- DESCRIPTION:
--   Cache warming configuration for peer caching.
--   Configures pre-loading of cache segments.
--
-- CORE DEPENDENCY: 022_peer_caching.sql
--
-- ============================================================================

CREATE TABLE dynamic.cache_warming_configs (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Config Identification
    config_code VARCHAR(100) NOT NULL,
    config_name VARCHAR(200) NOT NULL,
    config_description TEXT,
    
    -- Target Cache
    cache_segment VARCHAR(100) NOT NULL, -- 'ACCOUNTS', 'PRICES', 'REFERENCE_DATA'
    cache_type VARCHAR(50) DEFAULT 'QUERY_RESULTS', -- QUERY_RESULTS, ENTITIES, MATERIALIZED_VIEW
    
    -- Warming Schedule
    warming_schedule VARCHAR(50) DEFAULT 'STARTUP', -- STARTUP, SCHEDULED, CONTINUOUS
    warmup_cron_expression VARCHAR(100), -- For SCHEDULED type
    warmup_interval_minutes INTEGER, -- For CONTINUOUS type
    
    -- Data Selection
    warmup_query TEXT, -- SQL query to fetch data for warming
    warmup_entities UUID[], -- Specific entities to warm
    warmup_filters JSONB, -- Filter conditions
    
    -- Priority & Resources
    priority INTEGER DEFAULT 100, -- Lower = higher priority
    max_parallel_queries INTEGER DEFAULT 4,
    memory_limit_mb INTEGER DEFAULT 512,
    
    -- Warming Strategy
    strategy VARCHAR(50) DEFAULT 'FULL', -- FULL, INCREMENTAL, DELTA
    incremental_column VARCHAR(100), -- For INCREMENTAL: timestamp or ID column
    incremental_lookback_hours INTEGER DEFAULT 24,
    
    -- Validation
    validate_after_warmup BOOLEAN DEFAULT TRUE,
    validation_query TEXT,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    last_warmup_at TIMESTAMPTZ,
    last_warmup_duration_seconds INTEGER,
    last_warmup_status VARCHAR(20), -- SUCCESS, PARTIAL, FAILED
    
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
    
    CONSTRAINT unique_cache_warming_config UNIQUE (tenant_id, config_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.cache_warming_configs_default PARTITION OF dynamic.cache_warming_configs DEFAULT;

CREATE INDEX idx_cache_warming_segment ON dynamic.cache_warming_configs(tenant_id, cache_segment) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.cache_warming_configs IS 'Cache warming configuration for pre-loading peer cache segments. Tier 2 Low-Code';

CREATE TRIGGER trg_cache_warming_configs_audit
    BEFORE UPDATE ON dynamic.cache_warming_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.cache_warming_configs TO finos_app;
