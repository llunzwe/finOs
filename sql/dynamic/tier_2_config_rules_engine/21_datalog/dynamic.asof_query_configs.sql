-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 21 - Datalog Query Engine
-- TABLE: dynamic.asof_query_configs
--
-- DESCRIPTION:
--   As-of query configuration for temporal data retrieval.
--   Configures point-in-time and bitemporal queries.
--
-- CORE DEPENDENCY: 021_datalog_query_engine.sql
--
-- ============================================================================

CREATE TABLE dynamic.asof_query_configs (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Config Identification
    config_code VARCHAR(100) NOT NULL,
    config_name VARCHAR(200) NOT NULL,
    config_description TEXT,
    
    -- Time Specification
    time_mode VARCHAR(50) NOT NULL, -- AS_OF, SINCE, BETWEEN, SNAPSHOT, LATEST
    valid_time_reference VARCHAR(50) DEFAULT 'BUSINESS_TIME', -- BUSINESS_TIME, SYSTEM_TIME
    
    -- Time Parameters
    default_as_of_time TIMESTAMPTZ, -- NULL = now
    default_lookback_days INTEGER DEFAULT 30,
    snapshot_frequency VARCHAR(20), -- DAILY, WEEKLY, MONTHLY for SNAPSHOT mode
    
    -- Target Data
    target_tables VARCHAR(100)[], -- Tables to query
    target_entities UUID[], -- Specific entities to include
    
    -- Datom Pattern (for E-A-V queries)
    datom_entity_patterns VARCHAR(200)[], -- Entity ID patterns
    datom_attribute_patterns VARCHAR(200)[], -- Attribute patterns (wildcards supported)
    datom_value_filters JSONB, -- Value filter conditions
    
    -- Projection
    include_history BOOLEAN DEFAULT TRUE,
    include_system_time BOOLEAN DEFAULT FALSE,
    include_transaction_info BOOLEAN DEFAULT FALSE,
    
    -- Output
    output_format VARCHAR(50) DEFAULT 'TABLE',
    include_metadata BOOLEAN DEFAULT TRUE,
    
    -- Performance
    use_materialized_view BOOLEAN DEFAULT FALSE,
    materialized_view_name VARCHAR(100),
    max_results INTEGER DEFAULT 10000,
    
    -- Access
    allowed_roles VARCHAR(100)[],
    caching_enabled BOOLEAN DEFAULT TRUE,
    cache_ttl_seconds INTEGER DEFAULT 300,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
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
    
    CONSTRAINT unique_asof_config_code UNIQUE (tenant_id, config_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.asof_query_configs_default PARTITION OF dynamic.asof_query_configs DEFAULT;

CREATE INDEX idx_asof_query_mode ON dynamic.asof_query_configs(tenant_id, time_mode) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.asof_query_configs IS 'As-of query configuration for point-in-time temporal data retrieval. Tier 2 Low-Code';

CREATE TRIGGER trg_asof_query_configs_audit
    BEFORE UPDATE ON dynamic.asof_query_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.asof_query_configs TO finos_app;
