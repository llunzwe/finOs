-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 16 - Industry Packs Insurance
-- TABLE: dynamic.risk_assessment_models
-- COMPLIANCE: IFRS 17
--   - Solvency II
--   - IAIS
--   - POPIA
-- ============================================================================


CREATE TABLE dynamic.risk_assessment_models (

    model_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    model_code VARCHAR(100) NOT NULL,
    model_name VARCHAR(200) NOT NULL,
    model_description TEXT,
    
    -- Model Type
    assessment_type VARCHAR(50) NOT NULL 
        CHECK (assessment_type IN ('MORTALITY', 'MORBIDITY', 'LAPSE', 'EXPENSE', 'INVESTMENT', 'CATASTROPHE', 'OPERATIONAL')),
    
    -- Applicability
    applicable_lines_of_business VARCHAR(50)[], -- LIFE, HEALTH, P&C, etc.
    applicable_geographies VARCHAR(10)[], -- Country codes
    
    -- Model Methodology
    methodology VARCHAR(50) NOT NULL 
        CHECK (methodology IN ('TABLE_BASED', 'STOCHASTIC', 'DETERMINISTIC', 'MACHINE_LEARNING', 'GLM', 'PROPORTIONAL_HAZARDS')),
    
    -- Model Components
    risk_factors JSONB NOT NULL, -- [{factor: 'age', type: 'demographic', weight: 0.3}, ...]
    model_parameters JSONB, -- Calibration parameters
    
    -- Data Sources
    experience_data_period_start DATE,
    experience_data_period_end DATE,
    external_data_sources JSONB, -- [{source: 'CENSUS', description: '...'}]
    
    -- Assumptions
    key_assumptions JSONB, -- [{assumption: 'improvement_rate', value: 0.01}, ...]
    
    -- Validation
    validation_results JSONB, -- {mse: 0.02, bias: 0.001}
    validation_date DATE,
    peer_reviewed BOOLEAN DEFAULT FALSE,
    
    -- Governance
    model_owner VARCHAR(100),
    actuary_signatory VARCHAR(100),
    approval_date DATE,
    
    -- Status
    model_status VARCHAR(20) DEFAULT 'DEVELOPMENT' 
        CHECK (model_status IN ('DEVELOPMENT', 'VALIDATION', 'APPROVED', 'ACTIVE', 'DEPRECATED')),
    is_active BOOLEAN DEFAULT FALSE,
    
    -- Version
    model_version VARCHAR(20) NOT NULL DEFAULT '1.0',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_risk_assessment_model_code UNIQUE (tenant_id, model_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.risk_assessment_models_default PARTITION OF dynamic.risk_assessment_models DEFAULT;

-- Indexes
CREATE INDEX idx_risk_assessment_models_tenant ON dynamic.risk_assessment_models(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_risk_assessment_models_type ON dynamic.risk_assessment_models(tenant_id, assessment_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.risk_assessment_models IS 'Actuarial risk assessment models for insurance';

-- Triggers
CREATE TRIGGER trg_risk_assessment_models_audit
    BEFORE UPDATE ON dynamic.risk_assessment_models
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.risk_assessment_models TO finos_app;