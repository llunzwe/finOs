-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 48: Hedge Accounting (IFRS 9)
-- Table: hedge_designation
-- Description: Hedge relationship designation and documentation per IFRS 9
--              Fair value hedges, cash flow hedges, net investment hedges
-- Compliance: IFRS 9 (2014), IAS 39 (legacy), US GAAP ASC 815
-- ================================================================================

CREATE TABLE dynamic.hedge_designation (
    -- Primary Identity
    hedge_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Hedge Documentation
    hedge_reference VARCHAR(100) NOT NULL,
    hedge_name VARCHAR(200) NOT NULL,
    hedge_description TEXT,
    
    -- Hedge Classification
    hedge_type VARCHAR(50) NOT NULL CHECK (hedge_type IN (
        'FAIR_VALUE', 'CASH_FLOW', 'NET_INVESTMENT'
    )),
    hedge_sub_type VARCHAR(100) CHECK (hedge_sub_type IN (
        'INTEREST_RATE_RISK', 'FOREIGN_CURRENCY_RISK', 'CREDIT_RISK',
        'COMMODITY_PRICE_RISK', 'EQUITY_PRICE_RISK', 'BASIS_RISK'
    )),
    
    -- Hedged Item
    hedged_item_type VARCHAR(100) NOT NULL CHECK (hedged_item_type IN (
        'RECOGNIZED_ASSET', 'RECOGNIZED_LIABILITY', 'FIRM_COMMITMENT',
        'FORECAST_TRANSACTION', 'NET_INVESTMENT', 'PORTFOLIO'
    )),
    hedged_item_description TEXT NOT NULL,
    hedged_item_instrument_id UUID REFERENCES dynamic.securities_master(security_id),
    hedged_item_account_id UUID REFERENCES core.account_master(id),
    hedged_item_notional DECIMAL(28,8),
    hedged_item_currency CHAR(3),
    
    -- Hedging Instrument
    hedging_instrument_id UUID NOT NULL REFERENCES dynamic.securities_master(security_id),
    hedging_instrument_type VARCHAR(50) CHECK (hedging_instrument_type IN (
        'INTEREST_RATE_SWAP', 'CROSS_CURRENCY_SWAP', 'FX_FORWARD', 'FX_OPTION',
        'COMMODITY_SWAP', 'EQUITY_SWAP', 'FUTURES', 'OPTIONS'
    )),
    hedging_instrument_notional DECIMAL(28,8),
    hedging_instrument_currency CHAR(3),
    
    -- Hedge Ratio
    hedge_ratio_numerator DECIMAL(10,6) NOT NULL DEFAULT 1.0,
    hedge_ratio_denominator DECIMAL(10,6) NOT NULL DEFAULT 1.0,
    hedge_ratio DECIMAL(10,6) GENERATED ALWAYS AS (hedge_ratio_numerator / hedge_ratio_denominator) STORED,
    
    -- Risk Management Strategy
    risk_management_strategy TEXT NOT NULL,
    hedge_objective TEXT NOT NULL,
    expected_hedge_duration_months INTEGER,
    
    -- Hedge Effectiveness
    effectiveness_testing_method VARCHAR(100) NOT NULL DEFAULT 'DOLLAR_OFFSET' CHECK (effectiveness_testing_method IN (
        'DOLLAR_OFFSET', 'VARIANCE_REDUCTION', 'REGRESSION', 'CRITICAL_TERMS_MATCH'
    )),
    effectiveness_threshold_pct DECIMAL(5,2) DEFAULT 80.00,
    
    -- Designation Period
    designation_date DATE NOT NULL,
    expected_termination_date DATE,
    actual_termination_date DATE,
    termination_reason VARCHAR(100),
    
    -- Status
    hedge_status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (hedge_status IN (
        'DESIGNATED', 'ACTIVE', 'DISCONTINUED', 'EXPIRED', 'TERMINATED', 'REBALANCED'
    )),
    effectiveness_status VARCHAR(50) DEFAULT 'NOT_TESTED' CHECK (effectiveness_status IN (
        'NOT_TESTED', 'HIGHLY_EFFECTIVE', 'EFFECTIVE', 'INEFFECTIVE', 'PARTIALLY_EFFECTIVE'
    )),
    
    -- Accounting
    accounting_ledger_impact JSONB,
    oci_balance DECIMAL(28,8) DEFAULT 0,
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31',
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_hedge_ref_per_tenant UNIQUE (tenant_id, hedge_reference),
    CONSTRAINT valid_hedge_dates CHECK (valid_from < valid_to),
    CONSTRAINT valid_designation_dates CHECK (designation_date <= expected_termination_date OR expected_termination_date IS NULL),
    CONSTRAINT valid_hedge_ratio CHECK (hedge_ratio_denominator != 0)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE dynamic.hedge_designation_default PARTITION OF dynamic.hedge_designation
    DEFAULT;

-- Indexes
CREATE UNIQUE INDEX idx_hedge_designation_active ON dynamic.hedge_designation (tenant_id, hedge_reference)
    WHERE is_current = TRUE AND valid_to = '9999-12-31';
CREATE INDEX idx_hedge_designation_type ON dynamic.hedge_designation (tenant_id, hedge_type, hedge_status);
CREATE INDEX idx_hedge_designation_item ON dynamic.hedge_designation (tenant_id, hedged_item_instrument_id);
CREATE INDEX idx_hedge_designation_instrument ON dynamic.hedge_designation (tenant_id, hedging_instrument_id);
CREATE INDEX idx_hedge_designation_effectiveness ON dynamic.hedge_designation (tenant_id, effectiveness_status);

-- Comments
COMMENT ON TABLE dynamic.hedge_designation IS 'Hedge relationship designation per IFRS 9';
COMMENT ON COLUMN dynamic.hedge_designation.effectiveness_threshold_pct IS 'IFRS 9: 80% - 125% effectiveness band for hedge accounting';
COMMENT ON COLUMN dynamic.hedge_designation.hedge_type IS 'FAIR_VALUE: hedges fair value changes; CASH_FLOW: hedges cash flow variability';

-- RLS
ALTER TABLE dynamic.hedge_designation ENABLE ROW LEVEL SECURITY;
CREATE POLICY hedge_designation_tenant_isolation ON dynamic.hedge_designation
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.hedge_designation TO finos_app_user;
GRANT SELECT ON dynamic.hedge_designation TO finos_readonly_user;
