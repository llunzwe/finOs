-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 32 - Insurance Product Modules
-- TABLE: dynamic.insurance_product_config
--
-- DESCRIPTION:
--   Enterprise-grade insurance product configuration engine.
--   Life, non-life, health, motor, property product definitions.
--   Supports IFRS 17, embedded insurance, and bitemporal tracking.
--
-- COMPLIANCE: IFRS 17, Solvency II, GAAP, Insurance Regulations
-- ============================================================================


CREATE TABLE dynamic.insurance_product_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Product Identification
    product_code VARCHAR(100) NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    product_description TEXT,
    
    -- Classification
    insurance_type VARCHAR(50) NOT NULL 
        CHECK (insurance_type IN ('LIFE', 'HEALTH', 'MOTOR', 'PROPERTY', 'LIABILITY', 'TRAVEL', 'DEVICE', 'CREDIT', 'BUNDLE')),
    life_insurance_category VARCHAR(50), -- 'TERM', 'WHOLE_LIFE', 'ENDOWMENT', 'UNIVERSAL' (if LIFE)
    
    -- IFRS 17 Classification
    ifrs17_contract_type VARCHAR(50) 
        CHECK (ifrs17_contract_type IN ('VFA', 'GMM', 'PAA')), -- Variable Fee Approach, General Measurement Model, Premium Allocation Approach
    ifrs17_aggregation_level VARCHAR(50),
    
    -- Coverage Details
    coverage_types TEXT[], -- ['DEATH', 'DISABILITY', 'CRITICAL_ILLNESS']
    base_sum_assured_min DECIMAL(28,8),
    base_sum_assured_max DECIMAL(28,8),
    coverage_term_options INTEGER[], -- Years: [5, 10, 15, 20, 25]
    
    -- Premium Configuration
    premium_frequency_options VARCHAR(20)[] DEFAULT ARRAY['MONTHLY', 'QUARTERLY', 'ANNUAL', 'SINGLE'],
    premium_calculation_method TEXT, -- Formula or model reference
    base_premium_rate DECIMAL(10,6), -- Rate per 1000 sum assured
    
    -- Underwriting
    underwriting_type VARCHAR(50) DEFAULT 'AUTOMATED' 
        CHECK (underwriting_type IN ('AUTOMATED', 'MANUAL', 'HYBRID')),
    medical_exam_required BOOLEAN DEFAULT FALSE,
    max_auto_approval_amount DECIMAL(28,8),
    
    -- Riders & Add-ons
    available_riders JSONB DEFAULT '[]', -- Array of rider options
    
    -- Embedded Insurance
    is_embedded_product BOOLEAN DEFAULT FALSE,
    host_product_types VARCHAR(50)[], -- Can be embedded in: ['LOAN', 'CREDIT_CARD', 'TRAVEL_BOOKING']
    embedded_trigger_event VARCHAR(100), -- Event that triggers coverage
    
    -- Takaful Specific
    is_takaful BOOLEAN DEFAULT FALSE,
    takaful_model VARCHAR(50), -- 'WAKALAH', 'MUDARABAH', 'WAQF'
    operator_fee_percentage DECIMAL(5,4) DEFAULT 0.20, -- 20%
    qard_hasan_enabled BOOLEAN DEFAULT FALSE,
    
    -- Exclusions & Waiting Periods
    standard_exclusions TEXT[],
    waiting_period_days INTEGER DEFAULT 0,
    suicide_exclusion_months INTEGER DEFAULT 24,
    
    -- Status
    product_status VARCHAR(20) DEFAULT 'DRAFT' 
        CHECK (product_status IN ('DRAFT', 'PENDING_APPROVAL', 'ACTIVE', 'SUSPENDED', 'WITHDRAWN')),
    launch_date DATE,
    withdrawal_date DATE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_product_code_per_tenant UNIQUE (tenant_id, product_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.insurance_product_config_default PARTITION OF dynamic.insurance_product_config DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_insurance_product_tenant ON dynamic.insurance_product_config(tenant_id);
CREATE INDEX idx_insurance_product_type ON dynamic.insurance_product_config(tenant_id, insurance_type);
CREATE INDEX idx_insurance_product_status ON dynamic.insurance_product_config(tenant_id, product_status);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.insurance_product_config IS 'Insurance product configuration - life, health, motor, property, embedded insurance. Tier 2 - Insurance Product Modules.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.insurance_product_config TO finos_app;
