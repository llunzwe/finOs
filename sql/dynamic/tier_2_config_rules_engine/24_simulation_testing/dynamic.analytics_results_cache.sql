-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 24 - Simulation Testing
-- TABLE: dynamic.analytics_results_cache
-- COMPLIANCE: ISTQB
--   - Basel
--   - SOX
--   - ITIL
-- ============================================================================


CREATE TABLE dynamic.analytics_results_cache (

    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    view_id UUID NOT NULL REFERENCES dynamic.product_analytics_views(view_id),
    
    -- Cache Key
    cache_key VARCHAR(200) NOT NULL,
    
    -- Results
    results_jsonb JSONB NOT NULL,
    result_hash VARCHAR(64), -- For change detection
    
    -- Metadata
    record_count INTEGER,
    calculation_time_ms INTEGER,
    
    -- Validity
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.analytics_results_cache_default PARTITION OF dynamic.analytics_results_cache DEFAULT;

-- Indexes
CREATE INDEX idx_analytics_cache_view ON dynamic.analytics_results_cache(tenant_id, view_id, valid_until);

GRANT SELECT, INSERT, UPDATE ON dynamic.analytics_results_cache TO finos_app;