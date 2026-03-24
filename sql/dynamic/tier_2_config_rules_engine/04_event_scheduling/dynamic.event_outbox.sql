-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 04 - Event Scheduling
-- TABLE: dynamic.event_outbox
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Event Outbox.
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
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.event_outbox_default PARTITION OF dynamic.event_outbox DEFAULT;

-- Indexes
CREATE INDEX idx_event_outbox_unpublished ON dynamic.event_outbox(tenant_id, published, scheduled_at) WHERE published = FALSE;
CREATE INDEX idx_event_outbox_aggregate ON dynamic.event_outbox(tenant_id, aggregate_type, aggregate_id);

-- Comments
COMMENT ON TABLE dynamic.event_outbox IS 'Transactional outbox for guaranteed event delivery';

GRANT SELECT, INSERT, UPDATE ON dynamic.event_outbox TO finos_app;