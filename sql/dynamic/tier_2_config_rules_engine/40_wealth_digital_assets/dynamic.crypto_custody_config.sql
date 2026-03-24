-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 40 - Wealth & Digital Assets
-- TABLE: dynamic.crypto_custody_config
--
-- DESCRIPTION:
--   Enterprise-grade cryptocurrency custody and trading configuration.
--   Cold storage, hot wallets, staking, tokenized RWA support.
--
-- COMPLIANCE: FATF, MiCA, SEC, FCA, Financial Regulations
-- ============================================================================


CREATE TABLE dynamic.crypto_custody_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Configuration
    config_name VARCHAR(200) NOT NULL,
    asset_type VARCHAR(50) NOT NULL 
        CHECK (asset_type IN ('BITCOIN', 'ETHEREUM', 'STABLECOIN', 'TOKENIZED_RWA', 'DEFI_TOKEN', 'NFT')),
    asset_symbol VARCHAR(20) NOT NULL, -- 'BTC', 'ETH', 'USDC'
    
    -- Custody Model
    custody_model VARCHAR(50) DEFAULT 'SELF_CUSTODY' 
        CHECK (custody_model IN ('SELF_CUSTODY', 'THIRD_PARTY', 'MULTI_SIG', 'HSM', 'COLD_STORAGE')),
    custody_provider VARCHAR(100), -- 'Fireblocks', 'Copper', 'BitGo'
    
    -- Wallet Configuration
    wallet_type VARCHAR(50) NOT NULL 
        CHECK (wallet_type IN ('HOT', 'WARM', 'COLD', 'MULTI_SIG')),
    address_type VARCHAR(50), -- 'SegWit', 'Legacy', 'ERC20'
    
    -- Security
    multi_sig_required BOOLEAN DEFAULT FALSE,
    multi_sig_threshold INTEGER, -- Number of signatures required
    multi_sig_total_keys INTEGER,
    
    -- Transaction Limits
    daily_withdrawal_limit DECIMAL(28,8),
    single_transaction_limit DECIMAL(28,8),
    whitelisted_addresses_only BOOLEAN DEFAULT TRUE,
    
    -- Staking
    staking_enabled BOOLEAN DEFAULT FALSE,
    staking_reward_rate DECIMAL(10,6), -- Annual percentage
    minimum_staking_amount DECIMAL(28,8),
    staking_lock_period_days INTEGER,
    
    -- Trading
    trading_enabled BOOLEAN DEFAULT FALSE,
    supported_trading_pairs VARCHAR(20)[], -- ['BTC-USD', 'ETH-USD']
    
    -- Fees
    custody_fee_rate DECIMAL(10,6), -- Annual fee percentage
    withdrawal_fee_flat DECIMAL(28,8),
    withdrawal_fee_percentage DECIMAL(5,4),
    
    -- Compliance
    travel_rule_enabled BOOLEAN DEFAULT TRUE,
    sanctions_screening_required BOOLEAN DEFAULT TRUE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_asset_symbol UNIQUE (tenant_id, asset_symbol)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.crypto_custody_config_default PARTITION OF dynamic.crypto_custody_config DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.crypto_custody_config IS 'Cryptocurrency custody configuration - cold storage, staking, tokenized RWA. Tier 2 - Wealth & Digital Assets.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.crypto_custody_config TO finos_app;
