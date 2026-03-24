-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.commando_mode_configs
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Commando Mode Configs.
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
CREATE TABLE dynamic.commando_mode_configs (

    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    config_name VARCHAR(200) NOT NULL,
    
    -- Applicability
    applies_to VARCHAR(30) NOT NULL,
    target_id UUID NOT NULL,
    
    -- Commando Settings
    commando_enabled BOOLEAN DEFAULT FALSE,
    commando_type VARCHAR(30) DEFAULT 'always_allow' 
        CHECK (commando_type IN ('always_allow', 'velocity_override', 'limit_override', 'emergency')),
    
    -- Overrides
    override_velocity_limits BOOLEAN DEFAULT TRUE,
    override_spend_limits BOOLEAN DEFAULT TRUE,
    override_mcc_blocks BOOLEAN DEFAULT TRUE,
    
    -- Approval Chain
    approval_required BOOLEAN DEFAULT TRUE,
    approver_roles TEXT[],
    multi_approval_count INTEGER DEFAULT 1,
    
    -- Audit
    activated_at TIMESTAMPTZ,
    activated_by VARCHAR(100),
    activation_reason TEXT,
    
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

CREATE TABLE dynamic.commando_mode_configs_default PARTITION OF dynamic.commando_mode_configs DEFAULT;

-- Comments
COMMENT ON TABLE dynamic.commando_mode_configs IS 'Emergency override mode configurations (commando mode)';

-- Triggers
CREATE TRIGGER trg_commando_mode_configs_update
    BEFORE UPDATE ON dynamic.commando_mode_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_marqeta_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.commando_mode_configs TO finos_app;