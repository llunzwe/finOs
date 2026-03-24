-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 34 - Customer Onboarding
-- TABLE: dynamic.aml_screening_config
--
-- DESCRIPTION:
--   Enterprise-grade AML screening configuration.
--   PEP, sanctions, adverse media screening rules and providers.
--
-- COMPLIANCE: FATF, FICA, OFAC, UN, EU Sanctions, POPIA
-- ============================================================================


CREATE TABLE dynamic.aml_screening_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Screening Configuration
    config_name VARCHAR(200) NOT NULL,
    config_type VARCHAR(50) NOT NULL 
        CHECK (config_type IN ('PEP', 'SANCTIONS', 'ADVERSE_MEDIA', 'CRIMINAL_RECORD', 'WATCHLIST', 'CUSTOM')),
    
    -- Provider Settings
    provider_name VARCHAR(100) NOT NULL, -- 'Dow Jones', 'Refinitiv', 'ComplyAdvantage', 'LexisNexis'
    provider_api_endpoint TEXT,
    provider_api_key_reference VARCHAR(100), -- Reference to secure vault
    
    -- Screening Rules
    screening_scope VARCHAR(50) DEFAULT 'ALL' 
        CHECK (screening_scope IN ('ALL', 'INDIVIDUALS_ONLY', 'ENTITIES_ONLY', 'HIGH_RISK_JURISDICTIONS')),
    match_threshold INTEGER DEFAULT 85, -- Minimum match score 0-100
    fuzzy_matching_enabled BOOLEAN DEFAULT TRUE,
    phonetic_matching_enabled BOOLEAN DEFAULT TRUE,
    alias_checking_enabled BOOLEAN DEFAULT TRUE,
    
    -- Lists to Screen Against
    sanctions_lists TEXT[] DEFAULT ARRAY['OFAC', 'UN', 'EU', 'HMT', 'DFAT'],
    pep_lists TEXT[] DEFAULT ARRAY['GLOBAL_PEP', 'DOMESTIC_PEP', 'INTERNATIONAL_ORGANIZATION'],
    adverse_media_categories TEXT[] DEFAULT ARRAY['FINANCIAL_CRIME', 'FRAUD', 'TERRORISM', 'CORRUPTION'],
    
    -- Automated Actions
    auto_alert_on_match BOOLEAN DEFAULT FALSE,
    auto_block_on_sanctions_match BOOLEAN DEFAULT TRUE,
    escalation_on_pep_match BOOLEAN DEFAULT TRUE,
    
    -- Refresh Configuration
    ongoing_monitoring_enabled BOOLEAN DEFAULT TRUE,
    screening_refresh_days INTEGER DEFAULT 90, -- Re-screen every 90 days
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_config_name_type UNIQUE (tenant_id, config_name, config_type)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.aml_screening_config_default PARTITION OF dynamic.aml_screening_config DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.aml_screening_config IS 'AML screening configuration - PEP, sanctions, adverse media. Tier 2 - Customer Onboarding.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.aml_screening_config TO finos_app;
