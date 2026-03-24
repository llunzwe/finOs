-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.payments
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.payments (

    payment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    account_id UUID NOT NULL,
    account_type VARCHAR(30) NOT NULL,
    
    -- Payment Details
    payment_amount DECIMAL(28,8) NOT NULL,
    currency CHAR(3) NOT NULL,
    payment_type VARCHAR(30) NOT NULL 
        CHECK (payment_type IN ('minimum', 'full', 'partial', 'auto', 'excess')),
    
    -- Source
    funding_source_id UUID REFERENCES dynamic.funding_sources(source_id),
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending' 
        CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'reversed')),
    
    -- Allocation (how payment was applied)
    allocation_jsonb JSONB DEFAULT '{}',
    -- Example: {
    --   principal: 100.00,
    --   interest: 15.00,
    --   fees: 5.00
    -- }
    
    -- Reference
    reference_number VARCHAR(100),
    
    -- Linked Core Movement
    movement_id UUID REFERENCES core.value_movements(id),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.payments_default PARTITION OF dynamic.payments DEFAULT;

-- Indexes
CREATE INDEX idx_payments_account ON dynamic.payments(tenant_id, account_id);
CREATE INDEX idx_payments_status ON dynamic.payments(tenant_id, status) WHERE status IN ('pending', 'processing');

GRANT SELECT, INSERT, UPDATE ON dynamic.payments TO finos_app;