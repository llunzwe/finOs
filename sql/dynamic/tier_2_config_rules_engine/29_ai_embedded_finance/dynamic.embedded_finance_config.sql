-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 29 - AI & Embedded Finance
-- TABLE: dynamic.embedded_finance_config
--
-- DESCRIPTION:
--   Enterprise-grade embedded finance configuration.
--   Banking-as-a-Service (BaaS) partnerships, white-label products.
--   API orchestration, revenue sharing, partner integration.
--
-- COMPLIANCE: PSD2, Open Banking, GDPR, PCI DSS, Banking Regulations
-- ============================================================================


CREATE TABLE dynamic.embedded_finance_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Partner Information
    partner_code VARCHAR(100) NOT NULL,
    partner_name VARCHAR(200) NOT NULL,
    partner_type VARCHAR(50) NOT NULL 
        CHECK (partner_type IN ('FINTECH', 'RETAIL', 'TELCO', 'AUTO', 'HEALTHCARE', 'PAYMENT_PLATFORM', 'MARKETPLACE')),
    partner_legal_entity VARCHAR(200),
    partner_registration_number VARCHAR(100),
    
    -- Embedded Products
    embedded_products VARCHAR(50)[] NOT NULL, -- ['ACCOUNTS', 'PAYMENTS', 'LENDING', 'CARDS', 'INSURANCE']
    white_label_branding BOOLEAN DEFAULT TRUE,
    co_branded BOOLEAN DEFAULT FALSE,
    
    -- Integration Configuration
    integration_type VARCHAR(50) DEFAULT 'API' 
        CHECK (integration_type IN ('API', 'SDK', 'WIDGET', 'IFRAME', 'WHITE_LABEL_APP')),
    api_version VARCHAR(20) DEFAULT 'v1',
    webhook_url TEXT,
    ip_whitelist INET[],
    
    -- Authentication
    auth_method VARCHAR(50) DEFAULT 'OAUTH2' 
        CHECK (auth_method IN ('API_KEY', 'OAUTH2', 'MUTUAL_TLS', 'JWT')),
    api_key_rotation_days INTEGER DEFAULT 90,
    mtls_certificate_expiry DATE,
    
    -- Customer Journey
    onboarding_flow VARCHAR(50) DEFAULT 'EMBEDDED' 
        CHECK (onboarding_flow IN ('EMBEDDED', 'REDIRECT', 'HYBRID')),
    kyc_provider VARCHAR(100),
    kyc_responsibility VARCHAR(20) DEFAULT 'BANK' 
        CHECK (kyc_responsibility IN ('BANK', 'PARTNER', 'SHARED')),
    
    -- Revenue Sharing
    revenue_share_model VARCHAR(50) DEFAULT 'INTERCHANGE_SPLIT' 
        CHECK (revenue_share_model IN ('INTERCHANGE_SPLIT', 'FLAT_FEE', 'PER_TRANSACTION', 'TIERED', 'HYBRID')),
    revenue_share_percentage DECIMAL(5,4), -- Partner's share
    minimum_monthly_fee DECIMAL(28,8),
    
    -- Product Configuration
    account_types VARCHAR(50)[], -- ['CHECKING', 'SAVINGS', 'WALLET']
    card_program_enabled BOOLEAN DEFAULT FALSE,
    lending_products_enabled BOOLEAN DEFAULT FALSE,
    insurance_products_enabled BOOLEAN DEFAULT FALSE,
    
    -- Limits & Controls
    max_daily_transactions INTEGER,
    max_transaction_amount DECIMAL(28,8),
    monthly_volume_limit DECIMAL(28,8),
    
    -- Reporting
    reporting_frequency VARCHAR(20) DEFAULT 'MONTHLY',
    settlement_frequency VARCHAR(20) DEFAULT 'MONTHLY',
    settlement_account_iban VARCHAR(50),
    
    -- Contract Details
    contract_start_date DATE NOT NULL,
    contract_end_date DATE,
    auto_renewal BOOLEAN DEFAULT TRUE,
    termination_notice_days INTEGER DEFAULT 90,
    
    -- Status
    partnership_status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (partnership_status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'TERMINATED')),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_partner_code_per_tenant UNIQUE (tenant_id, partner_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.embedded_finance_config_default PARTITION OF dynamic.embedded_finance_config DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.embedded_finance_config IS 'Embedded finance configuration - BaaS partnerships, white-label products, API orchestration. Tier 2 - AI & Embedded Finance.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.embedded_finance_config TO finos_app;
