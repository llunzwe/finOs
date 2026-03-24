-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 11 - Integration Api Management
-- TABLE: dynamic.integration_message_queue
-- COMPLIANCE: ISO 20022
--   - ISO 27001
--   - OpenAPI
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.integration_message_queue (

    message_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Routing
    queue_name VARCHAR(100) NOT NULL,
    message_type VARCHAR(100) NOT NULL,
    
    -- Content
    payload JSONB NOT NULL,
    headers JSONB,
    priority INTEGER DEFAULT 5, -- 1=Highest
    
    -- Processing
    status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'DEAD_LETTER')),
    
    -- Attempts
    attempt_count INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    last_error TEXT,
    
    -- Scheduling
    scheduled_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    
    -- Correlation
    correlation_id UUID,
    
    -- TTL
    expires_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.integration_message_queue_default PARTITION OF dynamic.integration_message_queue DEFAULT;

-- Indexes
CREATE INDEX idx_message_queue_pending ON dynamic.integration_message_queue(tenant_id, queue_name, status, priority DESC, scheduled_at) 
    WHERE status = 'PENDING';
CREATE INDEX idx_message_queue_correlation ON dynamic.integration_message_queue(tenant_id, correlation_id);

-- Comments
COMMENT ON TABLE dynamic.integration_message_queue IS 'Internal integration message queue';

GRANT SELECT, INSERT, UPDATE ON dynamic.integration_message_queue TO finos_app;