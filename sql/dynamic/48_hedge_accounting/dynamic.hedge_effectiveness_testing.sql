-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 48: Hedge Accounting (IFRS 9)
-- Table: hedge_effectiveness_testing
-- Description: Prospective and retrospective hedge effectiveness testing results
--              with dollar offset, regression, and critical terms match analysis
-- Compliance: IFRS 9 (2014), IAS 39, US GAAP ASC 815
-- ================================================================================

CREATE TABLE dynamic.hedge_effectiveness_testing (
    -- Primary Identity
    test_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Hedge Reference
    hedge_id UUID NOT NULL REFERENCES dynamic.hedge_designation(hedge_id),
    
    -- Test Identification
    test_date DATE NOT NULL,
    test_type VARCHAR(50) NOT NULL CHECK (test_type IN ('PROSPECTIVE', 'RETROSPECTIVE')),
    test_sequence INTEGER NOT NULL, -- Quarterly test number, etc.
    
    -- Test Methodology
    testing_method VARCHAR(100) NOT NULL CHECK (testing_method IN (
        'DOLLAR_OFFSET', 'VARIANCE_REDUCTION', 'REGRESSION', 'CRITICAL_TERMS_MATCH', 'HYPO_CRITICAL_TERMS'
    )),
    
    -- Dollar Offset Results
    change_in_hedged_item DECIMAL(28,8),
    change_in_hedging_instrument DECIMAL(28,8),
    dollar_offset_ratio DECIMAL(10,6), -- Change in hedging / Change in hedged item
    
    -- Regression Results (when applicable)
    regression_r_squared DECIMAL(5,4),
    regression_slope DECIMAL(10,6),
    regression_intercept DECIMAL(28,8),
    regression_f_statistic DECIMAL(18,6),
    regression_p_value DECIMAL(8,6),
    
    -- Critical Terms Match (when applicable)
    critical_terms_matched BOOLEAN,
    terms_mismatches JSONB, -- Array of mismatched terms
    
    -- Effectiveness Assessment
    effectiveness_result VARCHAR(50) NOT NULL CHECK (effectiveness_result IN (
        'HIGHLY_EFFECTIVE', 'EFFECTIVE', 'PARTIALLY_EFFECTIVE', 'INEFFECTIVE'
    )),
    effectiveness_pct DECIMAL(6,2), -- Actual effectiveness percentage
    within_80_125_band BOOLEAN NOT NULL, -- IFRS 9 threshold test
    
    -- Ineffectiveness Amount
    ineffective_portion DECIMAL(28,8) DEFAULT 0,
    ineffective_portion_pnl_impact DECIMAL(28,8),
    
    -- Rebalancing (if required)
    rebalancing_required BOOLEAN DEFAULT FALSE,
    rebalancing_adjustment DECIMAL(28,8),
    rebalancing_rationale TEXT,
    
    -- Discontinuation Assessment
    discontinuation_triggered BOOLEAN DEFAULT FALSE,
    discontinuation_reason VARCHAR(100),
    
    -- Documentation
    test_calculation_details JSONB,
    supporting_documentation_ref VARCHAR(255),
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    
    -- Partitioning
    partition_key DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT valid_dollar_offset CHECK (dollar_offset_ratio IS NULL OR dollar_offset_ratio > 0),
    CONSTRAINT valid_regression_r2 CHECK (regression_r_squared IS NULL OR (regression_r_squared >= 0 AND regression_r_squared <= 1))
) PARTITION BY RANGE (partition_key);

-- Default partition
CREATE TABLE dynamic.hedge_effectiveness_testing_default PARTITION OF dynamic.hedge_effectiveness_testing
    DEFAULT;

-- Monthly partitions
CREATE TABLE dynamic.hedge_effectiveness_testing_2025_01 PARTITION OF dynamic.hedge_effectiveness_testing
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.hedge_effectiveness_testing_2025_02 PARTITION OF dynamic.hedge_effectiveness_testing
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Indexes
CREATE INDEX idx_hedge_effectiveness_hedge ON dynamic.hedge_effectiveness_testing (tenant_id, hedge_id, test_date);
CREATE INDEX idx_hedge_effectiveness_type ON dynamic.hedge_effectiveness_testing (tenant_id, test_type);
CREATE INDEX idx_hedge_effectiveness_result ON dynamic.hedge_effectiveness_testing (tenant_id, effectiveness_result);
CREATE INDEX idx_hedge_effectiveness_ineffective ON dynamic.hedge_effectiveness_testing (tenant_id, ineffective_portion) WHERE ineffective_portion != 0;
CREATE INDEX idx_hedge_effectiveness_discontinue ON dynamic.hedge_effectiveness_testing (tenant_id, discontinuation_triggered) WHERE discontinuation_triggered = TRUE;

-- Comments
COMMENT ON TABLE dynamic.hedge_effectiveness_testing IS 'Prospective and retrospective hedge effectiveness testing per IFRS 9';
COMMENT ON COLUMN dynamic.hedge_effectiveness_testing.dollar_offset_ratio IS 'Ratio of hedging instrument change to hedged item change (target: 80%-125%)';
COMMENT ON COLUMN dynamic.hedge_effectiveness_testing.within_80_125_band IS 'IFRS 9 effectiveness threshold: dollar offset ratio between 80% and 125%';

-- RLS
ALTER TABLE dynamic.hedge_effectiveness_testing ENABLE ROW LEVEL SECURITY;
CREATE POLICY hedge_effectiveness_testing_tenant_isolation ON dynamic.hedge_effectiveness_testing
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.hedge_effectiveness_testing TO finos_app_user;
GRANT SELECT ON dynamic.hedge_effectiveness_testing TO finos_readonly_user;
