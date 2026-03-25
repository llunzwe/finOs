-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 45: Settlement Fails Management (CSDR)
-- Table: buy_in_sell_out_rules
-- Description: Buy-in and sell-out execution rules per market and instrument type
--              CSDR Article 7 compliance configuration
-- Compliance: CSDR (EU) 909/2014 Article 7
-- ================================================================================

CREATE TABLE dynamic.buy_in_sell_out_rules (
    -- Primary Identity
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Definition
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Applicability
    market_mic VARCHAR(20), -- Market identifier code (XETR, XLON, etc.)
    settlement_location VARCHAR(100), -- Euroclear, Clearstream, DTC
    instrument_type VARCHAR(50) CHECK (instrument_type IN ('EQUITY', 'BOND', 'ETF', 'FUND', 'DERIVATIVE')),
    instrument_sub_type VARCHAR(50), -- Government bond, Corporate bond, etc.
    
    -- Trigger Conditions (CSDR Article 7)
    trigger_business_days INTEGER NOT NULL DEFAULT 4, -- Days after ISD to trigger
    fail_threshold_quantity DECIMAL(28,8), -- Minimum quantity for trigger
    fail_threshold_value DECIMAL(28,8), -- Minimum value for trigger
    
    -- Execution Rules
    execution_method VARCHAR(100) DEFAULT 'MARKET_ORDER' CHECK (execution_method IN (
        'MARKET_ORDER', 'LIMIT_ORDER', 'AUCTION', 'DARK_POOL', 'REQUEST_FOR_QUOTE'
    )),
    execution_venue VARCHAR(100), -- Primary venue for execution
    alternative_venues JSONB, -- Fallback venues in priority order
    
    -- Price Determination
    pricing_reference VARCHAR(100) NOT NULL, -- Closing price, VWAP, etc.
    price_limit_pct DECIMAL(5,2) DEFAULT 5.00, -- Maximum deviation from reference
    execution_time_window_start TIME DEFAULT '09:00:00',
    execution_time_window_end TIME DEFAULT '17:30:00',
    
    -- Cost Allocation
    cost_allocation_method VARCHAR(50) DEFAULT 'DEFAULTING_PARTY' CHECK (cost_allocation_method IN (
        'DEFAULTING_PARTY', 'NON_DEFAULTING_PARTY', 'PRO_RATA', 'CLIENT_PASSES_THROUGH'
    )),
    include_transaction_costs BOOLEAN DEFAULT TRUE,
    include_financing_costs BOOLEAN DEFAULT TRUE,
    
    -- Compensation Calculation
    compensation_formula VARCHAR(100) DEFAULT 'PRICE_DIFFERENCE' CHECK (compensation_formula IN (
        'PRICE_DIFFERENCE', 'PRICE_DIFFERENCE_PLUS_COSTS', 'MARKET_VALUE'
    )),
    compensation_cap_pct DECIMAL(5,2), -- Maximum compensation as % of trade value
    
    -- Notification
    notify_defaulting_party BOOLEAN DEFAULT TRUE,
    notify_client BOOLEAN DEFAULT TRUE,
    notify_cutoff_hours INTEGER DEFAULT 2, -- Hours before execution to notify
    
    -- Exemptions
    exempt_counterparty_types JSONB, -- ["CENTRAL_BANK", "SSA"]
    exempt_instrument_ids JSONB, -- Specific exempt instruments
    exempt_due_to_market_conditions BOOLEAN DEFAULT FALSE, -- Market disruption exemption
    
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
    CONSTRAINT unique_rule_code_per_tenant UNIQUE (tenant_id, rule_code),
    CONSTRAINT valid_rule_dates CHECK (effective_from < effective_to),
    CONSTRAINT valid_trigger_days CHECK (trigger_business_days >= 1 AND trigger_business_days <= 10)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE dynamic.buy_in_sell_out_rules_default PARTITION OF dynamic.buy_in_sell_out_rules
    DEFAULT;

-- Indexes
CREATE UNIQUE INDEX idx_buy_in_rules_active ON dynamic.buy_in_sell_out_rules (tenant_id, rule_code)
    WHERE is_active = TRUE AND effective_to = '9999-12-31';
CREATE INDEX idx_buy_in_rules_market ON dynamic.buy_in_sell_out_rules (tenant_id, market_mic, settlement_location);
CREATE INDEX idx_buy_in_rules_instrument ON dynamic.buy_in_sell_out_rules (tenant_id, instrument_type, instrument_sub_type);

-- Comments
COMMENT ON TABLE dynamic.buy_in_sell_out_rules IS 'Buy-in and sell-out execution rules per CSDR Article 7';
COMMENT ON COLUMN dynamic.buy_in_sell_out_rules.trigger_business_days IS 'CSDR default: 4 business days after ISD to trigger buy-in';

-- RLS
ALTER TABLE dynamic.buy_in_sell_out_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY buy_in_sell_out_rules_tenant_isolation ON dynamic.buy_in_sell_out_rules
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.buy_in_sell_out_rules TO finos_app_user;
GRANT SELECT ON dynamic.buy_in_sell_out_rules TO finos_readonly_user;
