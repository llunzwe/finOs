-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 49: P&L Attribution & Risk Analytics
-- Table: pnl_attribution_analysis
-- Description: P&L explain decomposition - market moves, new trades, carry,
--              credit, and other attribution factors
-- Compliance: Risk Management, Performance Attribution, Investor Reporting
-- ================================================================================

CREATE TABLE dynamic.pnl_attribution_analysis (
    -- Primary Identity
    attribution_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Analysis Context
    analysis_date DATE NOT NULL,
    analysis_period VARCHAR(50) NOT NULL CHECK (analysis_period IN ('DAILY', 'MTD', 'QTD', 'YTD', 'ITD', 'CUSTOM')),
    
    -- Portfolio/Position Reference
    portfolio_id UUID,
    strategy_id UUID,
    position_id UUID,
    account_id UUID REFERENCES core.account_master(id),
    instrument_id UUID REFERENCES dynamic.securities_master(security_id),
    
    -- Total P&L
    total_pnl DECIMAL(28,8) NOT NULL,
    total_pnl_currency CHAR(3) NOT NULL,
    
    -- Market Attribution (The Greeks)
    delta_pnl DECIMAL(28,8) DEFAULT 0, -- Price/spot movement
    gamma_pnl DECIMAL(28,8) DEFAULT 0, -- Convexity
    vega_pnl DECIMAL(28,8) DEFAULT 0, -- Volatility change
    theta_pnl DECIMAL(28,8) DEFAULT 0, -- Time decay
    rho_pnl DECIMAL(28,8) DEFAULT 0, -- Rate change
    basis_pnl DECIMAL(28,8) DEFAULT 0, -- Basis risk
    
    -- Carry Attribution
    carry_pnl DECIMAL(28,8) DEFAULT 0, -- Roll down, coupon accrual
    financing_pnl DECIMAL(28,8) DEFAULT 0, -- Funding cost/benefit
    dividend_pnl DECIMAL(28,8) DEFAULT 0, -- Dividend impact
    repo_pnl DECIMAL(28,8) DEFAULT 0, -- Repo financing
    
    -- Credit Attribution
    credit_pnl DECIMAL(28,8) DEFAULT 0, -- Credit spread change
    default_pnl DECIMAL(28,8) DEFAULT 0, -- Actual default impact
    recovery_pnl DECIMAL(28,8) DEFAULT 0, -- Recovery value changes
    
    -- Trading Attribution
    new_trades_pnl DECIMAL(28,8) DEFAULT 0,
    unwinds_pnl DECIMAL(28,8) DEFAULT 0,
    amendments_pnl DECIMAL(28,8) DEFAULT 0,
    
    -- Cross Effects
    cross_gamma_pnl DECIMAL(28,8) DEFAULT 0,
    vanna_pnl DECIMAL(28,8) DEFAULT 0, -- Delta-vol correlation
    volga_pnl DECIMAL(28,8) DEFAULT 0, -- Vol of vol
    
    -- Residual/Unexplained
    residual_pnl DECIMAL(28,8) DEFAULT 0,
    unexplained_pct DECIMAL(5,2),
    
    -- Reconciliation
    attribution_quality_score DECIMAL(3,2), -- 0.00 to 1.00
    reconciliation_status VARCHAR(50) DEFAULT 'PENDING' CHECK (reconciliation_status IN ('PENDING', 'RECONCILED', 'BREAK', 'ADJUSTED')),
    
    -- Market Data Reference
    market_data_snapshot_id UUID REFERENCES dynamic.market_data_snapshot(snapshot_id),
    
    -- Partitioning
    partition_key DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY RANGE (partition_key);

-- Default partition
CREATE TABLE dynamic.pnl_attribution_analysis_default PARTITION OF dynamic.pnl_attribution_analysis
    DEFAULT;

-- Monthly partitions
CREATE TABLE dynamic.pnl_attribution_analysis_2025_01 PARTITION OF dynamic.pnl_attribution_analysis
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.pnl_attribution_analysis_2025_02 PARTITION OF dynamic.pnl_attribution_analysis
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Indexes
CREATE INDEX idx_pnl_attr_portfolio ON dynamic.pnl_attribution_analysis (tenant_id, portfolio_id, analysis_date);
CREATE INDEX idx_pnl_attr_strategy ON dynamic.pnl_attribution_analysis (tenant_id, strategy_id, analysis_date);
CREATE INDEX idx_pnl_attr_instrument ON dynamic.pnl_attribution_analysis (tenant_id, instrument_id, analysis_date);
CREATE INDEX idx_pnl_attr_period ON dynamic.pnl_attribution_analysis (tenant_id, analysis_period, analysis_date);
CREATE INDEX idx_pnl_attr_recon ON dynamic.pnl_attribution_analysis (tenant_id, reconciliation_status) WHERE reconciliation_status != 'RECONCILED';

-- Comments
COMMENT ON TABLE dynamic.pnl_attribution_analysis IS 'P&L attribution decomposition into market, carry, credit, and trading factors';
COMMENT ON COLUMN dynamic.pnl_attribution_analysis.delta_pnl IS 'P&L from spot/price movements (first order)';
COMMENT ON COLUMN dynamic.pnl_attribution_analysis.carry_pnl IS 'P&L from time decay, roll down, carry';

-- RLS
ALTER TABLE dynamic.pnl_attribution_analysis ENABLE ROW LEVEL SECURITY;
CREATE POLICY pnl_attribution_analysis_tenant_isolation ON dynamic.pnl_attribution_analysis
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.pnl_attribution_analysis TO finos_app_user;
GRANT SELECT ON dynamic.pnl_attribution_analysis TO finos_readonly_user;
