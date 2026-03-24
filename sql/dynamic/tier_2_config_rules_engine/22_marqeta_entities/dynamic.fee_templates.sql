-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.fee_templates
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.fee_templates (

    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    fee_code VARCHAR(50) NOT NULL,
    fee_name VARCHAR(200) NOT NULL,
    fee_description TEXT,
    
    -- Fee Type
    fee_type VARCHAR(30) NOT NULL 
        CHECK (fee_type IN ('flat', 'percentage', 'tiered', 'minimum', 'maximum', 'hybrid')),
    
    -- Fee Calculation
    fee_calculation_jsonb JSONB NOT NULL DEFAULT '{}',
    -- Example: {
    --   flat_amount: 5.00,
    --   percentage: 0.025,
    --   min_fee: 1.00,
    --   max_fee: 100.00
    -- }
    
    -- Currency
    currency CHAR(3),
    
    -- Applicability
    applies_to VARCHAR(30) NOT NULL,
    charge_trigger VARCHAR(50) NOT NULL, -- 'transaction', 'monthly', 'atm_withdrawal', etc.
    
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_fee_code_per_tenant UNIQUE (tenant_id, fee_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.fee_templates_default PARTITION OF dynamic.fee_templates DEFAULT;

-- Indexes
CREATE INDEX idx_fee_templates_tenant ON dynamic.fee_templates(tenant_id, active) WHERE active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.fee_templates IS 'Reusable fee templates with flexible calculation rules';

GRANT SELECT, INSERT, UPDATE ON dynamic.fee_templates TO finos_app;