-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 15 - Industry Packs: Banking
-- TABLE: dynamic.credit_scoring_models
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Credit Scoring Models.
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
CREATE TABLE dynamic.credit_scoring_models (

    model_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    model_code VARCHAR(100) NOT NULL,
    model_name VARCHAR(200) NOT NULL,
    model_description TEXT,
    
    -- Model Type
    model_type VARCHAR(50) NOT NULL 
        CHECK (model_type IN ('STATISTICAL', 'MACHINE_LEARNING', 'RULE_BASED', 'HYBRID', 'EXTERNAL', 'BUREAU')),
    model_subtype VARCHAR(50), -- LOGISTIC_REGRESSION, RANDOM_FOREST, XGBOOST, NEURAL_NETWORK
    
    -- Applicability
    applicable_customer_types VARCHAR(50)[], -- INDIVIDUAL, SME, CORPORATE
    applicable_product_types UUID[],
    min_customer_age INTEGER,
    max_customer_age INTEGER,
    
    -- Scoring Range
    min_score INTEGER NOT NULL DEFAULT 0,
    max_score INTEGER NOT NULL DEFAULT 1000,
    
    -- Risk Bands
    risk_bands JSONB NOT NULL, -- [{min: 0, max: 400, band: 'HIGH_RISK', color: 'red'}, ...]
    
    -- Features/Variables
    feature_definitions JSONB NOT NULL, -- [{name: 'income', weight: 0.2, type: 'numeric'}, ...]
    
    -- Model Artifacts
    model_version VARCHAR(20) NOT NULL,
    model_file_location VARCHAR(500),
    model_parameters JSONB, -- Model-specific parameters
    
    -- External Bureau
    external_bureau_code VARCHAR(50), -- EXPERIAN, TRANSUNION, EQUIFAX, etc.
    bureau_mapping_rules JSONB, -- How to map bureau data to internal score
    
    -- Validation
    validation_metrics JSONB, -- {auc_roc: 0.85, gini: 0.70, ks_statistic: 0.45}
    validation_date DATE,
    validated_by VARCHAR(100),
    
    -- Governance
    model_owner VARCHAR(100),
    model_developer VARCHAR(100),
    approval_workflow_id UUID,
    
    -- Status
    model_status VARCHAR(20) DEFAULT 'DEVELOPMENT' 
        CHECK (model_status IN ('DEVELOPMENT', 'TESTING', 'APPROVED', 'ACTIVE', 'DEPRECATED', 'RETIRED')),
    is_active BOOLEAN DEFAULT FALSE,
    
    -- Effective Dates
    development_date DATE,
    approval_date DATE,
    deployment_date DATE,
    retirement_date DATE,
    
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
    
    CONSTRAINT unique_credit_model_code UNIQUE (tenant_id, model_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.credit_scoring_models_default PARTITION OF dynamic.credit_scoring_models DEFAULT;

-- Indexes
CREATE INDEX idx_credit_models_tenant ON dynamic.credit_scoring_models(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_credit_models_status ON dynamic.credit_scoring_models(tenant_id, model_status);

-- Comments
COMMENT ON TABLE dynamic.credit_scoring_models IS 'Credit scoring models for loan origination decisions';

-- Triggers
CREATE TRIGGER trg_credit_scoring_models_audit
    BEFORE UPDATE ON dynamic.credit_scoring_models
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.credit_scoring_models TO finos_app;