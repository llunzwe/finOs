-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 06 - Immutable Events
-- TABLE: dynamic.event_replay_policies
--
-- DESCRIPTION:
--   Event replay policy configuration for immutable event store.
--   Configures replay strategies, filtering, and recovery procedures.
--
-- CORE DEPENDENCY: 006_immutable_event_store.sql
--
-- ============================================================================

CREATE TABLE dynamic.event_replay_policies (
    policy_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Policy Identification
    policy_code VARCHAR(100) NOT NULL,
    policy_name VARCHAR(200) NOT NULL,
    policy_description TEXT,
    
    -- Replay Scope
    replay_scope VARCHAR(50) NOT NULL DEFAULT 'SELECTIVE', -- FULL, SELECTIVE, RECOVERY
    applicable_event_types VARCHAR(100)[],
    applicable_event_categories VARCHAR(50)[],
    applicable_datom_attributes VARCHAR(200)[],
    
    -- Time Range
    default_lookback_days INTEGER DEFAULT 30,
    max_lookback_days INTEGER DEFAULT 2555, -- ~7 years
    allow_future_replay BOOLEAN DEFAULT FALSE, -- Replay events with future valid_time
    
    -- Filtering
    include_retractions BOOLEAN DEFAULT TRUE, -- Include '-' operations
    filter_by_entity_types VARCHAR(100)[], -- Only replay events for these entity types
    exclude_event_ids UUID[], -- Specific events to exclude
    
    -- Replay Behavior
    replay_mode VARCHAR(50) DEFAULT 'RECONSTRUCT', -- RECONSTRUCT, PROJECT, VERIFY
    target_projection VARCHAR(200), -- Target view/materialized view to rebuild
    verify_consistency BOOLEAN DEFAULT TRUE,
    
    -- Performance
    batch_size INTEGER DEFAULT 1000,
    parallel_workers INTEGER DEFAULT 4,
    throttle_ms INTEGER DEFAULT 0, -- Throttle between batches
    
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
    
    CONSTRAINT unique_event_replay_policy_code UNIQUE (tenant_id, policy_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.event_replay_policies_default PARTITION OF dynamic.event_replay_policies DEFAULT;

CREATE INDEX idx_event_replay_scope ON dynamic.event_replay_policies(tenant_id, replay_scope) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.event_replay_policies IS 'Event replay policy configuration for immutable event store recovery. Tier 2 Low-Code';

CREATE TRIGGER trg_event_replay_policies_audit
    BEFORE UPDATE ON dynamic.event_replay_policies
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.event_replay_policies TO finos_app;
