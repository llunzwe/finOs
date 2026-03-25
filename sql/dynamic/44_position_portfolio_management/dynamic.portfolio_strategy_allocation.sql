-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 44: Position & Portfolio Management
-- Table: portfolio_strategy_allocation
-- Description: Portfolio strategy allocation rules - defines how positions are
--              allocated to strategies, benchmarks, and target allocations
-- Compliance: Investment Management, Performance Attribution, UCITS/AIFMD
-- ================================================================================

CREATE TABLE dynamic.portfolio_strategy_allocation (
    -- Primary Identity
    allocation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Allocation Hierarchy
    portfolio_id UUID NOT NULL,
    strategy_id UUID NOT NULL,
    parent_allocation_id UUID REFERENCES dynamic.portfolio_strategy_allocation(allocation_id),
    
    -- Strategy Details
    strategy_name VARCHAR(200) NOT NULL,
    strategy_code VARCHAR(100) NOT NULL,
    strategy_description TEXT,
    
    -- Strategy Classification
    strategy_type VARCHAR(100) NOT NULL CHECK (strategy_type IN (
        'CORE', 'SATELLITE', 'TACTICAL', 'STRATEGIC', 'HEDGING',
        'ALPHA_GENERATION', 'BETA_REPLICATION', 'ARBITRAGE', 'ENHANCED_INDEX'
    )),
    asset_class VARCHAR(50) CHECK (asset_class IN ('EQUITY', 'FIXED_INCOME', 'ALTERNATIVE', 'CASH', 'MULTI_ASSET')),
    geographic_focus VARCHAR(100),
    sector_focus VARCHAR(100),
    
    -- Target Allocation
    target_allocation_pct DECIMAL(5,2) NOT NULL CHECK (target_allocation_pct >= 0 AND target_allocation_pct <= 100),
    min_allocation_pct DECIMAL(5,2) DEFAULT 0,
    max_allocation_pct DECIMAL(5,2) DEFAULT 100,
    tolerance_band_pct DECIMAL(5,2) DEFAULT 5.00, -- Rebalancing trigger
    
    -- Benchmark
    benchmark_instrument_id UUID REFERENCES dynamic.securities_master(security_id),
    benchmark_weight DECIMAL(5,2) DEFAULT 100.00, -- 100 = pure benchmark, < 100 = active share
    
    -- Constraints
    long_only BOOLEAN DEFAULT TRUE,
    max_single_position_pct DECIMAL(5,2), -- Concentration limit
    max_sector_deviation_pct DECIMAL(5,2), -- From benchmark
    max_turnover_annual_pct DECIMAL(5,2), -- Trading limit
    
    -- Risk Constraints
    max_var_daily DECIMAL(28,8),
    max_tracking_error_pct DECIMAL(5,2),
    max_drawdown_pct DECIMAL(5,2),
    leverage_limit DECIMAL(5,2) DEFAULT 1.00,
    
    -- Rebalancing Rules
    rebalancing_frequency VARCHAR(50) DEFAULT 'MONTHLY' CHECK (rebalancing_frequency IN (
        'CONTINUOUS', 'DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'THRESHOLD_BASED'
    )),
    rebalancing_threshold_pct DECIMAL(5,2), -- Trigger when deviation exceeds this
    rebalancing_method VARCHAR(50) DEFAULT 'PROPORTIONAL' CHECK (rebalancing_method IN (
        'PROPORTIONAL', 'CASH_FLOW', 'TAX_OPTIMIZED', 'SHORTFALL'
    )),
    
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
    CONSTRAINT unique_strategy_code_per_portfolio UNIQUE (tenant_id, portfolio_id, strategy_code),
    CONSTRAINT valid_allocation_range CHECK (min_allocation_pct <= target_allocation_pct AND target_allocation_pct <= max_allocation_pct),
    CONSTRAINT valid_dates CHECK (effective_from < effective_to)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE dynamic.portfolio_strategy_allocation_default PARTITION OF dynamic.portfolio_strategy_allocation
    DEFAULT;

-- Indexes
CREATE UNIQUE INDEX idx_portfolio_strategy_active ON dynamic.portfolio_strategy_allocation (tenant_id, portfolio_id, strategy_code)
    WHERE is_active = TRUE AND effective_to = '9999-12-31';
CREATE INDEX idx_portfolio_strategy_portfolio ON dynamic.portfolio_strategy_allocation (tenant_id, portfolio_id);
CREATE INDEX idx_portfolio_strategy_type ON dynamic.portfolio_strategy_allocation (tenant_id, strategy_type, asset_class);
CREATE INDEX idx_portfolio_strategy_benchmark ON dynamic.portfolio_strategy_allocation (tenant_id, benchmark_instrument_id);

-- Comments
COMMENT ON TABLE dynamic.portfolio_strategy_allocation IS 'Portfolio strategy allocation rules with target weights and rebalancing logic';
COMMENT ON COLUMN dynamic.portfolio_strategy_allocation.tolerance_band_pct IS 'Deviation from target that triggers rebalancing';
COMMENT ON COLUMN dynamic.portfolio_strategy_allocation.benchmark_weight IS '100% = pure index replication, <100% = active management';

-- RLS
ALTER TABLE dynamic.portfolio_strategy_allocation ENABLE ROW LEVEL SECURITY;
CREATE POLICY portfolio_strategy_allocation_tenant_isolation ON dynamic.portfolio_strategy_allocation
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.portfolio_strategy_allocation TO finos_app_user;
GRANT SELECT ON dynamic.portfolio_strategy_allocation TO finos_readonly_user;
