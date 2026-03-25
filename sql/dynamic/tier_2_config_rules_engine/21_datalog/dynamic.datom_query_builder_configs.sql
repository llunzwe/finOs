-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 21 - Datalog Query Engine
-- TABLE: dynamic.datom_query_builder_configs
--
-- DESCRIPTION:
--   Datom query builder configuration for Datalog queries.
--   Configures saved queries, templates for E-A-V-Tx datom retrieval.
--
-- CORE DEPENDENCY: 021_datalog_query_engine.sql
--
-- ============================================================================

CREATE TABLE dynamic.datom_query_builder_configs (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Query Identification
    query_code VARCHAR(100) NOT NULL,
    query_name VARCHAR(200) NOT NULL,
    query_description TEXT,
    
    -- Query Type
    query_type VARCHAR(50) NOT NULL, -- ENTITY_HISTORY, ATTRIBUTE_HISTORY, PATTERN_MATCH, AS_OF
    
    -- Datalog Pattern
    find_clause TEXT[], -- Variables to find
    where_clauses JSONB NOT NULL, -- Array of datom patterns
    -- [{"e": "?e", "a": "container.balance", "v": "?balance", "tx": "?tx", "op": "+"}]
    
    -- Bindings & Parameters
    input_parameters JSONB, -- Parameters that can be bound at runtime
    default_bindings JSONB, -- Default values for parameters
    
    -- Temporal Modifiers
    as_of_time TIMESTAMPTZ, -- Query as of specific time
    since_time TIMESTAMPTZ, -- Query since specific time
    history_mode BOOLEAN DEFAULT FALSE, -- Include retractions
    
    -- Output Configuration
    output_format VARCHAR(50) DEFAULT 'TABLE', -- TABLE, JSON, CSV, PULL
    pull_pattern JSONB, -- Datomic pull pattern for nested results
    
    -- Performance
    use_index_hints BOOLEAN DEFAULT TRUE,
    index_hint VARCHAR(50), -- EAVT, AVET, AEVT, VAET
    max_results INTEGER DEFAULT 10000,
    timeout_seconds INTEGER DEFAULT 30,
    
    -- Access Control
    allowed_roles VARCHAR(100)[],
    require_approval BOOLEAN DEFAULT FALSE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_system_defined BOOLEAN DEFAULT FALSE,
    
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
    
    CONSTRAINT unique_datom_query_config UNIQUE (tenant_id, query_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.datom_query_builder_configs_default PARTITION OF dynamic.datom_query_builder_configs DEFAULT;

CREATE INDEX idx_datom_query_type ON dynamic.datom_query_builder_configs(tenant_id, query_type) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.datom_query_builder_configs IS 'Datom query builder configuration for Datalog E-A-V-Tx queries. Tier 2 Low-Code';

CREATE TRIGGER trg_datom_query_builder_configs_audit
    BEFORE UPDATE ON dynamic.datom_query_builder_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.datom_query_builder_configs TO finos_app;
