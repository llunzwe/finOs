-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 04 - Event Scheduling
-- TABLE: dynamic_history.event_processing_metrics
-- COMPLIANCE: ISO 8601
--   - ISO 20022
--   - ISO 25010
--   - GDPR
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic_history.event_processing_metrics (

    metric_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Time bucket
    metric_hour TIMESTAMPTZ NOT NULL,
    
    -- Dimensions
    event_type VARCHAR(100),
    subscription_id UUID,
    
    -- Metrics
    events_received BIGINT DEFAULT 0,
    events_delivered BIGINT DEFAULT 0,
    events_failed BIGINT DEFAULT 0,
    events_dlq BIGINT DEFAULT 0,
    
    -- Latency
    avg_latency_ms INTEGER,
    max_latency_ms INTEGER,
    p95_latency_ms INTEGER,
    p99_latency_ms INTEGER,
    
    -- Created
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_metrics_hour UNIQUE (tenant_id, metric_hour, event_type, subscription_id)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.event_processing_metrics_default PARTITION OF dynamic_history.event_processing_metrics DEFAULT;

-- Indexes
CREATE INDEX idx_event_metrics_hour ON dynamic_history.event_processing_metrics(tenant_id, metric_hour DESC);

-- Comments
COMMENT ON TABLE dynamic_history.event_processing_metrics IS 'Hourly event processing metrics by type and subscription';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.event_processing_metrics TO finos_app;