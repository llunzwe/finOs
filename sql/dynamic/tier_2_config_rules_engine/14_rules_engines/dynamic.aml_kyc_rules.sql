-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 14 - Rules Engines
-- TABLE: dynamic.aml_kyc_rules
-- COMPLIANCE: Basel
--   - IFRS
--   - GDPR
--   - SOX
-- ============================================================================


CREATE TABLE dynamic.aml_kyc_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Rule Type
    screening_type VARCHAR(50) NOT NULL 
        CHECK (screening_type IN ('SANCTIONS', 'PEP', 'ADVERSE_MEDIA', 'WATCHLIST', 'COUNTRY_RISK', 'TRANSACTION_MONITORING')),
    
    -- List Sources
    list_sources JSONB NOT NULL, -- [{source: 'OFAC', url: '...', refresh_frequency: 'DAILY'}, ...]
    
    -- Screening Configuration
    screening_scope JSONB, -- {customer_types: ['INDIVIDUAL', 'CORPORATE'], include_beneficial_owners: true}
    
    -- Matching Logic
    match_algorithm VARCHAR(50) DEFAULT 'FUZZY',
    match_threshold DECIMAL(5,4) DEFAULT 0.85,
    name_variations_check BOOLEAN DEFAULT TRUE,
    phonetic_matching BOOLEAN DEFAULT TRUE,
    
    -- Trigger Events
    trigger_events VARCHAR(50)[] DEFAULT ARRAY['ONBOARDING', 'TRANSACTION'], -- ONBOARDING, TRANSACTION, PERIODIC, CHANGE
    
    -- Frequency
    screening_frequency VARCHAR(20) DEFAULT 'REALTIME', -- REALTIME, DAILY, WEEKLY, MONTHLY
    
    -- Actions
    true_match_action VARCHAR(50) DEFAULT 'BLOCK',
    potential_match_action VARCHAR(50) DEFAULT 'REVIEW',
    
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
    
    CONSTRAINT unique_aml_kyc_rule_code UNIQUE (tenant_id, rule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.aml_kyc_rules_default PARTITION OF dynamic.aml_kyc_rules DEFAULT;

-- Indexes
CREATE INDEX idx_aml_kyc_rules_tenant ON dynamic.aml_kyc_rules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_aml_kyc_rules_type ON dynamic.aml_kyc_rules(tenant_id, screening_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.aml_kyc_rules IS 'AML/KYC screening configuration for sanctions and PEP checks';

-- Triggers
CREATE TRIGGER trg_aml_kyc_rules_audit
    BEFORE UPDATE ON dynamic.aml_kyc_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.aml_kyc_rules TO finos_app;