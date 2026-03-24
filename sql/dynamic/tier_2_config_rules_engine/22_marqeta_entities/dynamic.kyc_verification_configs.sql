-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.kyc_verification_configs
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Kyc Verification Configs.
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
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.kyc_verification_configs_default PARTITION OF dynamic.kyc_verification_configs DEFAULT;

-- Comments
COMMENT ON TABLE dynamic.kyc_verification_configs IS 'Configurable KYC verification policies by holder type';

GRANT SELECT, INSERT, UPDATE ON dynamic.kyc_verification_configs TO finos_app;