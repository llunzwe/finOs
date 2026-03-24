-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 07 - Insurance Takaful
-- TABLE: dynamic.claim_reserve
-- COMPLIANCE: IFRS 17
--   - Solvency II
--   - AAOIFI
--   - IAIS
-- ============================================================================


CREATE TABLE dynamic.claim_reserve (

    reserve_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    claim_id UUID REFERENCES dynamic.claim_register(claim_id),
    
    -- Reserve Type
    reserve_type VARCHAR(50) NOT NULL 
        CHECK (reserve_type IN ('CASE_RESERVE', 'IBNR_RESERVE', 'IBNER_RESERVE', 'LAE_RESERVE')),
    
    -- Reserve Amount
    reserve_amount DECIMAL(28,8) NOT NULL,
    reserve_currency CHAR(3) NOT NULL,
    
    -- Reference
    actuary_id UUID,
    reserve_date DATE NOT NULL,
    valuation_date DATE NOT NULL,
    
    -- Details
    reserve_basis TEXT,
    adjustment_reason TEXT,
    
    -- For IBNR
    accident_period DATE,
    report_lag_months INTEGER,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.claim_reserve_default PARTITION OF dynamic.claim_reserve DEFAULT;

-- Indexes
CREATE INDEX idx_reserve_claim ON dynamic.claim_reserve(tenant_id, claim_id);
CREATE INDEX idx_reserve_type ON dynamic.claim_reserve(tenant_id, reserve_type);
CREATE INDEX idx_reserve_date ON dynamic.claim_reserve(reserve_date DESC);

-- Comments
COMMENT ON TABLE dynamic.claim_reserve IS 'Claim reserves including IBNR and case reserves';

GRANT SELECT, INSERT, UPDATE ON dynamic.claim_reserve TO finos_app;