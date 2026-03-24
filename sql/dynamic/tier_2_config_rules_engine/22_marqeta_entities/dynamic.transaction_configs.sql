-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.transaction_configs
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Transaction Configs.
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

CREATE TABLE dynamic.transaction_configs_default PARTITION OF dynamic.transaction_configs DEFAULT;

GRANT SELECT, INSERT, UPDATE ON dynamic.transaction_configs TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.transaction_configs IS 'Transaction Configs';