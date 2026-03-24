-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 24 - Simulation Testing
-- TABLE: dynamic.deployment_history
-- COMPLIANCE: ISTQB
--   - Basel
--   - SOX
--   - ITIL
-- ============================================================================


CREATE TABLE dynamic.deployment_history (

    history_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    config_id UUID NOT NULL REFERENCES dynamic.deployment_configs(config_id),
    
    -- Deployment Details
    deployment_version VARCHAR(50) NOT NULL,
    deployment_action VARCHAR(50) NOT NULL 
        CHECK (deployment_action IN ('CREATE', 'UPDATE', 'SCALE', 'FAILOVER', 'ROLLBACK', 'DELETE')),
    
    -- Changes
    changes_summary JSONB DEFAULT '{}',
    -- {resources_changed: ['cpu', 'memory'], old_values: {...}, new_values: {...}}
    
    -- Result
    status VARCHAR(20) NOT NULL 
        CHECK (status IN ('pending', 'in_progress', 'completed', 'failed', 'cancelled')),
    error_message TEXT,
    
    -- Audit
    triggered_by VARCHAR(100),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.deployment_history_default PARTITION OF dynamic.deployment_history DEFAULT;

-- Indexes
CREATE INDEX idx_deployment_history_config ON dynamic.deployment_history(tenant_id, config_id, created_at DESC);

GRANT SELECT, INSERT, UPDATE ON dynamic.deployment_history TO finos_app;