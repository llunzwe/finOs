-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.kyc_verification_configs
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.kyc_verification_configs (

    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    config_name VARCHAR(100) NOT NULL,
    holder_type VARCHAR(20) NOT NULL,
    
    -- KYC Policy (JSON Schema)
    kyc_policy_jsonb JSONB NOT NULL DEFAULT '{}',
    -- Example: {
    --   document_types: ['passport', 'driving_license'],
    --   liveness_check: true,
    --   address_verification: true,
    --   pep_screening: true,
    --   sanctions_check: true
    -- }
    
    -- Risk Tiers
    risk_based_tiers JSONB DEFAULT '{}',
    
    -- Providers
    verification_providers TEXT[],
    
    -- Rules
    auto_approve_threshold INTEGER DEFAULT 80, -- Score out of 100
    manual_review_threshold INTEGER DEFAULT 50,
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.kyc_verification_configs_default PARTITION OF dynamic.kyc_verification_configs DEFAULT;

-- Comments
COMMENT ON TABLE dynamic.kyc_verification_configs IS 'Configurable KYC verification policies by holder type';

GRANT SELECT, INSERT, UPDATE ON dynamic.kyc_verification_configs TO finos_app;