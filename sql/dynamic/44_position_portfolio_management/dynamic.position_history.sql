-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 44: Position & Portfolio Management
-- Table: position_history
-- Description: Bitemporal position tracking - trade-date and settlement-date views
--              with full history for T+1 settlement cycles and reconciliation
-- Compliance: Portfolio Reconciliation, P&L Attribution, Regulatory Reporting
-- ================================================================================

CREATE TABLE dynamic.position_history (
    -- Primary Identity
    position_history_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Position Reference
    position_id UUID NOT NULL, -- References current position
    account_id UUID NOT NULL REFERENCES core.account_master(id),
    instrument_id UUID NOT NULL REFERENCES dynamic.securities_master(security_id),
    
    -- Position Date Types (Critical for T+1 settlement)
    as_of_date DATE NOT NULL,
    position_view VARCHAR(50) NOT NULL CHECK (position_view IN ('TRADE_DATE', 'SETTLEMENT_DATE', 'RECORD_DATE')),
    -- TRADE_DATE: Includes trades executed but not yet settled
    -- SETTLEMENT_DATE: Only settled positions
    -- RECORD_DATE: As of specific record date (for corporate actions)
    
    -- Quantity & Holdings
    quantity DECIMAL(28,8) NOT NULL,
    available_quantity DECIMAL(28,8) NOT NULL, -- Excluding holds, pledges
    blocked_quantity DECIMAL(28,8) DEFAULT 0, -- Held for pending settlement
    pledged_quantity DECIMAL(28,8) DEFAULT 0, -- Collateral, securities lending
    borrowed_quantity DECIMAL(28,8) DEFAULT 0, -- Short positions
    
    -- Position Type
    holding_type VARCHAR(50) NOT NULL CHECK (holding_type IN ('LONG', 'SHORT', 'COVERED_SHORT', 'BORROWED', 'LENT')),
    
    -- Financial Metrics
    book_cost DECIMAL(28,8), -- Original cost basis
    market_value DECIMAL(28,8), -- Current market value
    unrealized_pnl DECIMAL(28,8),
    realized_pnl_daily DECIMAL(28,8),
    currency_code CHAR(3) NOT NULL,
    
    -- Strategy Tags
    book_id UUID, -- Trading book reference
    strategy_id UUID,
    portfolio_id UUID,
    desk VARCHAR(100),
    trader VARCHAR(100),
    
    -- Settlement Status
    pending_settlements JSONB, -- Array of pending trades affecting position
    settlement_fail_count INTEGER DEFAULT 0,
    
    -- Corporate Action Adjustments
    ca_adjustment_factor DECIMAL(10,6) DEFAULT 1.0, -- Split adjustment
    ca_adjusted_cost_basis DECIMAL(28,8),
    
    -- Bitemporal (Critical for position reconstruction)
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31',
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Partitioning
    partition_key DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT valid_position_dates CHECK (valid_from < valid_to),
    CONSTRAINT valid_quantities CHECK (quantity = available_quantity + blocked_quantity + pledged_quantity)
) PARTITION BY RANGE (partition_key);

-- Default partition
CREATE TABLE dynamic.position_history_default PARTITION OF dynamic.position_history
    DEFAULT;

-- Monthly partitions
CREATE TABLE dynamic.position_history_2025_01 PARTITION OF dynamic.position_history
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.position_history_2025_02 PARTITION OF dynamic.position_history
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE dynamic.position_history_2025_03 PARTITION OF dynamic.position_history
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

-- Indexes for Position History
CREATE INDEX idx_position_history_account ON dynamic.position_history (tenant_id, account_id, as_of_date);
CREATE INDEX idx_position_history_instrument ON dynamic.position_history (tenant_id, instrument_id, as_of_date);
CREATE INDEX idx_position_history_view ON dynamic.position_history (tenant_id, position_view, as_of_date);
CREATE INDEX idx_position_history_current ON dynamic.position_history (tenant_id, account_id, instrument_id, as_of_date DESC) 
    WHERE is_current = TRUE;
CREATE INDEX idx_position_history_portfolio ON dynamic.position_history (tenant_id, portfolio_id, as_of_date);
CREATE INDEX idx_position_history_strategy ON dynamic.position_history (tenant_id, strategy_id, as_of_date);

-- Comments
COMMENT ON TABLE dynamic.position_history IS 'Bitemporal position tracking with trade-date and settlement-date views';
COMMENT ON COLUMN dynamic.position_history.position_view IS 'VIEW type: TRADE_DATE (includes pending), SETTLEMENT_DATE (settled only)';
COMMENT ON COLUMN dynamic.position_history.pending_settlements IS 'JSON array of trades pending settlement affecting this position';

-- RLS
ALTER TABLE dynamic.position_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY position_history_tenant_isolation ON dynamic.position_history
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT ON dynamic.position_history TO finos_app_user;
GRANT SELECT ON dynamic.position_history TO finos_readonly_user;
