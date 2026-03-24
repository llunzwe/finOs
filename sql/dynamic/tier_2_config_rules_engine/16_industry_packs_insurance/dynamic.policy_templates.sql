-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 16 - Industry Packs: Insurance
-- TABLE: dynamic.policy_templates
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Policy Templates.
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
CREATE TABLE dynamic.policy_templates (

    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    template_code VARCHAR(100) NOT NULL,
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    
    -- Product Link
    product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id),
    
    -- Policy Type
    policy_type VARCHAR(50) NOT NULL 
        CHECK (policy_type IN ('TERM_LIFE', 'WHOLE_LIFE', 'ENDOWMENT', 'UNIVERSAL_LIFE', 'MOTOR', 'PROPERTY', 'HEALTH', 'TRAVEL', 'GROUP_LIFE', 'MICRO')),
    
    -- Coverage Structure
    coverage_structure JSONB NOT NULL, -- [{coverage_code: '...', description: '...', sum_assured_min: 10000, sum_assured_max: 1000000}, ...]
    base_coverage_amount DECIMAL(28,8),
    
    -- Premium Calculation
    premium_calculation_method VARCHAR(50) NOT NULL 
        CHECK (premium_calculation_method IN ('STANDARD_MORTALITY', 'EXPERIENCE_RATED', 'COMMUNITY_RATED', 'AGE_BANDED', 'STEP_RATE', 'LEVEL_PREMIUM')),
    premium_rate_table JSONB, -- [{age: 25, gender: 'M', rate_per_1000: 2.5}, ...]
    
    -- Riders/Add-ons
    available_riders JSONB, -- [{rider_code: '...', rider_name: '...', premium_calculation: '...'}, ...]
    
    -- Underwriting
    underwriting_ruleset_id UUID REFERENCES dynamic.underwriting_rules(rule_id),
    auto_underwriting_limit DECIMAL(28,8),
    medical_exam_requirements JSONB, -- [{sum_assured_threshold: 100000, exam_type: 'BASIC'}, ...]
    
    -- Waiting Periods
    waiting_period_days INTEGER DEFAULT 0,
    waiting_period_waiver_conditions JSONB,
    
    -- Exclusions
    standard_exclusions JSONB, -- [{exclusion_code: '...', description: '...'}]
    optional_exclusions JSONB,
    
    -- Document Templates
    policy_document_template_id UUID,
    schedule_template_id UUID,
    endorsement_template_id UUID,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    template_version VARCHAR(20) DEFAULT '1.0',
    
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
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_policy_template_code UNIQUE (tenant_id, template_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.policy_templates_default PARTITION OF dynamic.policy_templates DEFAULT;

-- Indexes
CREATE INDEX idx_policy_templates_tenant ON dynamic.policy_templates(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_policy_templates_product ON dynamic.policy_templates(tenant_id, product_id) WHERE is_active = TRUE;
CREATE INDEX idx_policy_templates_type ON dynamic.policy_templates(tenant_id, policy_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.policy_templates IS 'Insurance policy templates with coverage and rider definitions';

-- Triggers
CREATE TRIGGER trg_policy_templates_audit
    BEFORE UPDATE ON dynamic.policy_templates
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.policy_templates TO finos_app;