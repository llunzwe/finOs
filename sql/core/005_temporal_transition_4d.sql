-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 5: TEMPORAL TRANSITION (4D TIME)
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: Bitemporal Support, 4D Time Tracking, Audit Trail
-- Standards: ISO 8601, SQL:2011 Temporal, TSQL2
-- =============================================================================

-- =============================================================================
-- TEMPORAL TRANSITIONS (4D Time Tracking)
-- =============================================================================
CREATE TABLE core.temporal_transitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Entity Reference (Polymorphic)
    entity_type VARCHAR(50) NOT NULL 
        CHECK (entity_type IN ('value_container', 'value_movement', 'economic_agent', 
                               'agreement', 'obligation', 'entitlement', 'settlement')),
    entity_id UUID NOT NULL,
    
    -- State Change
    from_state VARCHAR(50) NOT NULL,
    to_state VARCHAR(50) NOT NULL,
    transition_event VARCHAR(100) NOT NULL,
    transition_category VARCHAR(50) CHECK (transition_category IN ('manual', 'scheduled', 'system', 'workflow', 'api')),
    
    -- Four Time Dimensions (Axiom II)
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_time_start TIMESTAMPTZ NOT NULL,
    valid_time_end TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    decision_time TIMESTAMPTZ,
    
    -- Actor
    triggered_by UUID,
    trigger_source VARCHAR(50) CHECK (trigger_source IN ('manual', 'scheduled', 'system', 'api', 'webhook')),
    
    -- Context
    reason_code VARCHAR(50),
    reason_category VARCHAR(50),
    justification TEXT,
    context JSONB DEFAULT '{}',
    
    -- Compliance (4-Eyes Principle)
    requires_approval BOOLEAN NOT NULL DEFAULT FALSE,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    approval_evidence JSONB DEFAULT '{}',
    digital_signature BYTEA,
    
    -- Financial Impact
    associated_movement_id UUID,
    financial_impact_amount DECIMAL(28,8),
    financial_impact_currency CHAR(3),
    
    -- System
    processed BOOLEAN NOT NULL DEFAULT FALSE,
    processed_at TIMESTAMPTZ,
    
    -- Soft Delete
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    -- Event Tracking
    correlation_id UUID,
    causation_id UUID,
    idempotency_key VARCHAR(100),
    
    -- Constraints
    CONSTRAINT chk_valid_time_order CHECK (valid_time_start < valid_time_end),
    CONSTRAINT chk_decision_before_system CHECK (decision_time IS NULL OR decision_time <= system_time),
    CONSTRAINT chk_approval_required CHECK (
        (requires_approval = FALSE) OR 
        (requires_approval = TRUE AND approved_by IS NOT NULL)
    )
) PARTITION BY RANGE (system_time);

-- Create monthly partitions for temporal transitions
CREATE TABLE core.temporal_transitions_default PARTITION OF core.temporal_transitions
    DEFAULT;

-- Critical indexes (-3.2)
CREATE INDEX idx_transitions_entity ON core.temporal_transitions(entity_type, entity_id, valid_time_start DESC);
CREATE INDEX idx_transitions_system_time ON core.temporal_transitions(system_time DESC);
CREATE INDEX idx_transitions_bitemporal ON core.temporal_transitions(valid_time_start, valid_time_end, system_time);
CREATE INDEX idx_transitions_approval ON core.temporal_transitions(requires_approval, approved_by) 
    WHERE requires_approval = TRUE AND approved_by IS NULL;
CREATE INDEX idx_transitions_movement ON core.temporal_transitions(associated_movement_id) WHERE associated_movement_id IS NOT NULL;
CREATE INDEX idx_transitions_tenant ON core.temporal_transitions(tenant_id, system_time DESC);
CREATE INDEX idx_transitions_correlation ON core.temporal_transitions(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_transitions_idempotency ON core.temporal_transitions(tenant_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX idx_transitions_composite ON core.temporal_transitions(tenant_id, entity_type, valid_time_start) 
    WHERE processed = TRUE;

COMMENT ON TABLE core.temporal_transitions IS '4D time tracking: system_time (when recorded), valid_time (when effective), decision_time (when decided)';

-- =============================================================================
-- TEMPORAL PERIODS VIEW (Convenience)
-- =============================================================================
CREATE OR REPLACE VIEW core.temporal_periods AS
SELECT 
    id,
    tenant_id,
    entity_type,
    entity_id,
    from_state,
    to_state,
    system_time,
    valid_time_start,
    valid_time_end,
    tstzrange(valid_time_start, valid_time_end, '[)') AS valid_period,
    tstzrange(system_time, COALESCE(LEAD(system_time) OVER (PARTITION BY entity_type, entity_id ORDER BY system_time), 'infinity'::timestamptz), '[)') AS system_period
FROM core.temporal_transitions
WHERE processed = TRUE;

COMMENT ON VIEW core.temporal_periods IS 'Convenience view exposing valid_period and system_period as range types';

-- =============================================================================
-- AS-OF QUERY FUNCTIONS
-- =============================================================================

-- Function: Get state as of a specific valid time
CREATE OR REPLACE FUNCTION core.get_state_as_of_valid_time(
    p_entity_type VARCHAR,
    p_entity_id UUID,
    p_as_of_time TIMESTAMPTZ
) RETURNS TABLE (
    state VARCHAR(50),
    valid_from TIMESTAMPTZ,
    valid_to TIMESTAMPTZ,
    transition_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tt.to_state,
        tt.valid_time_start,
        tt.valid_time_end,
        tt.id
    FROM core.temporal_transitions tt
    WHERE tt.entity_type = p_entity_type
      AND tt.entity_id = p_entity_id
      AND tt.valid_time_start <= p_as_of_time
      AND tt.valid_time_end > p_as_of_time
      AND tt.processed = TRUE
    ORDER BY tt.system_time DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.get_state_as_of_valid_time IS 'Retrieves the effective state at a given valid time';

-- Function: Get state as of a specific system time (time travel)
CREATE OR REPLACE FUNCTION core.get_state_as_of_system_time(
    p_entity_type VARCHAR,
    p_entity_id UUID,
    p_system_time TIMESTAMPTZ
) RETURNS TABLE (
    state VARCHAR(50),
    system_time TIMESTAMPTZ,
    valid_from TIMESTAMPTZ,
    valid_to TIMESTAMPTZ,
    transition_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tt.to_state,
        tt.system_time,
        tt.valid_time_start,
        tt.valid_time_end,
        tt.id
    FROM core.temporal_transitions tt
    WHERE tt.entity_type = p_entity_type
      AND tt.entity_id = p_entity_id
      AND tt.system_time <= p_system_time
      AND tt.processed = TRUE
    ORDER BY tt.system_time DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.get_state_as_of_system_time IS 'Retrieves the state as known at a specific system time (audit trail)';

-- Function: Full bitemporal query
CREATE OR REPLACE FUNCTION core.get_state_bitemporal(
    p_entity_type VARCHAR,
    p_entity_id UUID,
    p_valid_time TIMESTAMPTZ,
    p_system_time TIMESTAMPTZ
) RETURNS TABLE (
    state VARCHAR(50),
    transition_record core.temporal_transitions
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tt.to_state,
        tt
    FROM core.temporal_transitions tt
    WHERE tt.entity_type = p_entity_type
      AND tt.entity_id = p_entity_id
      AND tt.valid_time_start <= p_valid_time
      AND tt.valid_time_end > p_valid_time
      AND tt.system_time <= p_system_time
      AND (tt.processed = TRUE OR tt.system_time <= p_system_time)
    ORDER BY tt.system_time DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.get_state_bitemporal IS 'Full bitemporal query at specific valid and system times';

-- =============================================================================
-- TEMPORAL CONSISTENCY TRIGGERS
-- =============================================================================

-- Trigger to close previous valid period
CREATE OR REPLACE FUNCTION core.close_previous_valid_period()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE core.temporal_transitions
    SET valid_time_end = NEW.valid_time_start,
        processed = TRUE,
        processed_at = NOW()
    WHERE entity_type = NEW.entity_type
      AND entity_id = NEW.entity_id
      AND valid_time_end = '9999-12-31 23:59:59+00'::timestamptz
      AND id != NEW.id
      AND processed = FALSE;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_close_valid_period
    AFTER INSERT ON core.temporal_transitions
    FOR EACH ROW EXECUTE FUNCTION core.close_previous_valid_period();

-- =============================================================================
-- TEMPORAL HISTORY (TimescaleDB Hypertable)
-- =============================================================================
CREATE TABLE core_history.temporal_snapshots (
    time TIMESTAMPTZ NOT NULL,
    tenant_id UUID NOT NULL,
    
    snapshot_type VARCHAR(50) NOT NULL,
    entity_count INTEGER,
    transition_count INTEGER,
    
    snapshot_data JSONB,
    merkle_root VARCHAR(64),
    
    PRIMARY KEY (time, tenant_id)
);

SELECT create_hypertable('core_history.temporal_snapshots', 'time', 
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists => TRUE);

CREATE INDEX idx_temporal_snapshots_type ON core_history.temporal_snapshots(snapshot_type, time DESC);

-- =============================================================================
-- TEMPORAL METRICS VIEW
-- =============================================================================
CREATE OR REPLACE VIEW core.temporal_metrics AS
SELECT 
    tenant_id,
    DATE_TRUNC('day', system_time) AS day,
    entity_type,
    COUNT(*) AS transition_count,
    COUNT(DISTINCT entity_id) AS entities_changed,
    SUM(CASE WHEN requires_approval THEN 1 ELSE 0 END) AS approved_transitions,
    AVG(EXTRACT(EPOCH FROM (processed_at - created_at))) AS avg_processing_seconds
FROM core.temporal_transitions
WHERE system_time > NOW() - INTERVAL '30 days'
GROUP BY tenant_id, DATE_TRUNC('day', system_time), entity_type;

COMMENT ON VIEW core.temporal_metrics IS 'Daily metrics on temporal transitions';

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT ON core.temporal_transitions TO finos_app;
GRANT SELECT ON core.temporal_periods TO finos_app;
GRANT SELECT ON core.temporal_metrics TO finos_app;
GRANT SELECT, INSERT ON core_history.temporal_snapshots TO finos_app;
GRANT EXECUTE ON FUNCTION core.get_state_as_of_valid_time TO finos_app;
GRANT EXECUTE ON FUNCTION core.get_state_as_of_system_time TO finos_app;
GRANT EXECUTE ON FUNCTION core.get_state_bitemporal TO finos_app;
