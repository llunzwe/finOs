-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.card_products
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.card_products (

    product_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identity
    product_name VARCHAR(200) NOT NULL,
    product_code VARCHAR(100) NOT NULL,
    
    -- Card Network
    card_network VARCHAR(20) NOT NULL 
        CHECK (card_network IN ('visa', 'mastercard', 'amex', 'discover', 'rupay', 'local')),
    card_type VARCHAR(20) NOT NULL 
        CHECK (card_type IN ('debit', 'credit', 'prepaid', 'virtual')),
    
    -- Configuration
    start_date DATE,
    end_date DATE,
    
    -- Spend Controls (default for cards in this product)
    spend_limit_jsonb JSONB DEFAULT '{}',
    -- Example: {
    --   daily: {amount: 5000, currency: 'USD'},
    --   monthly: {amount: 50000, currency: 'USD'},
    --   transaction_max: {amount: 2000, currency: 'USD'}
    -- }
    
    -- Features
    features_enabled JSONB DEFAULT '{}',
    -- Example: {
    --   contactless: true,
    --   online_purchases: true,
    --   atm_withdrawals: true,
    --   international: true,
    --   pin_change: true
    -- }
    
    -- Fulfillment
    fulfillment_provider VARCHAR(100),
    shipping_method VARCHAR(50),
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_card_product_code UNIQUE (tenant_id, product_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.card_products_default PARTITION OF dynamic.card_products DEFAULT;

-- Indexes
CREATE INDEX idx_card_products_tenant ON dynamic.card_products(tenant_id, active) WHERE active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.card_products IS 'Card product definitions with default controls';

-- Triggers
CREATE TRIGGER trg_card_products_update
    BEFORE UPDATE ON dynamic.card_products
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_marqeta_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.card_products TO finos_app;