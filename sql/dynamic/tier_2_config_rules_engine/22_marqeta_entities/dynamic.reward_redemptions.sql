-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.reward_redemptions
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.reward_redemptions (

    redemption_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    holder_id UUID NOT NULL REFERENCES dynamic.account_holders(holder_id),
    
    -- Redemption Details
    redemption_type VARCHAR(30) NOT NULL 
        CHECK (redemption_type IN ('cashback', 'voucher', 'transfer', 'merchandise', 'donation')),
    
    -- Amount
    points_redeemed INTEGER NOT NULL,
    cash_value DECIMAL(28,8),
    currency CHAR(3),
    
    -- Destination
    destination_account_id UUID,
    destination_description TEXT,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending' 
        CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    
    -- Reference
    reference_number VARCHAR(100),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.reward_redemptions_default PARTITION OF dynamic.reward_redemptions DEFAULT;

GRANT SELECT, INSERT, UPDATE ON dynamic.reward_redemptions TO finos_app;