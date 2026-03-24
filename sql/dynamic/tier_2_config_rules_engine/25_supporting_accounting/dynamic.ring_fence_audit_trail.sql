-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 25 - Supporting Accounting
-- TABLE: dynamic.ring_fence_audit_trail
-- COMPLIANCE: IFRS
--   - SOX
--   - CASS
--   - GDPR
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

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.ring_fence_audit_trail_default PARTITION OF dynamic.ring_fence_audit_trail DEFAULT;

-- Indexes
CREATE INDEX idx_ring_fence_audit_account ON dynamic.ring_fence_audit_trail(tenant_id, ring_fence_account_id, event_time DESC);

GRANT SELECT, INSERT, UPDATE ON dynamic.ring_fence_audit_trail TO finos_app;