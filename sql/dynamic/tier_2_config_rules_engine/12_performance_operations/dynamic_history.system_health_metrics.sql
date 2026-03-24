-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 12 - Performance Operations
-- TABLE: dynamic_history.system_health_metrics
-- COMPLIANCE: ITIL
--   - ISO 20000
--   - ISO 27001
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic_history.system_health_metrics (

    metric_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Metric Details
    metric_name VARCHAR(100) NOT NULL,
    metric_category VARCHAR(50), -- CPU, MEMORY, DISK, DATABASE, APPLICATION
    metric_unit VARCHAR(50),
    
    -- Value
    metric_value DECIMAL(20,8) NOT NULL,
    metric_value_text TEXT,
    
    -- Thresholds
    threshold_warning DECIMAL(20,8),
    threshold_critical DECIMAL(20,8),
    
    -- Status
    alert_status VARCHAR(20) GENERATED ALWAYS AS (
        CASE 
            WHEN threshold_critical IS NOT NULL AND metric_value >= threshold_critical THEN 'CRITICAL'
            WHEN threshold_warning IS NOT NULL AND metric_value >= threshold_warning THEN 'WARNING'
            ELSE 'NORMAL'
        END
    ) STORED,
    
    -- Context
    affected_tenants UUID[],
    affected_services TEXT[],
    metric_tags JSONB,
    
    -- Timestamp
    measurement_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.system_health_metrics_default PARTITION OF dynamic_history.system_health_metrics DEFAULT;

-- Indexes
CREATE INDEX idx_health_metric_name ON dynamic_history.system_health_metrics(tenant_id, metric_name);
CREATE INDEX idx_health_metric_time ON dynamic_history.system_health_metrics(measurement_timestamp DESC);
CREATE INDEX idx_health_metric_alert ON dynamic_history.system_health_metrics(tenant_id, alert_status) WHERE alert_status IN ('WARNING', 'CRITICAL');

-- Comments
COMMENT ON TABLE dynamic_history.system_health_metrics IS 'System health monitoring metrics with SLA thresholds';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.system_health_metrics TO finos_app;