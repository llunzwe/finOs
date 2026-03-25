-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 45: Settlement Fails Management (CSDR)
-- Table: settlement_fails_management
-- Description: Central Securities Depository Regulation (CSDR) settlement fails
--              tracking with penalty calculation and buy-in/sell-out workflows
-- Compliance: CSDR (EU) 909/2014, Buy-in Regime, Settlement Discipline
-- ================================================================================

CREATE TABLE dynamic.settlement_fails_management (
    -- Primary Identity
    fail_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Trade Reference
    trade_id UUID NOT NULL,
    settlement_instruction_id UUID NOT NULL,
    
    -- Settlement Details
    intended_settlement_date DATE NOT NULL,
    actual_settlement_date DATE,
    settlement_location VARCHAR(100) NOT NULL, -- Euroclear, Clearstream, DTC, etc.
    settlement_type VARCHAR(50) CHECK (settlement_type IN ('DVP', 'DFP', 'FOP', 'FREE')),
    
    -- Counterparty
    counterparty_id UUID NOT NULL REFERENCES dynamic.counterparty_master(counterparty_id),
    counterparty_role VARCHAR(50) CHECK (counterparty_role IN ('DELIVERER', 'RECEIVER')),
    
    -- Fail Details
    fail_reason_code VARCHAR(50) NOT NULL CHECK (fail_reason_code IN (
        'NO_INSTRUMENTS', 'NO_CASH', 'SETTLEMENT_SUSPENDED', 'COUNTERPARTY_DEFAULT',
        'TECHNICAL_ERROR', 'DOCUMENTATION_MISSING', 'REFERENCE_DATA_MISMATCH',
        'CLIENT_INSTRUCTION_DELAY', 'CUSTODIAN_DELAY', 'MARKET_HOLIDAY',
        'TRADE_CANCELLATION', 'PLACEHOLDER', 'OTHER'
    )),
    fail_reason_description TEXT,
    fail_direction VARCHAR(20) CHECK (fail_direction IN ('DELIVERY_FAIL', 'RECEIPT_FAIL')),
    
    -- CSDR Penalty Calculation
    penalty_applicable BOOLEAN DEFAULT TRUE,
    penalty_calculation_basis VARCHAR(50) DEFAULT 'MARKET_VALUE', -- MARKET_VALUE, TRADE_VALUE
    penalty_rate_bps DECIMAL(5,2), -- Penalty rate in basis points
    penalty_amount DECIMAL(28,8),
    penalty_currency CHAR(3),
    penalty_calculated_at TIMESTAMPTZ,
    penalty_settled BOOLEAN DEFAULT FALSE,
    penalty_settled_at TIMESTAMPTZ,
    
    -- Buy-in/Sell-out Regime (CSDR Article 7)
    buy_in_sell_out_triggered BOOLEAN DEFAULT FALSE,
    buy_in_sell_out_type VARCHAR(50) CHECK (buy_in_sell_out_type IN ('BUY_IN', 'SELL_OUT')),
    buy_in_sell_out_deadline DATE, -- 4 business days after ISD for buy-in
    buy_in_sell_out_executed BOOLEAN DEFAULT FALSE,
    buy_in_sell_out_execution_date DATE,
    buy_in_sell_out_price DECIMAL(28,8),
    buy_in_sell_out_costs DECIMAL(28,8),
    buy_in_sell_out_compensation DECIMAL(28,8),
    
    -- Pass-through to Client
    client_pass_through_applicable BOOLEAN DEFAULT FALSE,
    client_pass_through_amount DECIMAL(28,8),
    client_pass_through_status VARCHAR(50) DEFAULT 'PENDING',
    
    -- Resolution
    resolution_status VARCHAR(50) DEFAULT 'OPEN' CHECK (resolution_status IN (
        'OPEN', 'PENDING_BUY_IN', 'BUY_IN_EXECUTED', 'PARTIALLY_SETTLED',
        'SETTLED', 'CANCELLED', 'ESCALATED', 'LITIGATION'
    )),
    resolution_date DATE,
    resolution_notes TEXT,
    
    -- Reporting
    reported_to_regulator BOOLEAN DEFAULT FALSE,
    reported_at TIMESTAMPTZ,
    regulator_reference VARCHAR(100),
    
    -- Partitioning
    partition_key DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT valid_fail_dates CHECK (intended_settlement_date <= actual_settlement_date OR actual_settlement_date IS NULL)
) PARTITION BY RANGE (partition_key);

-- Default partition
CREATE TABLE dynamic.settlement_fails_management_default PARTITION OF dynamic.settlement_fails_management
    DEFAULT;

-- Monthly partitions
CREATE TABLE dynamic.settlement_fails_management_2025_01 PARTITION OF dynamic.settlement_fails_management
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.settlement_fails_management_2025_02 PARTITION OF dynamic.settlement_fails_management
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE dynamic.settlement_fails_management_2025_03 PARTITION OF dynamic.settlement_fails_management
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

-- Indexes
CREATE INDEX idx_settlement_fails_trade ON dynamic.settlement_fails_management (tenant_id, trade_id);
CREATE INDEX idx_settlement_fails_counterparty ON dynamic.settlement_fails_management (tenant_id, counterparty_id);
CREATE INDEX idx_settlement_fails_reason ON dynamic.settlement_fails_management (tenant_id, fail_reason_code);
CREATE INDEX idx_settlement_fails_status ON dynamic.settlement_fails_management (tenant_id, resolution_status);
CREATE INDEX idx_settlement_fails_buy_in ON dynamic.settlement_fails_management (tenant_id, buy_in_sell_out_triggered) 
    WHERE buy_in_sell_out_triggered = TRUE;
CREATE INDEX idx_settlement_fails_penalty ON dynamic.settlement_fails_management (tenant_id, penalty_settled) 
    WHERE penalty_settled = FALSE;
CREATE INDEX idx_settlement_fails_isd ON dynamic.settlement_fails_management (tenant_id, intended_settlement_date);

-- Comments
COMMENT ON TABLE dynamic.settlement_fails_management IS 'CSDR settlement fails tracking with penalty calculation and buy-in workflows';
COMMENT ON COLUMN dynamic.settlement_fails_management.buy_in_sell_out_deadline IS 'CSDR Article 7: 4 business days after ISD for mandatory buy-in';
COMMENT ON COLUMN dynamic.settlement_fails_management.penalty_rate_bps IS 'CSDR penalty rate in basis points (varies by instrument type)';

-- RLS
ALTER TABLE dynamic.settlement_fails_management ENABLE ROW LEVEL SECURITY;
CREATE POLICY settlement_fails_management_tenant_isolation ON dynamic.settlement_fails_management
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.settlement_fails_management TO finos_app_user;
GRANT SELECT ON dynamic.settlement_fails_management TO finos_readonly_user;
