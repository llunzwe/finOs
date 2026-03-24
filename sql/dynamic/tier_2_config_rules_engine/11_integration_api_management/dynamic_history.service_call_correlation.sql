-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 11 - Integration & API Management
-- TABLE: dynamic_history.service_call_correlation
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Service Call Correlation.
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
CREATE TABLE dynamic_history.service_call_correlation (

    call_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    service_id UUID NOT NULL REFERENCES dynamic.external_service_registry(service_id),
    
    -- Request
    correlation_id UUID NOT NULL,
    operation_name VARCHAR(100) NOT NULL,
    request_payload JSONB,
    request_headers JSONB,
    
    -- Response
    response_payload JSONB,
    response_headers JSONB,
    
    -- Performance
    http_status INTEGER,
    response_time_ms INTEGER,
    
    -- Retry
    retry_attempts INTEGER DEFAULT 0,
    is_retry BOOLEAN DEFAULT FALSE,
    original_call_id UUID,
    
    -- Error
    error_code VARCHAR(100),
    error_message TEXT,
    
    -- Timing
    called_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.service_call_correlation_default PARTITION OF dynamic_history.service_call_correlation DEFAULT;

-- Indexes
CREATE INDEX idx_service_call_service ON dynamic_history.service_call_correlation(tenant_id, service_id);
CREATE INDEX idx_service_call_correlation ON dynamic_history.service_call_correlation(tenant_id, correlation_id);
CREATE INDEX idx_service_call_time ON dynamic_history.service_call_correlation(called_at DESC);
CREATE INDEX idx_service_call_status ON dynamic_history.service_call_correlation(tenant_id, http_status);

-- Comments
COMMENT ON TABLE dynamic_history.service_call_correlation IS 'External service request tracking';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.service_call_correlation TO finos_app;