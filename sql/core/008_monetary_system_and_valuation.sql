-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 8: MONETARY SYSTEM & VALUATION
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: Multi-currency, Exchange Rates, Price History, TimescaleDB
-- Standards: ISO 4217, IFRS 13, IAS 21, ISO 10962 (CFI)
-- =============================================================================

-- Currencies and country codes are defined in 001_value_container.sql

-- =============================================================================
-- EXCHANGE RATES
-- =============================================================================
CREATE TABLE core.exchange_rates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Currency Pair (ISO 4217)
    from_currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    to_currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    
    -- Rate Details
    mid_rate DECIMAL(28,12) NOT NULL,
    bid_rate DECIMAL(28,12),
    ask_rate DECIMAL(28,12),
    spread DECIMAL(28,12) GENERATED ALWAYS AS (COALESCE(ask_rate, mid_rate) - COALESCE(bid_rate, mid_rate)) STORED,
    
    -- Rate Type
    rate_type VARCHAR(20) NOT NULL DEFAULT 'spot' 
        CHECK (rate_type IN ('spot', 'forward', 'fixing', 'intraday', 'historical', 'reference')),
    fixing_date DATE, -- For forward rates
    tenor VARCHAR(20), -- 'ON', '1W', '1M', '3M', '1Y' for forwards
    
    -- Source & Quality
    source VARCHAR(50) NOT NULL, -- 'ECB', 'FED', 'RBZ', 'Reuters', 'Bloomberg', 'calculated'
    source_reference VARCHAR(100), -- Specific fixing identifier
    data_quality_score DECIMAL(3,2) CHECK (data_quality_score BETWEEN 0 AND 1),
    is_verified BOOLEAN DEFAULT FALSE,
    
    -- Temporal (Axiom II)
    valid_from TIMESTAMPTZ NOT NULL,
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    
    -- Soft Delete
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    -- Constraints
    CONSTRAINT unique_rate_per_time UNIQUE (tenant_id, from_currency, to_currency, rate_type, valid_from),
    CONSTRAINT chk_different_currencies CHECK (from_currency != to_currency),
    CONSTRAINT chk_positive_rate CHECK (mid_rate > 0)
);

-- Index for rate lookup (latest rate as of date)
CREATE INDEX idx_exchange_rates_lookup ON core.exchange_rates(
    tenant_id, from_currency, to_currency, rate_type, valid_from DESC
) WHERE is_deleted = FALSE;
CREATE INDEX idx_exchange_rates_source ON core.exchange_rates(source, valid_from DESC);
CREATE INDEX idx_exchange_rates_tenant ON core.exchange_rates(tenant_id, valid_from DESC);
CREATE INDEX idx_exchange_rates_correlation ON core.exchange_rates(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core.exchange_rates IS 'Exchange rates with bitemporal validity and quality scoring';

-- =============================================================================
-- CURRENCY PAIRS (Reference Data)
-- =============================================================================
CREATE TABLE core.currency_pairs (
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    base_currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    quote_currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    
    -- Pair Properties
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    decimal_places INTEGER DEFAULT 4,
    
    -- Trading Parameters
    min_trade_amount DECIMAL(28,8),
    max_trade_amount DECIMAL(28,8),
    spread_bps DECIMAL(10,4), -- Default spread in basis points
    
    -- Rate Sources Priority
    primary_source VARCHAR(50),
    secondary_source VARCHAR(50),
    tertiary_source VARCHAR(50),
    
    -- Temporal
    valid_from DATE NOT NULL DEFAULT '1900-01-01',
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    
    PRIMARY KEY (tenant_id, base_currency, quote_currency)
);

CREATE INDEX idx_currency_pairs_active ON core.currency_pairs(tenant_id, is_active) WHERE is_active = TRUE;

COMMENT ON TABLE core.currency_pairs IS 'Currency pairs supported for trading/conversion';

-- =============================================================================
-- PRICE HISTORY (TimescaleDB Hypertable)
-- =============================================================================
CREATE TABLE core_history.price_history (
    time TIMESTAMPTZ NOT NULL,
    tenant_id UUID NOT NULL,
    
    -- Instrument Reference
    instrument_code VARCHAR(100) NOT NULL, -- ISIN, ticker, or internal code
    instrument_type VARCHAR(50) NOT NULL CHECK (instrument_type IN ('currency', 'security', 'commodity', 'derivative', 'index')),
    
    -- Price Data
    price_type VARCHAR(20) NOT NULL CHECK (price_type IN ('market', 'nominal', 'fair_value', 'bid', 'ask', 'close', 'open', 'high', 'low')),
    price DECIMAL(28,12) NOT NULL,
    price_currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    
    -- Volume (if applicable)
    volume DECIMAL(28,8),
    volume_currency CHAR(3),
    
    -- Source
    price_source VARCHAR(50) NOT NULL, -- 'exchange', 'vendor', 'calculated', 'manual'
    source_reference VARCHAR(100),
    market_code VARCHAR(20), -- MIC code
    
    -- Quality
    data_quality VARCHAR(20) DEFAULT 'verified' CHECK (data_quality IN ('verified', 'indicative', 'stale', 'estimated')),
    
    PRIMARY KEY (time, tenant_id, instrument_code, price_type)
);

SELECT create_hypertable('core_history.price_history', 'time', 
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists => TRUE);

CREATE INDEX idx_price_history_instrument ON core_history.price_history(tenant_id, instrument_code, time DESC);
CREATE INDEX idx_price_history_type ON core_history.price_history(tenant_id, instrument_type, price_type, time DESC);

COMMENT ON TABLE core_history.price_history IS 'Time-series price data using TimescaleDB';

-- =============================================================================
-- INSTRUMENT MASTER
-- =============================================================================
CREATE TABLE core.instruments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    instrument_type VARCHAR(20) NOT NULL 
        CHECK (instrument_type IN ('account', 'isin', 'card', 'loan', 'policy', 'security', 'commodity')),
    identifier VARCHAR(100) NOT NULL,
    
    -- ISO Standards
    isin_code VARCHAR(12) CHECK (isin_code ~ '^[A-Z]{2}[A-Z0-9]{9}[0-9]$'), -- ISO 6166
    cfi_code VARCHAR(6) CHECK (cfi_code ~ '^[A-Z]{6}$'), -- ISO 10962
    fisn VARCHAR(35), -- ISO 18774
    
    -- Classification
    asset_class VARCHAR(20) CHECK (asset_class IN ('cash', 'debt', 'equity', 'derivative', 'commodity', 'real_estate')),
    category VARCHAR(50),
    sub_category VARCHAR(50),
    
    -- Issuer/Owner
    issuer_id UUID REFERENCES core.economic_agents(id),
    owner_id UUID REFERENCES core.economic_agents(id),
    
    -- Terms
    issue_date DATE,
    maturity_date DATE,
    denomination DECIMAL(28,8),
    denomination_currency CHAR(3) REFERENCES core.currencies(code),
    
    -- For Fixed Income
    coupon_rate DECIMAL(10,6),
    coupon_frequency VARCHAR(20), -- 'monthly', 'quarterly', 'semi-annual', 'annual'
    day_count_convention VARCHAR(20), -- 'ACT/360', '30/360', 'ACT/ACT'
    
    -- For Derivatives
    underlying_instrument_id UUID REFERENCES core.instruments(id),
    strike_price DECIMAL(28,8),
    option_type VARCHAR(10), -- 'call', 'put'
    
    -- Valuation
    valuation_method VARCHAR(50) CHECK (valuation_method IN ('market', 'model', 'amortized_cost', 'fair_value')),
    ifrs13_level INTEGER CHECK (ifrs13_level IN (1, 2, 3)),
    
    -- Temporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER DEFAULT 1,
    
    CONSTRAINT unique_instrument UNIQUE (tenant_id, instrument_type, identifier),
    CONSTRAINT chk_valid_dates CHECK (valid_from < valid_to)
);

CREATE INDEX idx_instruments_lookup ON core.instruments(tenant_id, instrument_type, identifier);
CREATE INDEX idx_instruments_isin ON core.instruments(isin_code) WHERE isin_code IS NOT NULL;
CREATE INDEX idx_instruments_issuer ON core.instruments(issuer_id);
CREATE INDEX idx_instruments_underlying ON core.instruments(underlying_instrument_id) WHERE underlying_instrument_id IS NOT NULL;
CREATE INDEX idx_instruments_temporal ON core.instruments(valid_from, valid_to) WHERE is_current = TRUE;

COMMENT ON TABLE core.instruments IS 'Instrument master data supporting ISIN, CFI, and FISN standards';

-- =============================================================================
-- ACCOUNT NUMBERS & ADDRESSING
-- =============================================================================
CREATE TABLE core.account_numbers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    container_id UUID NOT NULL REFERENCES core.value_containers(id),
    
    -- Account Number Details
    account_number VARCHAR(100) NOT NULL,
    account_number_encrypted BYTEA,
    account_type VARCHAR(20) NOT NULL 
        CHECK (account_type IN ('bban', 'iban', 'card_pan', 'wallet_id', 'virtual', 'reference')),
    
    -- IBAN Specific
    check_digits VARCHAR(5),
    bank_identifier VARCHAR(20),
    branch_identifier VARCHAR(20),
    
    -- Status
    is_valid BOOLEAN NOT NULL DEFAULT TRUE,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Validation
    validated_at TIMESTAMPTZ,
    validation_method VARCHAR(50), -- 'mod97', 'api_check', 'manual'
    validation_reference VARCHAR(100),
    
    -- Temporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_account_number UNIQUE (tenant_id, account_number, account_type)
);

CREATE INDEX idx_account_numbers_container ON core.account_numbers(container_id, is_primary) WHERE is_primary = TRUE;
CREATE INDEX idx_account_numbers_lookup ON core.account_numbers(account_number, account_type);
CREATE INDEX idx_account_numbers_iban ON core.account_numbers(account_type) WHERE account_type = 'iban';

COMMENT ON TABLE core.account_numbers IS 'Account numbers including IBAN, BBAN, and card PANs';

-- =============================================================================
-- REFERENCE DATA
-- =============================================================================
CREATE TABLE core.reference_data (
    code_type VARCHAR(50) NOT NULL,
    code VARCHAR(50) NOT NULL,
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Description
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Hierarchy
    parent_code VARCHAR(50),
    parent_code_type VARCHAR(50),
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    -- Temporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    PRIMARY KEY (code_type, code, tenant_id)
);

CREATE INDEX idx_reference_data_type ON core.reference_data(tenant_id, code_type);
CREATE INDEX idx_reference_data_parent ON core.reference_data(parent_code_type, parent_code);

COMMENT ON TABLE core.reference_data IS 'Generic reference data: countries, currencies, BICs, MICs, etc.';

-- =============================================================================
-- IBAN VALIDATION FUNCTION (ISO 13616)
-- =============================================================================
-- This is a wrapper around the util_validate_iban function in 000_utilities.sql
CREATE OR REPLACE FUNCTION core.validate_iban(p_iban VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN core.util_validate_iban(p_iban);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION core.validate_iban IS 'Validates IBAN according to ISO 13616 (wrapper for util_validate_iban)';

-- =============================================================================
-- CURRENT EXCHANGE RATES MATERIALIZED VIEW
-- =============================================================================
CREATE MATERIALIZED VIEW core.current_exchange_rates AS
SELECT DISTINCT ON (tenant_id, from_currency, to_currency, rate_type)
    id,
    tenant_id,
    from_currency,
    to_currency,
    mid_rate,
    bid_rate,
    ask_rate,
    spread,
    rate_type,
    source,
    valid_from,
    valid_to,
    system_time
FROM core.exchange_rates
WHERE valid_to > NOW()
ORDER BY tenant_id, from_currency, to_currency, rate_type, valid_from DESC;

CREATE UNIQUE INDEX idx_current_rates ON core.current_exchange_rates(
    tenant_id, from_currency, to_currency, rate_type
);

COMMENT ON MATERIALIZED VIEW core.current_exchange_rates IS 'Current effective exchange rates (refresh periodically)';

-- Function to refresh materialized view
CREATE OR REPLACE FUNCTION core.refresh_exchange_rates()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY core.current_exchange_rates;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.exchange_rates TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.currency_pairs TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.instruments TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.account_numbers TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.reference_data TO finos_app;
GRANT SELECT, INSERT ON core_history.price_history TO finos_app;
GRANT SELECT ON core.current_exchange_rates TO finos_app;
GRANT EXECUTE ON FUNCTION core.validate_iban TO finos_app;
GRANT EXECUTE ON FUNCTION core.refresh_exchange_rates TO finos_app;
