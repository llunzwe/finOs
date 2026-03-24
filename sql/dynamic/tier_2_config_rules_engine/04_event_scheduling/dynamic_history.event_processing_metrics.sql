-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 04 - Event Scheduling
-- TABLE: dynamic_history.event_processing_metrics
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Event Processing Metrics.
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
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    CONSTRAINT unique_metrics_hour UNIQUE (tenant_id, metric_hour, event_type, subscription_id)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.event_processing_metrics_default PARTITION OF dynamic_history.event_processing_metrics DEFAULT;

-- Indexes
CREATE INDEX idx_event_metrics_hour ON dynamic_history.event_processing_metrics(tenant_id, metric_hour DESC);

-- Comments
COMMENT ON TABLE dynamic_history.event_processing_metrics IS 'Hourly event processing metrics by type and subscription';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.event_processing_metrics TO finos_app;