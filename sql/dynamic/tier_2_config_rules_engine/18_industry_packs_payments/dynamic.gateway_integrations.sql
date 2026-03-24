-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 18 - Industry Packs Payments
-- TABLE: dynamic.gateway_integrations
-- COMPLIANCE: PSD2
--   - PCI DSS
--   - ISO 20022
--   - NPS
-- ============================================================================


CREATE TABLE dynamic.gateway_integrations (

    integration_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    gateway_code VARCHAR(100) NOT NULL,
    gateway_name VARCHAR(200) NOT NULL,
    gateway_description TEXT,
    
    -- Provider
    provider_name VARCHAR(100) NOT NULL, -- Stripe, Adyen, PayPal, etc.
    provider_type VARCHAR(50) NOT NULL, -- PAYMENT_GATEWAY, PROCESSOR, AGGREGATOR
    
    -- Connection
    api_base_url VARCHAR(500) NOT NULL,
    api_version VARCHAR(20),
    auth_type dynamic.api_auth_type NOT NULL,
    auth_config JSONB, -- Encrypted credentials config
    
    -- Supported Methods
    supported_payment_methods UUID[], -- References payment_method_configs
    supported_currencies CHAR(3)[],
    supported_countries CHAR(2)[],
    
    -- Features
    supports_3ds BOOLEAN DEFAULT TRUE,
    supports_tokenization BOOLEAN DEFAULT TRUE,
    supports_webhooks BOOLEAN DEFAULT TRUE,
    supports_refunds BOOLEAN DEFAULT TRUE,
    supports_authorization BOOLEAN DEFAULT TRUE, -- Pre-auth/capture
    supports_delayed_capture BOOLEAN DEFAULT FALSE,
    
    -- Routing
    routing_priority INTEGER DEFAULT 0,
    routing_rules JSONB, -- [{condition: 'amount > 1000', priority: 1}, ...]
    failover_gateway_id UUID REFERENCES dynamic.gateway_integrations(integration_id),
    
    -- Performance
    timeout_seconds INTEGER DEFAULT 30,
    retry_attempts INTEGER DEFAULT 3,
    retry_backoff_ms INTEGER DEFAULT 1000,
    
    -- Webhook
    webhook_url VARCHAR(500),
    webhook_events VARCHAR(50)[], -- payment.success, payment.failed, etc.
    webhook_secret_encrypted BYTEA,
    
    -- Circuit Breaker
    circuit_breaker_enabled BOOLEAN DEFAULT TRUE,
    circuit_breaker_threshold INTEGER DEFAULT 5,
    circuit_breaker_recovery_seconds INTEGER DEFAULT 300,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_primary BOOLEAN DEFAULT FALSE,
    health_status VARCHAR(20) DEFAULT 'UNKNOWN', -- HEALTHY, DEGRADED, DOWN
    last_health_check TIMESTAMPTZ,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_gateway_code UNIQUE (tenant_id, gateway_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.gateway_integrations_default PARTITION OF dynamic.gateway_integrations DEFAULT;

-- Indexes
CREATE INDEX idx_gateway_tenant ON dynamic.gateway_integrations(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_gateway_provider ON dynamic.gateway_integrations(tenant_id, provider_name) WHERE is_active = TRUE;
CREATE INDEX idx_gateway_status ON dynamic.gateway_integrations(tenant_id, health_status);

-- Comments
COMMENT ON TABLE dynamic.gateway_integrations IS 'Payment gateway integrations with failover and routing';

-- Triggers
CREATE TRIGGER trg_gateway_integrations_audit
    BEFORE UPDATE ON dynamic.gateway_integrations
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.gateway_integrations TO finos_app;