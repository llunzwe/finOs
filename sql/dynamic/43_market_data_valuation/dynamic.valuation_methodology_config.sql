-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 43: Market Data & Valuation
-- Table: valuation_methodology_config
-- Description: Valuation model configuration - fair value hierarchy, pricing models,
--              and methodology rules per instrument class
-- Compliance: IFRS 13, US GAAP, Fair Value Measurement Standards
-- ================================================================================

CREATE TABLE dynamic.valuation_methodology_config (
    -- Primary Identity
    methodology_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Methodology Definition
    methodology_code VARCHAR(100) NOT NULL,
    methodology_name VARCHAR(200) NOT NULL,
    methodology_description TEXT,
    
    -- Fair Value Hierarchy (IFRS 13)
    fair_value_level VARCHAR(20) NOT NULL CHECK (fair_value_level IN ('LEVEL_1', 'LEVEL_2', 'LEVEL_3')),
    -- Level 1: Quoted prices in active markets
    -- Level 2: Observable inputs (yield curves, vol surfaces)
    -- Level 3: Unobservable inputs (management estimates)
    
    -- Instrument Classification
    instrument_type VARCHAR(100) NOT NULL,
    asset_class VARCHAR(50) CHECK (asset_class IN ('EQUITY', 'FIXED_INCOME', 'DERIVATIVE', 'FX', 'COMMODITY', 'STRUCTURED_PRODUCT')),
    
    -- Pricing Model
    pricing_model VARCHAR(100) NOT NULL CHECK (pricing_model IN (
        'DISCOUNTED_CASH_FLOW', 'BLACK_SCHOLES', 'BINOMIAL_TREE', 'MONTE_CARLO',
        'MARKET_COMPARABLE', 'REPLACEMENT_COST', 'NET_REALIZABLE_VALUE',
        'MATRIX_PRICING', 'OPTION_ADJUSTED_SPREAD', 'PROXY_PRICING'
    )),
    
    -- Model Inputs Configuration
    required_inputs JSONB NOT NULL,
    -- Example: {"yield_curve": true, "credit_spread": true, "volatility_surface": false}
    optional_inputs JSONB,
    input_hierarchy JSONB, -- Priority order for input sources
    
    -- Valuation Rules
    price_source_priority JSONB NOT NULL, -- Ordered list of preferred price sources
    fallback_methodology UUID REFERENCES dynamic.valuation_methodology_config(methodology_id),
    
    -- Frequency & Timing
    valuation_frequency VARCHAR(50) DEFAULT 'DAILY' CHECK (valuation_frequency IN ('REAL_TIME', 'INTRADAY', 'DAILY', 'WEEKLY', 'MONTHLY')),
    valuation_time TIME, -- Specific time for daily valuation
    holiday_convention VARCHAR(50) DEFAULT 'FOLLOWING', -- FOLLOWING, MODIFIED_FOLLOWING, PRECEDING
    
    -- Quality Thresholds
    min_data_quality_score DECIMAL(3,2) DEFAULT 0.80,
    max_staleness_hours INTEGER DEFAULT 24,
    
    -- Model Risk Management
    model_owner VARCHAR(100),
    model_validation_date DATE,
    model_expiry_date DATE,
    model_version VARCHAR(20),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE NOT NULL DEFAULT '9999-12-31',
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_methodology_code_per_tenant UNIQUE (tenant_id, methodology_code),
    CONSTRAINT valid_methodology_dates CHECK (effective_from < effective_to),
    CONSTRAINT valid_quality_threshold CHECK (min_data_quality_score >= 0 AND min_data_quality_score <= 1)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE dynamic.valuation_methodology_config_default PARTITION OF dynamic.valuation_methodology_config
    DEFAULT;

-- Indexes
CREATE UNIQUE INDEX idx_valuation_methodology_active ON dynamic.valuation_methodology_config (tenant_id, methodology_code)
    WHERE is_active = TRUE AND effective_to = '9999-12-31';
CREATE INDEX idx_valuation_methodology_level ON dynamic.valuation_methodology_config (tenant_id, fair_value_level, asset_class);
CREATE INDEX idx_valuation_methodology_model ON dynamic.valuation_methodology_config (tenant_id, pricing_model);

-- Comments
COMMENT ON TABLE dynamic.valuation_methodology_config IS 'Valuation model configuration with IFRS 13 fair value hierarchy';
COMMENT ON COLUMN dynamic.valuation_methodology_config.fair_value_level IS 'IFRS 13 fair value hierarchy: Level 1 (quoted), Level 2 (observable), Level 3 (unobservable)';
COMMENT ON COLUMN dynamic.valuation_methodology_config.price_source_priority IS 'JSON array of preferred price sources in priority order';

-- RLS
ALTER TABLE dynamic.valuation_methodology_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY valuation_methodology_config_tenant_isolation ON dynamic.valuation_methodology_config
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.valuation_methodology_config TO finos_app_user;
GRANT SELECT ON dynamic.valuation_methodology_config TO finos_readonly_user;
