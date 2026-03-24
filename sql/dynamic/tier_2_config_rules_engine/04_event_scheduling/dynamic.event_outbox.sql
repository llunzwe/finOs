-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 04 - Event Scheduling
-- TABLE: dynamic.event_outbox
-- COMPLIANCE: ISO 8601
--   - ISO 20022
--   - ISO 25010
--   - GDPR
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic.event_outbox (

    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Event Content
    event_type VARCHAR(100) NOT NULL,
    event_version VARCHAR(20) NOT NULL DEFAULT '1.0.0',
    payload JSONB NOT NULL,
    
    -- Routing
    aggregate_type VARCHAR(50),
    aggregate_id UUID,
    
    -- Metadata
    correlation_id UUID,
    causation_id UUID,
    
    -- Publication
    published BOOLEAN DEFAULT FALSE,
    published_at TIMESTAMPTZ,
    publish_attempts INTEGER DEFAULT 0,
    last_publish_error TEXT,
    
    -- Scheduling
    scheduled_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.event_outbox_default PARTITION OF dynamic.event_outbox DEFAULT;

-- Indexes
CREATE INDEX idx_event_outbox_unpublished ON dynamic.event_outbox(tenant_id, published, scheduled_at) WHERE published = FALSE;
CREATE INDEX idx_event_outbox_aggregate ON dynamic.event_outbox(tenant_id, aggregate_type, aggregate_id);

-- Comments
COMMENT ON TABLE dynamic.event_outbox IS 'Transactional outbox for guaranteed event delivery';

GRANT SELECT, INSERT, UPDATE ON dynamic.event_outbox TO finos_app;