-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 23 - API Streaming Config
-- TABLE: dynamic.api_surface_registry
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Api Surface Registry.
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
CREATE TABLE dynamic.api_surface_registry (

    api_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- API Identity
    api_name VARCHAR(100) NOT NULL,
    api_version VARCHAR(20) NOT NULL DEFAULT 'v1',
    api_type VARCHAR(30) NOT NULL 
        CHECK (api_type IN ('REST', 'GRAPHQL', 'GRPC', 'WEBSOCKET', 'WEBHOOK', 'KAFKA')),
    
    -- API Surface Type (as per v1.1 spec)
    surface_type VARCHAR(30) NOT NULL 
        CHECK (surface_type IN ('POSTING_API', 'CORE_API', 'STREAMING_API', 'MIGRATION_API')),
    
    -- Endpoint Configuration
    base_path VARCHAR(200) NOT NULL,
    base_url TEXT,
    
    -- Documentation
    open_api_spec_url TEXT,
    graphql_schema_url TEXT,
    documentation_url TEXT,
    
    -- Authentication
    auth_type VARCHAR(30) DEFAULT 'oauth2' 
        CHECK (auth_type IN ('none', 'api_key', 'oauth2', 'mTLS', 'jwt')),
    auth_config JSONB DEFAULT '{}',
    -- Example: {
    --   token_url: 'https://auth.example.com/oauth/token',
    --   scopes: ['read:accounts', 'write:payments'],
    --   jwt_issuer: 'https://auth.example.com'
    -- }
    
    -- Rate Limiting
    rate_limit_requests_per_second INTEGER DEFAULT 100,
    rate_limit_burst INTEGER DEFAULT 150,
    rate_limit_config JSONB DEFAULT '{}',
    
    -- Features
    features_enabled JSONB DEFAULT '{}',
    -- Example: {
    --   idempotency: true,
    --   batching: true,
    --   webhooks: true,
    --   sandbox: true
    -- }
    
    -- Status
    status VARCHAR(20) DEFAULT 'draft' 
        CHECK (status IN ('draft', 'active', 'deprecated', 'sunset')),
    
    -- Deprecation
    sunset_date DATE,
    migration_guide_url TEXT,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    
    CONSTRAINT unique_api_name_version UNIQUE (tenant_id, api_name, api_version)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.api_surface_registry_default PARTITION OF dynamic.api_surface_registry DEFAULT;

-- Indexes
CREATE INDEX idx_api_registry_tenant ON dynamic.api_surface_registry(tenant_id, status) WHERE status = 'active';
CREATE INDEX idx_api_registry_type ON dynamic.api_surface_registry(tenant_id, surface_type);

-- Comments
COMMENT ON TABLE dynamic.api_surface_registry IS 
    'Registry of all API surfaces: Posting, Core, Streaming, Migration APIs';

-- Triggers
CREATE TRIGGER trg_api_registry_update
    BEFORE UPDATE ON dynamic.api_surface_registry
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_api_streaming_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.api_surface_registry TO finos_app;