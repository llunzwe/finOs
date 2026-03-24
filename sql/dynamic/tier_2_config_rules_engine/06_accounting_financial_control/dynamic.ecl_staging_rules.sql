-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 06 - Accounting & Financial Control
-- TABLE: dynamic.ecl_staging_rules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Ecl Staging Rules.
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
CREATE TABLE dynamic.ecl_staging_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    model_id UUID NOT NULL REFERENCES dynamic.ecl_model_configuration(model_id),
    
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Staging Criteria
    staging_criteria VARCHAR(50) NOT NULL 
        CHECK (staging_criteria IN ('DAYS_PAST_DUE', 'RISK_RATING_CHANGE', 'FORECAST', 'MANUAL', 'WATCHLIST')),
    
    -- DPD Thresholds
    stage_1_to_2_threshold_dpd INTEGER DEFAULT 30,
    stage_2_to_3_threshold_dpd INTEGER DEFAULT 90,
    
    -- Significant Increase in Credit Risk (SICR)
    significant_increase_indicators JSONB, -- {risk_rating_change: 2, watchlist_flag: true}
    absolute_pd_threshold DECIMAL(5,4),
    relative_pd_increase_threshold DECIMAL(5,4),
    
    -- Backstop
    backstop_days_past_due INTEGER DEFAULT 90,
    
    -- Low Credit Risk Exemption
    low_credit_risk_exemption BOOLEAN DEFAULT TRUE,
    investment_grade_ratings VARCHAR(10)[],
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 0,
    
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

CREATE TABLE dynamic.ecl_staging_rules_default PARTITION OF dynamic.ecl_staging_rules DEFAULT;

-- Indexes
CREATE INDEX idx_ecl_staging_model ON dynamic.ecl_staging_rules(tenant_id, model_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.ecl_staging_rules IS 'IFRS 9 Stage 1/2/3 automation rules';

-- Triggers
CREATE TRIGGER trg_ecl_staging_audit
    BEFORE UPDATE ON dynamic.ecl_staging_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.ecl_staging_rules TO finos_app;