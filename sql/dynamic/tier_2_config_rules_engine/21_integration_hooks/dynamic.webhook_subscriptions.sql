-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 21 - Integration Hooks
-- TABLE: dynamic.webhook_subscriptions
-- COMPLIANCE: ISO 20022
--   - ISO 27001
--   - GDPR
--   - SOX
-- ============================================================================


CREATE TABLE dynamic.webhook_subscriptions (

    subscription_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    subscription_name VARCHAR(200) NOT NULL,
    subscription_description TEXT,
    
    -- Event Filter
    event_types VARCHAR(100)[] NOT NULL, -- [payment.success, account.created, ...]
    event_filter_expression JSONB, -- Additional JSONLogic filter
    
    -- Endpoint
    endpoint_url VARCHAR(500) NOT NULL,
    endpoint_method VARCHAR(10) DEFAULT 'POST',
    endpoint_headers JSONB, -- {Authorization: 'Bearer ...', X-Custom-Header: '...'}
    
    -- Payload
    payload_format VARCHAR(20) DEFAULT 'JSON' CHECK (payload_format IN ('JSON', 'XML', 'FORM')),
    payload_template TEXT, -- Custom payload template
    payload_signature_enabled BOOLEAN DEFAULT TRUE,
    signature_algorithm VARCHAR(50) DEFAULT 'HMAC_SHA256', -- HMAC_SHA256, RSA_SHA256
    signature_secret_encrypted BYTEA,
    signature_header_name VARCHAR(50) DEFAULT 'X-Webhook-Signature',
    
    -- Authentication
    auth_type dynamic.api_auth_type DEFAULT 'NONE',
    auth_credentials_encrypted BYTEA,
    
    -- Retry Policy
    retry_policy JSONB DEFAULT '{
        "max_retries": 3,
        "backoff_type": "exponential",
        "initial_interval_ms": 1000,
        "max_interval_ms": 60000,
        "retry_http_codes": [408, 429, 500, 502, 503, 504]
    }'::jsonb,
    
    -- Circuit Breaker
    circuit_breaker_enabled BOOLEAN DEFAULT TRUE,
    circuit_breaker_threshold INTEGER DEFAULT 10,
    circuit_breaker_window_minutes INTEGER DEFAULT 5,
    
    -- Delivery
    delivery_order VARCHAR(20) DEFAULT 'UNORDERED' CHECK (delivery_order IN ('ORDERED', 'UNORDERED')),
    batching_enabled BOOLEAN DEFAULT FALSE,
    batch_size INTEGER,
    batch_interval_seconds INTEGER,
    
    -- Security
    ip_allowlist INET[],
    tls_verify BOOLEAN DEFAULT TRUE,
    
    -- Monitoring
    alert_on_failure BOOLEAN DEFAULT TRUE,
    alert_threshold_failures INTEGER DEFAULT 10,
    
    -- Statistics
    events_delivered BIGINT DEFAULT 0,
    events_failed BIGINT DEFAULT 0,
    last_delivered_at TIMESTAMPTZ,
    last_failed_at TIMESTAMPTZ,
    last_error_message TEXT,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    paused BOOLEAN DEFAULT FALSE,
    paused_at TIMESTAMPTZ,
    paused_reason TEXT,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.webhook_subscriptions_default PARTITION OF dynamic.webhook_subscriptions DEFAULT;

-- Indexes
CREATE INDEX idx_webhook_subs_tenant ON dynamic.webhook_subscriptions(tenant_id) WHERE is_active = TRUE AND paused = FALSE;
CREATE INDEX idx_webhook_subs_events ON dynamic.webhook_subscriptions(tenant_id, event_types) WHERE is_active = TRUE AND paused = FALSE;

-- Comments
COMMENT ON TABLE dynamic.webhook_subscriptions IS 'Outbound webhook event subscriptions';

-- Triggers
CREATE TRIGGER trg_webhook_subscriptions_audit
    BEFORE UPDATE ON dynamic.webhook_subscriptions
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.webhook_subscriptions TO finos_app;