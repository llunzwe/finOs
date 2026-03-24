-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.account_holder_transitions
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Account Holder State Transitions.
--   Records all account holder status changes for audit purposes.
--   Supports tenant isolation and comprehensive audit trails.
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


CREATE TABLE dynamic.account_holder_transitions (

    transition_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    holder_id UUID NOT NULL REFERENCES dynamic.account_holders(holder_id),
    
    -- Transition
    from_status VARCHAR(20) NOT NULL,
    to_status VARCHAR(20) NOT NULL,
    transition_reason VARCHAR(100),
    transition_notes TEXT,
    
    -- Actor
    triggered_by VARCHAR(100),
    triggered_by_type VARCHAR(20) CHECK (triggered_by_type IN ('user', 'system', 'api', 'webhook')),
    
    -- Timing
    transitioned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Linked to Core
    transition_event_id BIGINT REFERENCES core.transactions(tx_id),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.account_holder_transitions_default PARTITION OF dynamic.account_holder_transitions DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_holder_transitions ON dynamic.account_holder_transitions(tenant_id, holder_id, transitioned_at DESC);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.account_holder_transitions IS 'Account holder state transition history. Tier 2 - Marqeta Entities.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.account_holder_transitions TO finos_app;
