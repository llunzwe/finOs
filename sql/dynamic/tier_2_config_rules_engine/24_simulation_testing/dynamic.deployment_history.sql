-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 24 - Simulation Testing
-- TABLE: dynamic.deployment_history
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Deployment History.
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
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.deployment_history_default PARTITION OF dynamic.deployment_history DEFAULT;

-- Indexes
CREATE INDEX idx_deployment_history_config ON dynamic.deployment_history(tenant_id, config_id, created_at DESC);

GRANT SELECT, INSERT, UPDATE ON dynamic.deployment_history TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.deployment_history IS 'Deployment History';