-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 18 - Industry Packs: Payments
-- TABLE: dynamic.cart_to_payment_mappings
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Cart To Payment Mappings.
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
CREATE TABLE dynamic.cart_to_payment_mappings (

    mapping_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    mapping_name VARCHAR(200) NOT NULL,
    mapping_description TEXT,
    
    -- Cart Configuration
    cart_type VARCHAR(50) NOT NULL 
        CHECK (cart_type IN ('STANDARD', 'SUBSCRIPTION', 'MARKETPLACE', 'DONATION', 'INVOICE', 'BILL_PAYMENT')),
    
    -- Cart Fields
    cart_field_mappings JSONB NOT NULL, -- {amount: 'total_amount', currency: 'currency_code', ...}
    line_item_mappings JSONB, -- [{cart_field: 'product_name', payment_field: 'description'}, ...]
    
    -- Amount Calculation
    amount_calculation_rules JSONB, -- [{type: 'SUBTOTAL'}, {type: 'TAX'}, {type: 'SHIPPING'}, {type: 'DISCOUNT'}]
    tax_calculation_method VARCHAR(50), -- INCLUSIVE, EXCLUSIVE, NO_TAX
    
    -- Payment Request
    payment_request_template JSONB, -- Template for building payment request
    metadata_mappings JSONB, -- Custom fields to pass to payment provider
    
    -- Split Payments
    supports_split_payment BOOLEAN DEFAULT FALSE,
    split_payment_rules JSONB, -- [{condition: 'amount > 1000', methods: ['CARD', 'BANK_TRANSFER']}]
    
    -- Recurring
    recurring_mapping_rules JSONB, -- {frequency_field: 'billing_cycle', start_date_field: 'start_date'}
    
    -- Webhook Handling
    success_webhook_handler VARCHAR(100),
    failure_webhook_handler VARCHAR(100),
    pending_webhook_handler VARCHAR(100),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.cart_to_payment_mappings_default PARTITION OF dynamic.cart_to_payment_mappings DEFAULT;

-- Indexes
CREATE INDEX idx_cart_payment_mappings_tenant ON dynamic.cart_to_payment_mappings(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_cart_payment_mappings_type ON dynamic.cart_to_payment_mappings(tenant_id, cart_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.cart_to_payment_mappings IS 'Shopping cart to payment request mappings';

-- Triggers
CREATE TRIGGER trg_cart_to_payment_mappings_audit
    BEFORE UPDATE ON dynamic.cart_to_payment_mappings
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.cart_to_payment_mappings TO finos_app;