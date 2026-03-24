-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 12 - Performance Operations
-- TABLE: dynamic_history.query_performance_log
-- COMPLIANCE: ITIL
--   - ISO 20000
--   - ISO 27001
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic_history.query_performance_log (

    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Query Details
    query_hash VARCHAR(64) NOT NULL,
    query_text TEXT,
    query_normalized TEXT,
    
    -- Execution Stats
    calls BIGINT DEFAULT 0,
    total_time_ms DECIMAL(20,4),
    avg_time_ms DECIMAL(20,4),
    max_time_ms DECIMAL(20,4),
    min_time_ms DECIMAL(20,4),
    
    -- Resource Usage
    shared_blks_hit BIGINT,
    shared_blks_read BIGINT,
    temp_blks_written BIGINT,
    
    -- Time Period
    log_period TIMESTAMPTZ NOT NULL, -- Hour bucket
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_query_period UNIQUE (tenant_id, query_hash, log_period)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.query_performance_log_default PARTITION OF dynamic_history.query_performance_log DEFAULT;

-- Indexes
CREATE INDEX idx_query_perf_hash ON dynamic_history.query_performance_log(tenant_id, query_hash);
CREATE INDEX idx_query_perf_period ON dynamic_history.query_performance_log(log_period DESC);
CREATE INDEX idx_query_perf_slow ON dynamic_history.query_performance_log(tenant_id, avg_time_ms DESC) WHERE avg_time_ms > 1000;

-- Comments
COMMENT ON TABLE dynamic_history.query_performance_log IS 'Query performance statistics by hour';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.query_performance_log TO finos_app;