-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 11 - Integration Api Management
-- TABLE: dynamic_history.service_health_metrics
-- COMPLIANCE: ISO 20022
--   - ISO 27001
--   - OpenAPI
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic_history.service_health_metrics (

    metric_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    service_id UUID NOT NULL REFERENCES dynamic.external_service_registry(service_id),
    
    -- Time Bucket
    metric_hour TIMESTAMPTZ NOT NULL,
    
    -- Availability
    uptime_percentage DECIMAL(5,2),
    downtime_minutes INTEGER,
    
    -- Performance
    avg_response_time_ms INTEGER,
    p95_response_time_ms INTEGER,
    p99_response_time_ms INTEGER,
    
    -- Volume
    request_count INTEGER,
    success_count INTEGER,
    error_count INTEGER,
    timeout_count INTEGER,
    
    -- Errors
    error_breakdown JSONB, -- {error_code: count}
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_service_hour UNIQUE (tenant_id, service_id, metric_hour)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.service_health_metrics_default PARTITION OF dynamic_history.service_health_metrics DEFAULT;

-- Indexes
CREATE INDEX idx_service_health_service ON dynamic_history.service_health_metrics(tenant_id, service_id);
CREATE INDEX idx_service_health_hour ON dynamic_history.service_health_metrics(metric_hour DESC);

-- Comments
COMMENT ON TABLE dynamic_history.service_health_metrics IS 'Hourly service health and performance metrics';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.service_health_metrics TO finos_app;