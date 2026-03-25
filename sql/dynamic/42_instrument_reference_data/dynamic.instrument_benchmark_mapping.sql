-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 42: Instrument Reference Data Management
-- Table: instrument_benchmark_mapping
-- Description: Benchmark and index constituent mappings - tracks instrument membership
--              in indices (S&P 500, FTSE 100, etc.) with effective dates
-- Compliance: Index Fund Management, Performance Attribution
-- ================================================================================

CREATE TABLE dynamic.instrument_benchmark_mapping (
    -- Primary Identity
    mapping_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- References
    instrument_id UUID NOT NULL REFERENCES dynamic.securities_master(security_id),
    benchmark_id UUID NOT NULL, -- References the benchmark instrument
    
    -- Benchmark Details
    benchmark_type VARCHAR(50) NOT NULL CHECK (benchmark_type IN (
        'EQUITY_INDEX', 'BOND_INDEX', 'COMPOSITE_INDEX', 'SECTOR_INDEX',
        'CUSTOM_BENCHMARK', 'PEER_GROUP', 'BLENDED_BENCHMARK'
    )),
    benchmark_name VARCHAR(200) NOT NULL,
    benchmark_provider VARCHAR(100), -- MSCI, FTSE Russell, S&P Dow Jones, Bloomberg
    
    -- Constituent Details
    constituent_weight DECIMAL(10,6), -- Weight in benchmark (0-1)
    constituent_rank INTEGER, -- Rank by market cap/weight
    price_factor DECIMAL(10,6) DEFAULT 1.0, -- Adjustment factor
    
    -- Membership Dates
    membership_start_date DATE NOT NULL,
    membership_end_date DATE DEFAULT '9999-12-31',
    is_current_constituent BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Change Reason
    membership_change_reason VARCHAR(100) CHECK (membership_change_reason IN (
        'INITIAL_INCLUSION', 'REBALANCE', 'REPLACEMENT', 'MERGER',
        'DELISTING', 'SPIN_OFF', 'SECTOR_CHANGE', 'RULE_CHANGE'
    )),
    
    -- Rebalancing
    last_rebalance_date DATE,
    next_rebalance_date DATE,
    
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
    CONSTRAINT valid_benchmark_dates CHECK (valid_from < valid_to),
    CONSTRAINT valid_membership_dates CHECK (membership_start_date < membership_end_date),
    CONSTRAINT valid_weight CHECK (constituent_weight >= 0 AND constituent_weight <= 1)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE dynamic.instrument_benchmark_mapping_default PARTITION OF dynamic.instrument_benchmark_mapping
    DEFAULT;

-- Indexes
CREATE INDEX idx_instrument_benchmark_mapping_instrument ON dynamic.instrument_benchmark_mapping (tenant_id, instrument_id);
CREATE INDEX idx_instrument_benchmark_mapping_benchmark ON dynamic.instrument_benchmark_mapping (tenant_id, benchmark_id, is_current_constituent);
CREATE INDEX idx_instrument_benchmark_mapping_current ON dynamic.instrument_benchmark_mapping (tenant_id, benchmark_id) 
    WHERE is_current = TRUE AND is_current_constituent = TRUE;
CREATE INDEX idx_instrument_benchmark_mapping_dates ON dynamic.instrument_benchmark_mapping (tenant_id, membership_start_date, membership_end_date);

-- Comments
COMMENT ON TABLE dynamic.instrument_benchmark_mapping IS 'Benchmark and index constituent mappings for performance attribution';
COMMENT ON COLUMN dynamic.instrument_benchmark_mapping.constituent_weight IS 'Weight of instrument in benchmark (0.00 to 1.00)';

-- RLS
ALTER TABLE dynamic.instrument_benchmark_mapping ENABLE ROW LEVEL SECURITY;
CREATE POLICY instrument_benchmark_mapping_tenant_isolation ON dynamic.instrument_benchmark_mapping
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.instrument_benchmark_mapping TO finos_app_user;
GRANT SELECT ON dynamic.instrument_benchmark_mapping TO finos_readonly_user;
