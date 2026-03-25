-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 43: Market Data & Valuation
-- Table: market_data_snapshot
-- Description: Market data capture with provenance, quality metrics, and temporal validity
--              Supports tick, EOD, and intraday price discovery
-- Compliance: Best Execution, MiFID II, Market Abuse Regulations
-- ================================================================================

CREATE TABLE dynamic.market_data_snapshot (
    -- Primary Identity
    snapshot_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Instrument Reference
    instrument_id UUID NOT NULL REFERENCES dynamic.securities_master(security_id),
    
    -- Price Identification
    price_type VARCHAR(50) NOT NULL CHECK (price_type IN (
        'BID', 'ASK', 'MID', 'LAST', 'OPEN', 'HIGH', 'LOW', 'CLOSE',
        'VWAP', 'TWAP', 'EVALUATED', 'THEORETICAL', 'INTERPOLATED',
        'STALE_PRICE', 'INDICATIVE', 'REFERENCE'
    )),
    price_source VARCHAR(100) NOT NULL, -- Bloomberg, Refinitiv, Exchange, Internal
    
    -- Price Data
    price DECIMAL(28,8) NOT NULL,
    price_currency CHAR(3) NOT NULL,
    quantity DECIMAL(28,8), -- Associated trade size for LAST price
    
    -- Market Context
    market_venue VARCHAR(100), -- Exchange or trading venue
    market_conditions VARCHAR(50) CHECK (market_conditions IN (
        'NORMAL', 'FAST_MARKET', 'VOLATILE', 'HALTED', 'AUCTION', 'PRE_OPEN', 'POST_CLOSE'
    )),
    
    -- Timestamp Hierarchy
    quote_timestamp TIMESTAMPTZ NOT NULL, -- When price was quoted
    received_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(), -- When we received it
    processed_timestamp TIMESTAMPTZ, -- When we processed it
    
    -- Quality Metrics
    data_quality_score DECIMAL(3,2), -- 0.00 to 1.00
    confidence_level VARCHAR(20) CHECK (confidence_level IN ('HIGH', 'MEDIUM', 'LOW', 'UNVERIFIED')),
    staleness_seconds INTEGER, -- Seconds since last update
    is_stale BOOLEAN DEFAULT FALSE,
    
    -- Pricing Methodology
    pricing_methodology VARCHAR(100) CHECK (pricing_methodology IN (
        'MARKET_QUOTE', 'MODEL_PRICING', 'INTERPOLATED_CURVE', 'MATRIX_PRICING',
        'THEORETICAL_MODEL', 'STALE_PRICE_CARRIED', 'MANUAL_OVERRIDE'
    )),
    
    -- Spread Information (for BID/ASK)
    spread_bps DECIMAL(10,4), -- Spread in basis points
    depth_levels JSONB, -- Order book depth: [{"level":1,"bid":100,"ask":101,"bid_qty":500}]
    
    -- Source Attribution
    data_vendor VARCHAR(100),
    vendor_ticker VARCHAR(50),
    field_code VARCHAR(50), -- Bloomberg field code, etc.
    
    -- Partitioning
    partition_key DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT valid_price CHECK (price >= 0),
    CONSTRAINT valid_quality_score CHECK (data_quality_score >= 0 AND data_quality_score <= 1)
) PARTITION BY RANGE (partition_key);

-- Default partition
CREATE TABLE dynamic.market_data_snapshot_default PARTITION OF dynamic.market_data_snapshot
    DEFAULT;

-- Monthly partitions for market data (high volume)
CREATE TABLE dynamic.market_data_snapshot_2025_01 PARTITION OF dynamic.market_data_snapshot
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.market_data_snapshot_2025_02 PARTITION OF dynamic.market_data_snapshot
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE dynamic.market_data_snapshot_2025_03 PARTITION OF dynamic.market_data_snapshot
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

-- Indexes for Market Data Performance
CREATE INDEX idx_market_data_snapshot_instrument ON dynamic.market_data_snapshot (tenant_id, instrument_id, quote_timestamp DESC);
CREATE INDEX idx_market_data_snapshot_price_type ON dynamic.market_data_snapshot (tenant_id, price_type, quote_timestamp DESC);
CREATE INDEX idx_market_data_snapshot_source ON dynamic.market_data_snapshot (tenant_id, price_source, quote_timestamp DESC);
CREATE INDEX idx_market_data_snapshot_current ON dynamic.market_data_snapshot (tenant_id, instrument_id, price_type, quote_timestamp DESC);
CREATE INDEX idx_market_data_snapshot_quality ON dynamic.market_data_snapshot (tenant_id, data_quality_score) WHERE data_quality_score < 0.8;
CREATE INDEX idx_market_data_snapshot_stale ON dynamic.market_data_snapshot (tenant_id, is_stale) WHERE is_stale = TRUE;

-- Comments
COMMENT ON TABLE dynamic.market_data_snapshot IS 'Market data capture with provenance, quality metrics, and temporal validity';
COMMENT ON COLUMN dynamic.market_data_snapshot.staleness_seconds IS 'Seconds elapsed since last market data update';
COMMENT ON COLUMN dynamic.market_data_snapshot.pricing_methodology IS 'Method used to determine price (market quote, model, interpolation, etc.)';

-- RLS
ALTER TABLE dynamic.market_data_snapshot ENABLE ROW LEVEL SECURITY;
CREATE POLICY market_data_snapshot_tenant_isolation ON dynamic.market_data_snapshot
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT ON dynamic.market_data_snapshot TO finos_app_user;
GRANT SELECT ON dynamic.market_data_snapshot TO finos_readonly_user;
