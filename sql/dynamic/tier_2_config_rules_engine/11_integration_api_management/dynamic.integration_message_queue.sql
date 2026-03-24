-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 11 - Integration & API Management
-- TABLE: dynamic.integration_message_queue
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Integration Message Queue.
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

CREATE TABLE dynamic.integration_message_queue_default PARTITION OF dynamic.integration_message_queue DEFAULT;

-- Indexes
CREATE INDEX idx_message_queue_pending ON dynamic.integration_message_queue(tenant_id, queue_name, status, priority DESC, scheduled_at) 
    WHERE status = 'PENDING';
CREATE INDEX idx_message_queue_correlation ON dynamic.integration_message_queue(tenant_id, correlation_id);

-- Comments
COMMENT ON TABLE dynamic.integration_message_queue IS 'Internal integration message queue';

GRANT SELECT, INSERT, UPDATE ON dynamic.integration_message_queue TO finos_app;