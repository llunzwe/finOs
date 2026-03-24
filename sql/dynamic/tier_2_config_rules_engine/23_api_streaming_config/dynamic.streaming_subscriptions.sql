-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 23 - Api Streaming Config
-- TABLE: dynamic.streaming_subscriptions
-- COMPLIANCE: OpenAPI
--   - OAuth 2.0
--   - ISO 20022
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.streaming_subscriptions (

    subscription_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Subscription Identity
    subscription_name VARCHAR(100) NOT NULL,
    subscription_type VARCHAR(30) NOT NULL 
        CHECK (subscription_type IN ('KAFKA', 'WEBHOOK', 'WEBSOCKET', 'SQS', 'PUBSUB', 'EVENTBRIDGE')),
    
    -- Event Types (Vault/Marqeta style)
    event_types TEXT[] NOT NULL,
    -- Examples:
    -- accounting.* - All accounting events
    -- balance.updated - Balance changes
    -- status.transitioned - Status changes
    -- mutation.ledger - Ledger mutations
    -- auth.approved, auth.declined - Authorization events
    -- settlement.completed - Settlement finality
    
    -- Filters
    event_filters JSONB DEFAULT '{}',
    -- Example: {
    --   transaction_types: ['purchase', 'refund'],
    --   currency: ['USD', 'EUR'],
    --   min_amount: 100.00
    -- }
    
    -- Delivery Configuration
    delivery_config JSONB NOT NULL DEFAULT '{}',
    -- Kafka: {topic: 'finos-events', partition: 0, compression: 'snappy'}
    -- Webhook: {url: 'https://...', method: 'POST', secret: '...', retry_policy: {...}}
    -- WebSocket: {endpoint: '/ws/events', auth_required: true}
    
    -- Delivery Mode
    delivery_mode VARCHAR(20) DEFAULT 'push' 
        CHECK (delivery_mode IN ('push', 'pull', 'hybrid')),
    
    -- Retry Configuration
    max_retries INTEGER DEFAULT 3,
    retry_backoff_ms INTEGER DEFAULT 1000,
    retry_backoff_multiplier DECIMAL(3,2) DEFAULT 2.00,
    
    -- Cursor Management
    cursor_strategy VARCHAR(20) DEFAULT 'event_id' 
        CHECK (cursor_strategy IN ('event_id', 'timestamp', 'offset')),
    last_delivered_event_id UUID,
    last_delivered_at TIMESTAMPTZ,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' 
        CHECK (status IN ('active', 'paused', 'error', 'disabled')),
    
    -- Circuit Breaker
    circuit_breaker_enabled BOOLEAN DEFAULT TRUE,
    circuit_breaker_failure_threshold INTEGER DEFAULT 5,
    circuit_breaker_recovery_timeout_seconds INTEGER DEFAULT 60,
    circuit_breaker_last_failure_at TIMESTAMPTZ,
    
    -- Error Tracking
    consecutive_failures INTEGER DEFAULT 0,
    last_error_message TEXT,
    last_error_at TIMESTAMPTZ,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    CONSTRAINT unique_subscription_name UNIQUE (tenant_id, subscription_name)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.streaming_subscriptions_default PARTITION OF dynamic.streaming_subscriptions DEFAULT;

-- Indexes
CREATE INDEX idx_streaming_subs_tenant ON dynamic.streaming_subscriptions(tenant_id, status) WHERE status = 'active';
CREATE INDEX idx_streaming_subs_type ON dynamic.streaming_subscriptions(tenant_id, subscription_type);

-- Comments
COMMENT ON TABLE dynamic.streaming_subscriptions IS 
    'Exact Vault + Marqeta events - accounting, balance, status, mutation streaming';

-- Triggers
CREATE TRIGGER trg_streaming_subs_update
    BEFORE UPDATE ON dynamic.streaming_subscriptions
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_api_streaming_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.streaming_subscriptions TO finos_app;