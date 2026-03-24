-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.fee_charges
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.fee_charges (

    charge_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    fee_template_id UUID REFERENCES dynamic.fee_templates(template_id),
    
    -- What was charged
    target_type VARCHAR(30) NOT NULL, -- 'card', 'user', 'program'
    target_id UUID NOT NULL,
    
    -- Charge Details
    charge_trigger VARCHAR(50) NOT NULL,
    charge_amount DECIMAL(28,8) NOT NULL,
    currency CHAR(3) NOT NULL,
    
    -- Basis
    basis_amount DECIMAL(28,8), -- Amount fee was calculated on
    basis_currency CHAR(3),
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending' 
        CHECK (status IN ('pending', 'charged', 'waived', 'reversed')),
    
    -- Linked Transaction
    related_transaction_id UUID,
    related_movement_id UUID REFERENCES core.value_movements(id),
    
    -- Waiver
    waived BOOLEAN DEFAULT FALSE,
    waived_by VARCHAR(100),
    waived_reason TEXT,
    waived_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    charged_at TIMESTAMPTZ

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.fee_charges_default PARTITION OF dynamic.fee_charges DEFAULT;

-- Indexes
CREATE INDEX idx_fee_charges_target ON dynamic.fee_charges(tenant_id, target_type, target_id);
CREATE INDEX idx_fee_charges_status ON dynamic.fee_charges(tenant_id, status) WHERE status = 'pending';

GRANT SELECT, INSERT, UPDATE ON dynamic.fee_charges TO finos_app;