-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 21 - Integration Hooks
-- TABLE: dynamic.external_service_configs
-- COMPLIANCE: ISO 20022
--   - ISO 27001
--   - GDPR
--   - SOX
-- ============================================================================


CREATE TABLE dynamic.external_service_configs (

    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    service_code VARCHAR(100) NOT NULL,
    service_name VARCHAR(200) NOT NULL,
    service_description TEXT,
    
    -- Provider
    provider_name VARCHAR(100) NOT NULL, -- Jumio, Stripe, Experian, etc.
    provider_category VARCHAR(50) NOT NULL 
        CHECK (provider_category IN ('KYC', 'PAYMENT', 'BUREAU', 'FRAUD', 'SMS', 'EMAIL', 'SANCTIONS', 'TAX', 'ACCOUNTING', 'CLOUD_STORAGE')),
    
    -- Connection
    api_base_url VARCHAR(500) NOT NULL,
    api_version VARCHAR(20),
    auth_type dynamic.api_auth_type NOT NULL,
    
    -- Credentials (encrypted)
    api_key_encrypted BYTEA,
    api_secret_encrypted BYTEA,
    oauth_client_id_encrypted BYTEA,
    oauth_client_secret_encrypted BYTEA,
    certificate_encrypted BYTEA,
    
    -- Configuration
    connection_config JSONB, -- {timeout: 30, retry_attempts: 3, ...}
    rate_limit_requests_per_minute INTEGER DEFAULT 60,
    rate_limit_requests_per_day INTEGER,
    
    -- Webhook
    webhook_url VARCHAR(500),
    webhook_events VARCHAR(100)[],
    webhook_secret_encrypted BYTEA,
    webhook_verification_method VARCHAR(50), -- HMAC, SIGNATURE, etc.
    
    -- Features
    supported_operations JSONB, -- [{operation: 'verify_identity', enabled: true}, ...]
    supported_countries CHAR(2)[],
    supported_currencies CHAR(3)[],
    
    -- Circuit Breaker
    circuit_breaker_enabled BOOLEAN DEFAULT TRUE,
    circuit_breaker_failure_threshold INTEGER DEFAULT 5,
    circuit_breaker_recovery_timeout_seconds INTEGER DEFAULT 300,
    
    -- Cost Tracking
    cost_per_request DECIMAL(28,8),
    cost_currency CHAR(3),
    monthly_budget_limit DECIMAL(28,8),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    health_status VARCHAR(20) DEFAULT 'UNKNOWN', -- HEALTHY, DEGRADED, DOWN
    last_health_check_at TIMESTAMPTZ,
    last_successful_call_at TIMESTAMPTZ,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_external_service_code UNIQUE (tenant_id, service_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.external_service_configs_default PARTITION OF dynamic.external_service_configs DEFAULT;

-- Indexes
CREATE INDEX idx_external_service_tenant ON dynamic.external_service_configs(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_external_service_provider ON dynamic.external_service_configs(tenant_id, provider_name) WHERE is_active = TRUE;
CREATE INDEX idx_external_service_category ON dynamic.external_service_configs(tenant_id, provider_category) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.external_service_configs IS 'Third-party service integrations (Jumio, Stripe, bureaus)';

-- Triggers
CREATE TRIGGER trg_external_service_configs_audit
    BEFORE UPDATE ON dynamic.external_service_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.external_service_configs TO finos_app;