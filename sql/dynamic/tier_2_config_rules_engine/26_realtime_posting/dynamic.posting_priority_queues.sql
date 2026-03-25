-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Real-Time Posting
-- TABLE: dynamic.posting_priority_queues
--
-- DESCRIPTION:
--   Posting priority queue configuration.
--   Configures queue prioritization for real-time ledger posting.
--
-- CORE DEPENDENCY: 026_real_time_posting.sql
--
-- ============================================================================

CREATE TABLE dynamic.posting_priority_queues (
    queue_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Queue Identification
    queue_code VARCHAR(100) NOT NULL,
    queue_name VARCHAR(200) NOT NULL,
    queue_description TEXT,
    
    -- Priority Configuration
    priority_level INTEGER NOT NULL CHECK (priority_level BETWEEN 1 AND 10), -- 1 = highest
    priority_name VARCHAR(50), -- 'CRITICAL', 'HIGH', 'NORMAL', 'LOW', 'BULK'
    
    -- Applicability
    applicable_movement_types VARCHAR(50)[], -- Which movements use this queue
    applicable_amount_threshold_min DECIMAL(28,8),
    applicable_amount_threshold_max DECIMAL(28,8),
    applicable_entity_types VARCHAR(50)[],
    
    -- Queue Behavior
    max_queue_depth INTEGER DEFAULT 10000,
    max_processing_time_ms INTEGER DEFAULT 1000,
    preempt_lower_priorities BOOLEAN DEFAULT FALSE,
    
    -- Resource Allocation
    dedicated_workers INTEGER DEFAULT 2,
    max_parallel_processing INTEGER DEFAULT 10,
    cpu_priority VARCHAR(20) DEFAULT 'NORMAL', -- LOW, NORMAL, HIGH, REALTIME
    
    -- SLA
    target_processing_time_ms INTEGER DEFAULT 500,
    sla_violation_action VARCHAR(50) DEFAULT 'ALERT', -- ALERT, ESCALATE, REJECT
    
    -- Backpressure
    enable_backpressure BOOLEAN DEFAULT TRUE,
    backpressure_threshold INTEGER DEFAULT 8000, -- Queue depth to trigger backpressure
    backpressure_action VARCHAR(50) DEFAULT 'THROTTLE', -- THROTTLE, REJECT, SCALE_UP
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_posting_queue_code UNIQUE (tenant_id, queue_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.posting_priority_queues_default PARTITION OF dynamic.posting_priority_queues DEFAULT;

CREATE INDEX idx_posting_queue_priority ON dynamic.posting_priority_queues(tenant_id, priority_level) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.posting_priority_queues IS 'Posting priority queue configuration for real-time ledger posting prioritization. Tier 2 Low-Code';

CREATE TRIGGER trg_posting_priority_queues_audit
    BEFORE UPDATE ON dynamic.posting_priority_queues
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.posting_priority_queues TO finos_app;
