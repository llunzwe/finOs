-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 24 - Simulation Testing
-- TABLE: dynamic.product_analytics_views
-- COMPLIANCE: ISTQB
--   - Basel
--   - SOX
--   - ITIL
-- ============================================================================


CREATE TABLE dynamic.product_analytics_views (

    view_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- View Identity
    view_name VARCHAR(200) NOT NULL,
    view_description TEXT,
    view_type VARCHAR(50) NOT NULL 
        CHECK (view_type IN ('REAL_TIME', 'DAILY', 'WEEKLY', 'MONTHLY', 'CUSTOM')),
    
    -- Data Source
    source_type VARCHAR(50) NOT NULL 
        CHECK (source_type IN ('core', 'dynamic', 'hypertable', 'materialized_view')),
    source_tables TEXT[] NOT NULL,
    
    -- Query Definition
    query_definition TEXT NOT NULL, -- SQL or JSON query definition
    query_parameters JSONB DEFAULT '{}',
    
    -- Aggregation
    aggregation_config JSONB DEFAULT '{}',
    -- Example: {
    --   dimensions: ['product_id', 'date'],
    --   metrics: ['count', 'sum_amount', 'avg_balance'],
    --   filters: {status: 'active'}
    -- }
    
    -- Refresh Configuration
    refresh_mode VARCHAR(20) DEFAULT 'on_demand' 
        CHECK (refresh_mode IN ('real_time', 'near_real_time', 'scheduled', 'on_demand')),
    refresh_schedule VARCHAR(100), -- Cron expression
    refresh_interval_seconds INTEGER, -- For near_real_time
    
    last_refreshed_at TIMESTAMPTZ,
    last_refresh_duration_ms INTEGER,
    
    -- Output
    output_destination VARCHAR(50) DEFAULT 'table' 
        CHECK (output_destination IN ('table', 'materialized_view', 'api_endpoint', 's3')),
    output_config JSONB DEFAULT '{}',
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_analytics_views_default PARTITION OF dynamic.product_analytics_views DEFAULT;

-- Indexes
CREATE INDEX idx_analytics_views_tenant ON dynamic.product_analytics_views(tenant_id, active) WHERE active = TRUE;

-- Triggers
CREATE TRIGGER trg_analytics_views_update
    BEFORE UPDATE ON dynamic.product_analytics_views
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_simulation_testing_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.product_analytics_views TO finos_app;