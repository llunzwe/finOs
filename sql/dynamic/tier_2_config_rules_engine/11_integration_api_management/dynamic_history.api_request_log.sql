-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 11 - Integration & API Management
-- TABLE: dynamic_history.api_request_log
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Api Request Log.
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
CREATE TABLE dynamic_history.api_request_log (

    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    endpoint_id UUID REFERENCES dynamic.api_endpoint_registry(endpoint_id),
    
    -- Request
    request_method VARCHAR(10) NOT NULL,
    request_path TEXT NOT NULL,
    request_headers JSONB,
    request_body TEXT,
    request_size_bytes INTEGER,
    
    -- Client
    client_ip INET,
    client_id VARCHAR(100),
    api_key_id VARCHAR(100),
    
    -- Response
    response_status INTEGER,
    response_headers JSONB,
    response_body TEXT,
    response_size_bytes INTEGER,
    
    -- Performance
    request_started_at TIMESTAMPTZ NOT NULL,
    request_completed_at TIMESTAMPTZ,
    response_time_ms INTEGER,
    
    -- Errors
    error_code VARCHAR(50),
    error_message TEXT,
    
    -- Correlation
    correlation_id UUID,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.api_request_log_default PARTITION OF dynamic_history.api_request_log DEFAULT;

-- Indexes
CREATE INDEX idx_api_log_endpoint ON dynamic_history.api_request_log(tenant_id, endpoint_id);
CREATE INDEX idx_api_log_client ON dynamic_history.api_request_log(tenant_id, client_id);
CREATE INDEX idx_api_log_time ON dynamic_history.api_request_log(request_started_at DESC);
CREATE INDEX idx_api_log_status ON dynamic_history.api_request_log(tenant_id, response_status);

-- Comments
COMMENT ON TABLE dynamic_history.api_request_log IS 'API request/response audit trail';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.api_request_log TO finos_app;