-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 36 - Payments Infrastructure
-- TABLE: dynamic.cbdc_stablecoin_config
--
-- DESCRIPTION:
--   Enterprise-grade CBDC and stablecoin payment configuration.
--   Programmable money, smart contract triggers, tokenized deposits.
--
-- COMPLIANCE: BIS, Central Bank Regulations, AML/CFT
-- ============================================================================


CREATE TABLE dynamic.cbdc_stablecoin_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Currency Configuration
    currency_name VARCHAR(100) NOT NULL,
    currency_code VARCHAR(20) NOT NULL, -- 'e-CNY', 'USDC', 'PYUSD'
    currency_type VARCHAR(50) NOT NULL 
        CHECK (currency_type IN ('CBDC_RETAIL', 'CBDC_WHOLESALE', 'FIAT_BACKED_STABLECOIN', 'CRYPTO_BACKED', 'ALGORITHMIC')),
    
    -- Issuer Details
    issuer_type VARCHAR(50) NOT NULL 
        CHECK (issuer_type IN ('CENTRAL_BANK', 'BANK', 'PRIVATE_ENTITY', 'CONSORTIUM')),
    issuer_name VARCHAR(200),
    issuer_country CHAR(2),
    
    -- Blockchain/Platform
    platform_type VARCHAR(50) NOT NULL 
        CHECK (platform_type IN ('DLT', 'BLOCKCHAIN', 'CENTRALIZED_LEDGER', 'HYBRID')),
    blockchain_network VARCHAR(100), -- 'Ethereum', 'Hyperledger', 'Corda'
    smart_contract_address VARCHAR(100),
    
    -- Programmability
    programmable_features_enabled BOOLEAN DEFAULT FALSE,
    condition_types VARCHAR(50)[], -- ['TIME_LOCK', 'MULTI_SIG', 'SPENDING_LIMITS']
    smart_contract_triggers JSONB DEFAULT '{}',
    
    -- Connectivity
    api_integration_endpoint TEXT,
    wallet_provider VARCHAR(100),
    
    -- Limits & Controls
    holding_limit_per_wallet DECIMAL(28,8),
    transaction_limit_per_day DECIMAL(28,8),
    merchant_acceptance_required BOOLEAN DEFAULT TRUE,
    
    -- Compliance
    kyc_required BOOLEAN DEFAULT TRUE,
    travel_rule_threshold DECIMAL(28,8) DEFAULT 1000.00,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    pilot_mode BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_currency_code UNIQUE (tenant_id, currency_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.cbdc_stablecoin_config_default PARTITION OF dynamic.cbdc_stablecoin_config DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.cbdc_stablecoin_config IS 'CBDC and stablecoin configuration - programmable money, smart contracts. Tier 2 - Payments Infrastructure.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.cbdc_stablecoin_config TO finos_app;
