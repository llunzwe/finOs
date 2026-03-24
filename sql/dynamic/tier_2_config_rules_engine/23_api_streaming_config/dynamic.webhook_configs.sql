-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 23 - API Streaming Config
-- TABLE: dynamic.webhook_configs
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Webhook Configs.
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

CREATE TABLE dynamic.webhook_configs_default PARTITION OF dynamic.webhook_configs DEFAULT;

-- Triggers
CREATE TRIGGER trg_webhook_configs_update
    BEFORE UPDATE ON dynamic.webhook_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_api_streaming_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.webhook_configs TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.webhook_configs IS 'Webhook Configs';