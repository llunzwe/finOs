-- =============================================================================
-- FINOS CORE KERNEL - WEBHOOK SYSTEM
-- =============================================================================
-- File: 006_webhook.sql
-- Description: Webhook subscriptions, deliveries, and retry logic
-- =============================================================================

-- SECTION 16: WEBHOOK SYSTEM
-- =============================================================================

CREATE TABLE core.webhook_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    
    -- Subscriber
    subscriber_name VARCHAR(100) NOT NULL,
    subscriber_type VARCHAR(50) NOT NULL CHECK (subscriber_type IN ('internal', 'external', 'partner', 'regulator')),
    
    -- Endpoint
    webhook_url TEXT NOT NULL,
    webhook_method VARCHAR(10) DEFAULT 'POST' CHECK (webhook_method IN ('POST', 'PUT', 'PATCH')),
    
    -- Event Filtering
    event_types TEXT[] NOT NULL, -- ['movement.posted', 'container.created']
    event_categories TEXT[], -- ['movement', 'container', 'agent']
    
    -- Security
    secret_key_encrypted BYTEA, -- For HMAC-SHA256 signature
    signature_algorithm VARCHAR(20) DEFAULT 'HMAC-SHA256',
    auth_type VARCHAR(20) DEFAULT 'none' CHECK (auth_type IN ('none', 'bearer', 'basic', 'api_key')),
    auth_credentials_encrypted BYTEA,
    
    -- Retry Configuration
    max_retries INTEGER DEFAULT 3,
    retry_backoff_seconds INTEGER DEFAULT 60,
    timeout_seconds INTEGER DEFAULT 30,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'paused', 'failed', 'disabled')),
    failure_count INTEGER DEFAULT 0,
    last_failure_at TIMESTAMPTZ,
    last_failure_reason TEXT,
    last_success_at TIMESTAMPTZ,
    
    -- Temporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    CONSTRAINT unique_webhook_url UNIQUE (tenant_id, webhook_url, valid_from)
);

CREATE INDEX idx_webhook_subscriptions_active ON core.webhook_subscriptions(tenant_id, status) WHERE status = 'active';
CREATE INDEX idx_webhook_subscriptions_event ON core.webhook_subscriptions USING GIN(event_types);

COMMENT ON TABLE core.webhook_subscriptions IS 'Webhook event subscriptions with HMAC signatures';

CREATE TABLE core.webhook_deliveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    subscription_id UUID NOT NULL REFERENCES core.webhook_subscriptions(id),
    
    -- Event Reference
    event_id BIGINT,
    event_type VARCHAR(100) NOT NULL,
    event_payload JSONB,
    
    -- Delivery Attempt
    attempt_number INTEGER NOT NULL DEFAULT 1,
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'delivered', 'failed', 'retrying')),
    
    -- Request Details
    request_headers JSONB,
    request_body JSONB,
    request_signature VARCHAR(128),
    
    -- Response Details
    response_status INTEGER,
    response_headers JSONB,
    response_body TEXT,
    response_time_ms INTEGER,
    
    -- Error Details
    error_message TEXT,
    error_code VARCHAR(50),
    
    -- Timing
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    attempted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    next_retry_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

SELECT create_hypertable('core.webhook_deliveries', 'created_at', 
                         chunk_time_interval => INTERVAL '1 week',
                         if_not_exists => TRUE);

CREATE INDEX idx_webhook_deliveries_pending ON core.webhook_deliveries(status, scheduled_at) WHERE status IN ('pending', 'retrying');
CREATE INDEX idx_webhook_deliveries_subscription ON core.webhook_deliveries(subscription_id, created_at DESC);

COMMENT ON TABLE core.webhook_deliveries IS 'Webhook delivery attempts with retry tracking';

-- =============================================================================
