-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 23 - Api Streaming Config
-- TABLE: dynamic.webhook_configs
-- COMPLIANCE: OpenAPI
--   - OAuth 2.0
--   - ISO 20022
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.webhook_configs (

    webhook_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    webhook_name VARCHAR(100) NOT NULL,
    
    -- Endpoint
    url TEXT NOT NULL,
    method VARCHAR(10) DEFAULT 'POST',
    
    -- Authentication
    auth_type VARCHAR(30) DEFAULT 'hmac' 
        CHECK (auth_type IN ('none', 'hmac', 'bearer', 'basic')),
    auth_config JSONB DEFAULT '{}',
    -- HMAC: {secret: '...', header: 'X-Webhook-Signature', algorithm: 'sha256'}
    -- Bearer: {token: '...', header: 'Authorization'}
    
    -- Events
    event_types TEXT[] NOT NULL,
    
    -- Retry
    max_retries INTEGER DEFAULT 3,
    retry_interval_seconds INTEGER DEFAULT 60,
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.webhook_configs_default PARTITION OF dynamic.webhook_configs DEFAULT;

-- Triggers
CREATE TRIGGER trg_webhook_configs_update
    BEFORE UPDATE ON dynamic.webhook_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_api_streaming_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.webhook_configs TO finos_app;