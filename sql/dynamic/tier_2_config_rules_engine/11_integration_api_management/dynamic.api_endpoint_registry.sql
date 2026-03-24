-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 11 - Integration Api Management
-- TABLE: dynamic.api_endpoint_registry
-- COMPLIANCE: ISO 20022
--   - ISO 27001
--   - OpenAPI
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.api_endpoint_registry (

    endpoint_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Endpoint Definition
    endpoint_path VARCHAR(200) NOT NULL,
    http_method VARCHAR(10) NOT NULL CHECK (http_method IN ('GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS')),
    endpoint_name VARCHAR(200) NOT NULL,
    endpoint_description TEXT,
    
    -- Grouping
    api_version VARCHAR(20) DEFAULT 'v1',
    api_group VARCHAR(100),
    
    -- Authentication
    auth_type dynamic.api_auth_type NOT NULL,
    auth_config JSONB, -- OAuth2 scopes, API key header, etc.
    
    -- Rate Limiting
    rate_limit_per_minute INTEGER DEFAULT 60,
    rate_limit_per_hour INTEGER,
    rate_limit_per_day INTEGER,
    
    -- Security
    allowed_ip_ranges INET[],
    blocked_ip_ranges INET[],
    require_mtls BOOLEAN DEFAULT FALSE,
    
    -- Performance
    timeout_seconds INTEGER DEFAULT 30,
    cache_ttl_seconds INTEGER,
    
    -- Backend
    backend_service_url VARCHAR(500),
    backend_service_timeout INTEGER DEFAULT 30,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_deprecated BOOLEAN DEFAULT FALSE,
    deprecation_date DATE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_endpoint_path UNIQUE (tenant_id, api_version, endpoint_path, http_method)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.api_endpoint_registry_default PARTITION OF dynamic.api_endpoint_registry DEFAULT;

-- Indexes
CREATE INDEX idx_api_endpoint_tenant ON dynamic.api_endpoint_registry(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_api_endpoint_path ON dynamic.api_endpoint_registry(tenant_id, endpoint_path);

-- Comments
COMMENT ON TABLE dynamic.api_endpoint_registry IS 'External API interface definitions';

-- Triggers
CREATE TRIGGER trg_api_endpoint_audit
    BEFORE UPDATE ON dynamic.api_endpoint_registry
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.api_endpoint_registry TO finos_app;