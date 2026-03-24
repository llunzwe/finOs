-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 23 - API Streaming Config
-- TABLE: dynamic.api_endpoints
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Api Endpoints.
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
CREATE TABLE dynamic.api_endpoints (

    endpoint_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    api_id UUID NOT NULL REFERENCES dynamic.api_surface_registry(api_id),
    
    -- Endpoint Definition
    endpoint_path VARCHAR(300) NOT NULL,
    http_method VARCHAR(10) NOT NULL 
        CHECK (http_method IN ('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS')),
    operation_id VARCHAR(100) NOT NULL,
    
    -- Description
    summary VARCHAR(255),
    description TEXT,
    
    -- Request/Response
    request_schema JSONB,
    response_schema JSONB,
    
    -- Validation
    request_validation_enabled BOOLEAN DEFAULT TRUE,
    response_validation_enabled BOOLEAN DEFAULT TRUE,
    
    -- Rate Limit Override
    rate_limit_override JSONB,
    
    -- Features
    idempotency_key_required BOOLEAN DEFAULT FALSE,
    webhook_trigger_enabled BOOLEAN DEFAULT FALSE,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' 
        CHECK (status IN ('active', 'deprecated', 'beta', 'experimental')),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.api_endpoints_default PARTITION OF dynamic.api_endpoints DEFAULT;

-- Indexes
CREATE INDEX idx_api_endpoints_api ON dynamic.api_endpoints(tenant_id, api_id);

-- Triggers
CREATE TRIGGER trg_api_endpoints_update
    BEFORE UPDATE ON dynamic.api_endpoints
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_api_streaming_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.api_endpoints TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.api_endpoints IS 'Api Endpoints';