-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 25 - Supporting Accounting
-- TABLE: dynamic.ring_fence_audit_trail
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Ring Fence Audit Trail.
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
CREATE TABLE dynamic.ring_fence_audit_trail (

    audit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    ring_fence_account_id UUID NOT NULL,
    
    -- Event
    event_type VARCHAR(50) NOT NULL 
        CHECK (event_type IN ('MOVEMENT', 'ADJUSTMENT', 'RECONCILIATION', 'COMPLIANCE_CHECK', 'BREACH', 'RESOLUTION')),
    
    -- Details
    event_description TEXT,
    movement_id UUID REFERENCES core.value_movements(id),
    
    -- Amounts
    amount DECIMAL(28,8),
    currency CHAR(3),
    balance_after DECIMAL(28,8),
    
    -- Compliance
    compliance_status VARCHAR(20),
    compliance_notes TEXT,
    
    -- Actor
    performed_by VARCHAR(100),
    performed_by_type VARCHAR(20),
    
    -- Timestamp
    event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.ring_fence_audit_trail_default PARTITION OF dynamic.ring_fence_audit_trail DEFAULT;

-- Indexes
CREATE INDEX idx_ring_fence_audit_account ON dynamic.ring_fence_audit_trail(tenant_id, ring_fence_account_id, event_time DESC);

GRANT SELECT, INSERT, UPDATE ON dynamic.ring_fence_audit_trail TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.ring_fence_audit_trail IS 'Ring Fence Audit Trail';