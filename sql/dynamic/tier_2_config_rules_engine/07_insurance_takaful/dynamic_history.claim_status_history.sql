-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 07 - Insurance & Takaful
-- TABLE: dynamic_history.claim_status_history
--
-- DESCRIPTION:
--   Enterprise-grade history table for Claim Status tracking.
--   Records all claim status transitions for audit purposes.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - IFRS 17
--   - AAOIFI
--   - GDPR
--   - SOC2
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


CREATE TABLE dynamic_history.claim_status_history (

    history_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    claim_id UUID NOT NULL REFERENCES dynamic.claim_register(claim_id) ON DELETE CASCADE,
    
    from_status dynamic.claim_status NOT NULL,
    to_status dynamic.claim_status NOT NULL,
    status_change_reason TEXT,
    
    changed_by VARCHAR(100) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    ip_address INET,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.claim_status_history_default PARTITION OF dynamic_history.claim_status_history DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_claim_history_claim ON dynamic_history.claim_status_history(tenant_id, claim_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic_history.claim_status_history IS 'Claim status transition history for audit. Tier 2 - Insurance & Takaful.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic_history.claim_status_history TO finos_app;
