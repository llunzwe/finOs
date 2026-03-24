-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 27 - Risk Provisioning Engine
-- TABLE: dynamic.ecl_calculation_engine
--
-- DESCRIPTION:
--   Enterprise-grade Expected Credit Loss (ECL) calculation engine configuration.
--   IFRS 9 Stage 1/2/3 provisioning rules, probability of default (PD), 
--   loss given default (LGD), exposure at default (EAD) models.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - IFRS 9 (Financial Instruments)
--   - Basel III/IV (Credit Risk)
--   - EBA Guidelines on PD/LGD estimation
--   - GDPR
--   - SOC2
--
-- AUDIT & GOVERNANCE:
--   - Bitemporal tracking
--   - Full audit trail
--   - Model versioning and validation
--   - Tenant isolation via partitioning
--
-- ============================================================================


CREATE TABLE dynamic.ecl_calculation_engine (
    model_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Model Identification
    model_code VARCHAR(100) NOT NULL,
    model_name VARCHAR(200) NOT NULL,
    model_description TEXT,
    model_version VARCHAR(20) NOT NULL DEFAULT '1.0.0',
    
    -- IFRS 9 Stage Configuration
    ifrs9_stage INTEGER NOT NULL 
        CHECK (ifrs9_stage IN (1, 2, 3)),
    stage_criteria TEXT, -- SQL/logic for stage assignment
    
    -- ECL Components
    pd_model_type VARCHAR(50) NOT NULL 
        CHECK (pd_model_type IN ('POINT_IN_TIME', 'THROUGH_THE_CYCLE', 'HYBRID')),
    pd_calculation_method TEXT, -- SQL formula or model reference
    lgd_model_type VARCHAR(50) 
        CHECK (lgd_model_type IN ('WORKOUT', 'MARKET', 'MIXED')),
    lgd_calculation_method TEXT,
    ead_model_type VARCHAR(50) 
        CHECK (ead_model_type IN ('CURRENT', 'AMORTIZED', 'CASH_FLOW')),
    ead_calculation_method TEXT,
    
    -- Time Horizons
    lifetime_months INTEGER NOT NULL DEFAULT 12,
    forward_looking_period INTEGER DEFAULT 12, -- Months for macro-economic forecasts
    
    -- Product/Application Scope
    applicable_product_types VARCHAR(50)[],
    applicable_segments VARCHAR(50)[],
    applicable_currencies CHAR(3)[],
    
    -- Macroeconomic Factors
    macro_scenario VARCHAR(20) DEFAULT 'BASELINE' 
        CHECK (macro_scenario IN ('BASELINE', 'UPSIDE', 'DOWNSIDE', 'STRESSED')),
    macro_adjustment_factors JSONB, -- Weightings for GDP, unemployment, etc.
    
    -- Provisioning Rules
    minimum_provision_rate DECIMAL(10,6) DEFAULT 0.0,
    maximum_provision_rate DECIMAL(10,6) DEFAULT 1.0,
    provision_floor_amount DECIMAL(28,8) DEFAULT 0.0,
    
    -- Back-testing & Validation
    backtesting_frequency VARCHAR(20) DEFAULT 'QUARTERLY',
    last_validation_date DATE,
    validation_status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (validation_status IN ('PENDING', 'VALIDATED', 'REJECTED', 'UNDER_REVIEW')),
    model_accuracy DECIMAL(5,4), -- Last back-test accuracy
    
    -- Status & Control
    model_status VARCHAR(20) DEFAULT 'DRAFT' 
        CHECK (model_status IN ('DRAFT', 'ACTIVE', 'INACTIVE', 'DEPRECATED')),
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    
    -- Metadata
    attributes JSONB DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_model_code_version UNIQUE (tenant_id, model_code, model_version)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.ecl_calculation_engine_default PARTITION OF dynamic.ecl_calculation_engine DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_ecl_model_tenant ON dynamic.ecl_calculation_engine(tenant_id);
CREATE INDEX idx_ecl_model_stage ON dynamic.ecl_calculation_engine(tenant_id, ifrs9_stage);
CREATE INDEX idx_ecl_model_status ON dynamic.ecl_calculation_engine(tenant_id, model_status);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.ecl_calculation_engine IS 'IFRS 9 ECL calculation engine - PD/LGD/EAD models for credit loss provisioning. Tier 2 - Risk Provisioning Engine.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.ecl_calculation_engine TO finos_app;
