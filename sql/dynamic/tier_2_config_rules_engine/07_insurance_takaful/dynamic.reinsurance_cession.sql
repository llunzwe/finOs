-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 07 - Insurance Takaful
-- TABLE: dynamic.reinsurance_cession
-- COMPLIANCE: IFRS 17
--   - Solvency II
--   - AAOIFI
--   - IAIS
-- ============================================================================


CREATE TABLE dynamic.reinsurance_cession (

    cession_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    treaty_id UUID NOT NULL REFERENCES dynamic.reinsurance_treaty(treaty_id),
    policy_id UUID NOT NULL REFERENCES dynamic.insurance_policy_master(policy_id),
    
    -- Ceded Amounts
    ceded_sum_assured DECIMAL(28,8) NOT NULL,
    ceded_premium DECIMAL(28,8) NOT NULL,
    
    -- Commission
    commission_on_cession DECIMAL(28,8),
    commission_percentage DECIMAL(10,6),
    
    -- Liability
    ceded_claim_reserve DECIMAL(28,8),
    ceded_claim_paid DECIMAL(28,8),
    
    -- Status
    cession_status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (cession_status IN ('ACTIVE', 'TERMINATED', 'EXPIRED')),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.reinsurance_cession_default PARTITION OF dynamic.reinsurance_cession DEFAULT;

-- Indexes
CREATE INDEX idx_cession_treaty ON dynamic.reinsurance_cession(tenant_id, treaty_id);
CREATE INDEX idx_cession_policy ON dynamic.reinsurance_cession(tenant_id, policy_id);

-- Comments
COMMENT ON TABLE dynamic.reinsurance_cession IS 'Specific risk cessions to reinsurers';

GRANT SELECT, INSERT, UPDATE ON dynamic.reinsurance_cession TO finos_app;