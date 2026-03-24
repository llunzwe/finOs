-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.transaction_configs
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.transaction_configs (

    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    config_name VARCHAR(200) NOT NULL,
    config_type VARCHAR(50) NOT NULL 
        CHECK (config_type IN ('authorization', 'clearing', 'refund', 'chargeback', 'transfer')),
    
    -- Matching Rules
    matching_rules_jsonb JSONB DEFAULT '{}',
    -- Example: {
    --   transaction_types: ['purchase', 'atm'],
    --   card_networks: ['visa'],
    --   mcc_ranges: ['0000-5999']
    -- }
    
    -- Processing Rules
    processing_rules_jsonb JSONB DEFAULT '{}',
    -- Example: {
    --   auto_post: true,
    --   hold_days: 3,
    --   require_3ds: false
    -- }
    
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.transaction_configs_default PARTITION OF dynamic.transaction_configs DEFAULT;

GRANT SELECT, INSERT, UPDATE ON dynamic.transaction_configs TO finos_app;