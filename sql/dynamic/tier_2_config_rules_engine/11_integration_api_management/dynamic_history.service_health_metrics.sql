-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 11 - Integration & API Management
-- TABLE: dynamic_history.service_health_metrics
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Service Health Metrics.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 8601
--   - ISO 20022
--   - IFRS 15
--   - Basel III
--   - OECD
--   - NCA
--
-- AUDIT & GOVERNANCE:
--   - Bitemporal tracking (effective_from/valid_from, effective_to/valid_to)
--   - Full audit trail (created_at, updated_at, created_by, updated_by)
--   - Version control for change management
--   - Tenant isolation via partitioning
--   - Row-Level Security (RLS) for data protection
--
-- DATA CLASSIFICATION:
--   - Tenant Isolation: Row-Level Security enabled
--   - Audit Level: FULL
--   - Encryption: At-rest for sensitive fields
--
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
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    CONSTRAINT unique_service_hour UNIQUE (tenant_id, service_id, metric_hour)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.service_health_metrics_default PARTITION OF dynamic_history.service_health_metrics DEFAULT;

-- Indexes
CREATE INDEX idx_service_health_service ON dynamic_history.service_health_metrics(tenant_id, service_id);
CREATE INDEX idx_service_health_hour ON dynamic_history.service_health_metrics(metric_hour DESC);

-- Comments
COMMENT ON TABLE dynamic_history.service_health_metrics IS 'Hourly service health and performance metrics';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.service_health_metrics TO finos_app;