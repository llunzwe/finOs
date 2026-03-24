-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 04 - Event Scheduling
-- TABLE: dynamic_history.dead_letter_queue
-- COMPLIANCE: ISO 8601
--   - ISO 20022
--   - ISO 25010
--   - GDPR
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic_history.dead_letter_queue (

    dlq_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Original Event
    original_event_id UUID,
    original_event_type VARCHAR(100) NOT NULL,
    original_event_payload JSONB NOT NULL,
    
    -- Subscription
    subscription_id UUID REFERENCES dynamic.event_subscription(subscription_id),
    
    -- Failure Details
    failure_reason TEXT NOT NULL,
    failure_category VARCHAR(50), -- VALIDATION, TRANSPORT, TIMEOUT, etc.
    error_code VARCHAR(50),
    error_details JSONB,
    
    -- Retry Tracking
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    
    -- Timestamps
    failed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_retry_at TIMESTAMPTZ,
    next_retry_at TIMESTAMPTZ,
    
    -- Resolution
    resolution_status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (resolution_status IN ('PENDING', 'RETRYING', 'RESOLVED', 'DISCARDED', 'MANUAL_INTERVENTION')),
    resolved_at TIMESTAMPTZ,
    resolved_by VARCHAR(100),
    resolution_action VARCHAR(50), -- RETRIED, DISCARDED, MANUAL_REPLAY
    resolution_notes TEXT,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.dead_letter_queue_default PARTITION OF dynamic_history.dead_letter_queue DEFAULT;

-- Indexes
CREATE INDEX idx_dlq_tenant ON dynamic_history.dead_letter_queue(tenant_id, resolution_status) WHERE resolution_status = 'PENDING';
CREATE INDEX idx_dlq_event ON dynamic_history.dead_letter_queue(tenant_id, original_event_type);
CREATE INDEX idx_dlq_subscription ON dynamic_history.dead_letter_queue(tenant_id, subscription_id);
CREATE INDEX idx_dlq_failed_at ON dynamic_history.dead_letter_queue(failed_at DESC);

-- Comments
COMMENT ON TABLE dynamic_history.dead_letter_queue IS 'Failed event handling with retry and resolution tracking';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.dead_letter_queue TO finos_app;