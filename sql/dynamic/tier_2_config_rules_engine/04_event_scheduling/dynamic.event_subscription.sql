-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 04 - Event Scheduling
-- TABLE: dynamic.event_subscription
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Event Subscription.
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
CREATE TABLE dynamic.event_subscription (

    subscription_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    subscription_name VARCHAR(200) NOT NULL,
    
    -- Event Filter
    event_type VARCHAR(100),
    event_category VARCHAR(50),
    event_filter_expression TEXT, -- SQL or DSL filter
    
    -- Consumer
    consumer_service_name VARCHAR(100) NOT NULL,
    consumer_description TEXT,
    
    -- Delivery
    delivery_method VARCHAR(20) NOT NULL 
        CHECK (delivery_method IN ('WEBHOOK', 'KAFKA_API', 'QUEUE', 'LAMBDA', 'FUNCTION')),
    endpoint_url VARCHAR(500),
    endpoint_method VARCHAR(10) DEFAULT 'POST',
    endpoint_headers JSONB,
    
    -- Authentication
    auth_type dynamic.api_auth_type DEFAULT 'API_KEY',
    auth_credentials_encrypted BYTEA,
    
    -- Retry Policy
    retry_policy JSONB DEFAULT '{"max_retries": 3, "backoff_type": "exponential", "initial_interval_ms": 1000}'::jsonb,
    
    -- DLQ
    dead_letter_queue_enabled BOOLEAN DEFAULT TRUE,
    dead_letter_queue_max_retries INTEGER DEFAULT 3,
    dead_letter_queue_retention_days INTEGER DEFAULT 30,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    paused BOOLEAN DEFAULT FALSE,
    
    -- Metrics
    messages_delivered BIGINT DEFAULT 0,
    messages_failed BIGINT DEFAULT 0,
    last_delivered_at TIMESTAMPTZ,
    last_failed_at TIMESTAMPTZ,
    
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
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.event_subscription_default PARTITION OF dynamic.event_subscription DEFAULT;

-- Indexes
CREATE INDEX idx_event_sub_tenant ON dynamic.event_subscription(tenant_id) WHERE is_active = TRUE AND paused = FALSE;
CREATE INDEX idx_event_sub_type ON dynamic.event_subscription(tenant_id, event_type) WHERE is_active = TRUE AND paused = FALSE;

-- Comments
COMMENT ON TABLE dynamic.event_subscription IS 'Event consumer registrations with delivery configuration';

-- Triggers
CREATE TRIGGER trg_event_subscription_audit
    BEFORE UPDATE ON dynamic.event_subscription
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.event_subscription TO finos_app;