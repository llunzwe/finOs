-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 07 - Insurance Takaful
-- TABLE: dynamic.commission_earned
-- COMPLIANCE: IFRS 17
--   - Solvency II
--   - AAOIFI
--   - IAIS
-- ============================================================================


CREATE TABLE dynamic.commission_earned (

    commission_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- References
    agent_id UUID NOT NULL,
    policy_id UUID NOT NULL REFERENCES dynamic.insurance_policy_master(policy_id),
    structure_id UUID REFERENCES dynamic.commission_structure(structure_id),
    
    -- Commission Details
    commission_type VARCHAR(20) NOT NULL,
    commission_basis DECIMAL(28,8), -- Premium amount commission is based on
    commission_amount DECIMAL(28,8) NOT NULL,
    commission_rate DECIMAL(10,6),
    
    -- Installment Reference
    installment_number INTEGER,
    
    -- Recognition
    recognition_date DATE NOT NULL,
    recognition_status VARCHAR(20) DEFAULT 'ACCRUED' 
        CHECK (recognition_status IN ('ACCRUED', 'PAID', 'CLAWED_BACK', 'FORFEITED')),
    
    -- Payment
    paid_at TIMESTAMPTZ,
    payment_reference VARCHAR(100),
    
    -- Clawback
    clawed_back_amount DECIMAL(28,8) DEFAULT 0,
    clawed_back_at TIMESTAMPTZ,
    clawback_reason VARCHAR(100),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.commission_earned_default PARTITION OF dynamic.commission_earned DEFAULT;

-- Indexes
CREATE INDEX idx_commission_agent ON dynamic.commission_earned(tenant_id, agent_id);
CREATE INDEX idx_commission_policy ON dynamic.commission_earned(tenant_id, policy_id);
CREATE INDEX idx_commission_status ON dynamic.commission_earned(tenant_id, recognition_status);

-- Comments
COMMENT ON TABLE dynamic.commission_earned IS 'Accrued and paid commissions with clawback tracking';

GRANT SELECT, INSERT, UPDATE ON dynamic.commission_earned TO finos_app;