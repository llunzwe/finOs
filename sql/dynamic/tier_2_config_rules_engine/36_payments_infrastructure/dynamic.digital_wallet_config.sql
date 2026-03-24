-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 36 - Payments Infrastructure
-- TABLE: dynamic.digital_wallet_config
--
-- DESCRIPTION:
--   Enterprise-grade digital wallet and tokenization configuration.
--   Apple Pay, Google Pay, Samsung Pay, HCE, NFC tokenization.
--
-- COMPLIANCE: PCI DSS, EMVCo, Scheme Rules (Visa/MC/Amex)
-- ============================================================================


CREATE TABLE dynamic.digital_wallet_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Wallet Configuration
    wallet_provider VARCHAR(50) NOT NULL 
        CHECK (wallet_provider IN ('APPLE_PAY', 'GOOGLE_PAY', 'SAMSUNG_PAY', 'GARMIN_PAY', 'FITBIT_PAY', 'HCE', 'PROPRIETARY')),
    wallet_name VARCHAR(200) NOT NULL,
    
    -- Tokenization
    tokenization_enabled BOOLEAN DEFAULT TRUE,
    tokenization_scheme VARCHAR(50) DEFAULT 'NETWORK' 
        CHECK (tokenization_scheme IN ('NETWORK', 'ISSUER', 'Gateway')),
    token_expiry_months INTEGER DEFAULT 36,
    
    -- Card Support
    supported_card_schemes VARCHAR(20)[] DEFAULT ARRAY['VISA', 'MASTERCARD'],
    supported_device_types VARCHAR(50)[] DEFAULT ARRAY['MOBILE', 'WEARABLE', 'IOT'],
    
    -- Authentication
    authentication_methods VARCHAR(50)[] DEFAULT ARRAY['BIOMETRIC', 'PIN', 'DEVICE_LOCK'],
    cvm_limit_contactless DECIMAL(28,8), -- Cardholder verification method limit
    no_cvm_limit_contactless DECIMAL(28,8), -- No CVM limit
    
    -- NFC/Contactless
    nfc_enabled BOOLEAN DEFAULT TRUE,
    contactless_enabled BOOLEAN DEFAULT TRUE,
    magstripe_mode_enabled BOOLEAN DEFAULT FALSE,
    
    -- In-App Provisioning
    in_app_provisioning_enabled BOOLEAN DEFAULT TRUE,
    manual_entry_provisioning_enabled BOOLEAN DEFAULT TRUE,
    
    -- Security
    device_binding_required BOOLEAN DEFAULT TRUE,
    geolocation_check_enabled BOOLEAN DEFAULT TRUE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_wallet_provider UNIQUE (tenant_id, wallet_provider)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.digital_wallet_config_default PARTITION OF dynamic.digital_wallet_config DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.digital_wallet_config IS 'Digital wallet configuration - Apple Pay, Google Pay, tokenization, NFC. Tier 2 - Payments Infrastructure.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.digital_wallet_config TO finos_app;
