-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 11 - Integration Api Management
-- TABLE: dynamic_history.service_call_correlation
-- COMPLIANCE: ISO 20022
--   - ISO 27001
--   - OpenAPI
--   - GDPR
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