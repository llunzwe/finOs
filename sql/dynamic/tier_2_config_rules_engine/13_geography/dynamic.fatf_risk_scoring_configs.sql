-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 13 - Geography & Jurisdiction
-- TABLE: dynamic.fatf_risk_scoring_configs
--
-- DESCRIPTION:
--   FATF country risk scoring configuration.
--   Configures AML risk ratings per FATF guidelines.
--
-- CORE DEPENDENCY: 013_geography_and_jurisdiction.sql
--
-- COMPLIANCE:
--   - FATF Recommendations
--   - AML/CFT regulations
--
-- ============================================================================

CREATE TABLE dynamic.fatf_risk_scoring_configs (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Jurisdiction
    jurisdiction_code CHAR(2) NOT NULL REFERENCES core.jurisdictions(iso_code),
    jurisdiction_name VARCHAR(200) NOT NULL,
    
    -- FATF Status
    fatf_list_status VARCHAR(50) NOT NULL, -- 'GREY_LIST', 'BLACK_LIST', 'WHITE_LIST'
    fatf_call_for_action BOOLEAN DEFAULT FALSE,
    fatf_monitoring_dates JSONB, -- {"added": "2023-01-01", "removed": null}
    
    -- Risk Scoring
    base_risk_score INTEGER NOT NULL CHECK (base_risk_score BETWEEN 1 AND 100),
    risk_category VARCHAR(20) GENERATED ALWAYS AS (
        CASE 
            WHEN base_risk_score >= 80 THEN 'HIGH'
            WHEN base_risk_score >= 50 THEN 'MEDIUM'
            ELSE 'LOW'
        END
    ) STORED,
    
    -- Risk Factors
    corruption_perception_index INTEGER, -- 0-100 (Transparency International)
    rule_of_law_score DECIMAL(5,2), -- World Bank indicator
    regulatory_quality_score DECIMAL(5,2),
    
    -- Enhanced Due Diligence Triggers
    requires_enhanced_due_diligence BOOLEAN DEFAULT FALSE,
    edd_threshold_amount DECIMAL(28,8),
    edd_required_for_all_transactions BOOLEAN DEFAULT FALSE,
    
    -- Sanctions
    sanctions_applicable BOOLEAN DEFAULT FALSE,
    sanction_types VARCHAR(50)[], -- 'UN', 'EU', 'US', 'UK'
    
    -- Last Review
    last_review_date DATE DEFAULT CURRENT_DATE,
    next_review_date DATE DEFAULT (CURRENT_DATE + INTERVAL '1 year'),
    reviewed_by VARCHAR(100),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_jurisdiction_risk_config UNIQUE (tenant_id, jurisdiction_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.fatf_risk_scoring_configs_default PARTITION OF dynamic.fatf_risk_scoring_configs DEFAULT;

CREATE INDEX idx_fatf_risk_status ON dynamic.fatf_risk_scoring_configs(tenant_id, fatf_list_status) WHERE is_active = TRUE AND is_current = TRUE;
CREATE INDEX idx_fatf_risk_score ON dynamic.fatf_risk_scoring_configs(tenant_id, base_risk_score) WHERE is_active = TRUE;

COMMENT ON TABLE dynamic.fatf_risk_scoring_configs IS 'FATF country risk scoring configuration for AML compliance. Tier 2 Low-Code';

CREATE TRIGGER trg_fatf_risk_scoring_configs_audit
    BEFORE UPDATE ON dynamic.fatf_risk_scoring_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.fatf_risk_scoring_configs TO finos_app;
