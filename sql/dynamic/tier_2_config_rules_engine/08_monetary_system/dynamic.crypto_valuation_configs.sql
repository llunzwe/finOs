-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 08 - Monetary System
-- TABLE: dynamic.crypto_valuation_configs
--
-- DESCRIPTION:
--   Cryptocurrency valuation configuration.
--   Configures price sources, valuation methods for digital assets.
--
-- CORE DEPENDENCY: 008_monetary_system_and_valuation.sql
--
-- ============================================================================

CREATE TABLE dynamic.crypto_valuation_configs (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Crypto Asset
    cryptocurrency_code VARCHAR(50) NOT NULL, -- 'BTC', 'ETH', 'USDT', etc.
    cryptocurrency_name VARCHAR(200) NOT NULL,
    blockchain_network VARCHAR(100), -- 'bitcoin', 'ethereum', 'polygon'
    token_contract_address VARCHAR(100), -- For ERC-20 tokens
    
    -- Price Sources
    primary_price_source VARCHAR(100) NOT NULL, -- 'COINBASE', 'BINANCE', 'CHAINLINK', 'BLOOMBERG'
    secondary_price_sources VARCHAR(100)[], -- Fallback sources
    price_aggregation_method VARCHAR(50) DEFAULT 'VWAP', -- VWAP, MEDIAN, AVERAGE, BEST
    
    -- Valuation Rules
    valuation_frequency VARCHAR(20) DEFAULT 'REALTIME', -- REALTIME, MINUTE, HOUR, DAY
    valuation_cutoff_time TIME DEFAULT '16:00:00',
    use_mark_to_market BOOLEAN DEFAULT TRUE,
    
    -- Volatility Adjustments
    volatility_adjustment_enabled BOOLEAN DEFAULT FALSE,
    volatility_window_hours INTEGER DEFAULT 24,
    haircut_percentage DECIMAL(5,4) DEFAULT 0.0000, -- 0% to 100%
    
    -- Custody
    requires_custody BOOLEAN DEFAULT TRUE,
    approved_custodians VARCHAR(100)[],
    
    -- Risk Limits
    max_position_limit DECIMAL(28,8),
    max_concentration_percentage DECIMAL(5,4), -- Of total portfolio
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_tradable BOOLEAN DEFAULT TRUE,
    is_settlable BOOLEAN DEFAULT TRUE,
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_crypto_config UNIQUE (tenant_id, cryptocurrency_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.crypto_valuation_configs_default PARTITION OF dynamic.crypto_valuation_configs DEFAULT;

CREATE INDEX idx_crypto_config_active ON dynamic.crypto_valuation_configs(tenant_id, cryptocurrency_code) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.crypto_valuation_configs IS 'Cryptocurrency valuation configuration for digital asset pricing. Tier 2 Low-Code';

CREATE TRIGGER trg_crypto_valuation_configs_audit
    BEFORE UPDATE ON dynamic.crypto_valuation_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.crypto_valuation_configs TO finos_app;
