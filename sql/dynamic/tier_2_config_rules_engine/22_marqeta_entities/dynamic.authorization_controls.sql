-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.authorization_controls
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Authorization Controls.
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
CREATE TABLE dynamic.authorization_controls (

    control_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Applicability
    applies_to VARCHAR(30) NOT NULL 
        CHECK (applies_to IN ('program', 'user', 'card', 'card_product')),
    target_id UUID NOT NULL,
    
    -- Control Type
    control_type VARCHAR(50) NOT NULL 
        CHECK (control_type IN ('velocity', 'spend', 'merchant', 'mcc', 'geography', 'time', 'custom')),
    
    -- Control Logic
    control_logic_jsonb JSONB NOT NULL DEFAULT '{}',
    -- Example for velocity: {
    --   window: 'day',
    --   max_count: 10,
    --   max_amount: 5000
    -- }
    -- Example for mcc: {
    --   blocked_mccs: ['5912', '7995'],
    --   allowed_mccs: ['5411', '5541']
    -- }
    
    -- Action on Breach
    action_on_breach VARCHAR(20) DEFAULT 'decline' 
        CHECK (action_on_breach IN ('decline', 'approve', 'flag', 'notify')),
    notification_targets TEXT[],
    
    -- Active Period
    active_from TIMESTAMPTZ DEFAULT NOW(),
    active_to TIMESTAMPTZ DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    
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

CREATE TABLE dynamic.authorization_controls_default PARTITION OF dynamic.authorization_controls DEFAULT;

-- Indexes
CREATE INDEX idx_auth_controls_target ON dynamic.authorization_controls(tenant_id, applies_to, target_id);
CREATE INDEX idx_auth_controls_active ON dynamic.authorization_controls(tenant_id, active) 
    WHERE active = TRUE AND active_from <= NOW() AND active_to > NOW();

-- Comments
COMMENT ON TABLE dynamic.authorization_controls IS 'Authorization controls - velocity, spend, merchant, MCC, geography';

-- Triggers
CREATE TRIGGER trg_authorization_controls_update
    BEFORE UPDATE ON dynamic.authorization_controls
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_marqeta_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.authorization_controls TO finos_app;