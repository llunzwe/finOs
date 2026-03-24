-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 07 - Insurance Takaful
-- TABLE: dynamic_history.claim_status_history
-- COMPLIANCE: IFRS 17
--   - Solvency II
--   - AAOIFI
--   - IAIS
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
    
    ip_address INET

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.claim_status_history_default PARTITION OF dynamic_history.claim_status_history DEFAULT;

-- Indexes
CREATE INDEX idx_claim_history_claim ON dynamic_history.claim_status_history(tenant_id, claim_id);

-- Comments
COMMENT ON TABLE dynamic_history.claim_status_history IS 'Audit trail of claim status changes';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.claim_status_history TO finos_app;