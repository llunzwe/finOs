-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Enterprise Extensions
-- TABLE: dynamic.channel_config
--
-- DESCRIPTION:
--   Enterprise-grade communication channel configuration.
--   SMS gateways, email providers, push notification services.
--
-- ============================================================================


CREATE TABLE dynamic.channel_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Channel Identification
    channel_name VARCHAR(100) NOT NULL,
    channel_type VARCHAR(50) NOT NULL 
        CHECK (channel_type IN ('EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP')),
    
    -- Provider Configuration
    provider_name VARCHAR(100) NOT NULL, -- 'SendGrid', 'Twilio', 'AWS SES', 'Firebase'
    provider_api_endpoint TEXT,
    provider_api_key_reference VARCHAR(100), -- Secure reference to credentials
    
    -- Channel-Specific Settings
    from_address VARCHAR(255), -- For email
    from_number VARCHAR(50), -- For SMS/WhatsApp
    sender_id VARCHAR(20), -- For SMS
    
    -- Rate Limiting
    rate_limit_per_minute INTEGER,
    rate_limit_per_hour INTEGER,
    rate_limit_per_day INTEGER,
    
    -- Retry Configuration
    max_retry_attempts INTEGER DEFAULT 3,
    retry_interval_seconds INTEGER DEFAULT 60,
    
    -- Fallback
    fallback_channel_id UUID REFERENCES dynamic.channel_config(config_id),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_channel_name_type UNIQUE (tenant_id, channel_name, channel_type)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.channel_config_default PARTITION OF dynamic.channel_config DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_channel_config_tenant ON dynamic.channel_config(tenant_id);
CREATE INDEX idx_channel_config_type ON dynamic.channel_config(tenant_id, channel_type);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.channel_config IS 'Communication channel configuration - SMS, email, push providers. Tier 2 - Enterprise Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.channel_config TO finos_app;
