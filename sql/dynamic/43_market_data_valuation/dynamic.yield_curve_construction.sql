-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 43: Market Data & Valuation
-- Table: yield_curve_construction
-- Description: Yield curve construction and bootstrapping configuration - supports
--              multiple curve types (discount, forward, credit spread)
-- Compliance: IFRS 9, Derivatives Valuation, Risk Management
-- ================================================================================

CREATE TABLE dynamic.yield_curve_construction (
    -- Primary Identity
    curve_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Curve Identification
    curve_code VARCHAR(100) NOT NULL,
    curve_name VARCHAR(200) NOT NULL,
    curve_description TEXT,
    
    -- Curve Classification
    curve_type VARCHAR(50) NOT NULL CHECK (curve_type IN (
        'DISCOUNT', 'ZERO_COUPON', 'FORWARD', 'PAR', 'CREDIT_SPREAD',
        'BASIS_SPREAD', 'FX_FORWARD', 'INFLATION', 'DIVIDEND'
    )),
    curve_currency CHAR(3) NOT NULL,
    curve_tenor VARCHAR(20), -- e.g., '3M', '6M' for tenor basis curves
    
    -- Benchmark Reference
    reference_index VARCHAR(50), -- SOFR, EURIBOR, LIBOR (legacy), SONIA
    reference_index_term VARCHAR(20), -- e.g., '3M' for 3-month SOFR
    
    -- Construction Methodology
    construction_method VARCHAR(100) NOT NULL CHECK (construction_method IN (
        'BOOTSTRAP', 'NELSON_SIEGEL', 'SPLINE_CUBIC', 'SPLINE_BILINEAR',
        'PARAMETRIC', 'PIECEWISE_LINEAR', 'SMOOTHING_SPLINE'
    )),
    interpolation_method VARCHAR(100) DEFAULT 'LINEAR' CHECK (interpolation_method IN (
        'LINEAR', 'LOG_LINEAR', 'CUBIC_SPLINE', 'HERMITE', 'MONOTONE_CONVEX'
    )),
    extrapolation_method VARCHAR(100) DEFAULT 'FLAT' CHECK (extrapolation_method IN (
        'FLAT', 'LINEAR', 'NONE'
    )),
    
    -- Instrument Selection for Construction
    instrument_selection_criteria JSONB NOT NULL,
    -- Example:
    -- {
    --   "cash": {"tenors": ["O/N", "T/N", "1W", "1M", "3M", "6M", "12M"]},
    --   "futures": {"exchanges": ["CME", "Liffe"], "tenors": ["H25", "M25", "U25", "Z25"]},
    --   "swaps": {"tenors": ["2Y", "5Y", "10Y", "30Y"]}
    -- }
    
    -- Quality & Filters
    min_instrument_quality DECIMAL(3,2) DEFAULT 0.90,
    outlier_detection_method VARCHAR(50) DEFAULT 'STANDARD_DEVIATION',
    outlier_threshold DECIMAL(5,2) DEFAULT 3.00, -- Standard deviations
    
    -- Curve Output
    output_tenors JSONB NOT NULL, -- ["O/N", "1W", "1M", "3M", "6M", "1Y", "2Y", "5Y", "10Y", "30Y"]
    day_count_convention VARCHAR(50) DEFAULT 'ACT/360',
    compound_frequency VARCHAR(20) DEFAULT 'CONTINUOUS',
    
    -- Update Schedule
    update_frequency VARCHAR(50) DEFAULT 'DAILY',
    update_time TIME DEFAULT '08:00:00',
    intraday_updates BOOLEAN DEFAULT FALSE,
    
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
    CONSTRAINT unique_curve_code_per_tenant UNIQUE (tenant_id, curve_code),
    CONSTRAINT valid_curve_dates CHECK (effective_from < effective_to),
    CONSTRAINT valid_quality CHECK (min_instrument_quality >= 0 AND min_instrument_quality <= 1)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE dynamic.yield_curve_construction_default PARTITION OF dynamic.yield_curve_construction
    DEFAULT;

-- Indexes
CREATE UNIQUE INDEX idx_yield_curve_active ON dynamic.yield_curve_construction (tenant_id, curve_code)
    WHERE is_active = TRUE AND effective_to = '9999-12-31';
CREATE INDEX idx_yield_curve_type ON dynamic.yield_curve_construction (tenant_id, curve_type, curve_currency);
CREATE INDEX idx_yield_curve_reference ON dynamic.yield_curve_construction (tenant_id, reference_index, reference_index_term);

-- Comments
COMMENT ON TABLE dynamic.yield_curve_construction IS 'Yield curve construction configuration for discounting and valuation';
COMMENT ON COLUMN dynamic.yield_curve_construction.instrument_selection_criteria IS 'JSON configuration of instruments used for curve construction';

-- RLS
ALTER TABLE dynamic.yield_curve_construction ENABLE ROW LEVEL SECURITY;
CREATE POLICY yield_curve_construction_tenant_isolation ON dynamic.yield_curve_construction
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.yield_curve_construction TO finos_app_user;
GRANT SELECT ON dynamic.yield_curve_construction TO finos_readonly_user;
