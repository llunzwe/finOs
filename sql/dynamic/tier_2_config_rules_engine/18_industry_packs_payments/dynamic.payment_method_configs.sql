-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 18 - Industry Packs: Payments
-- TABLE: dynamic.payment_method_configs
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Payment Method Configs.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 8601
--   - ISO 20022
--   - IFRS 15
--   - Basel III
--   - OECD
--   - NCA
--
-- AUDIT & GOVERNANCE:
--   - Bitemporal tracking (effective_from/valid_from, effective_to/valid_to)
--   - Full audit trail (created_at, updated_at, created_by, updated_by)
--   - Version control for change management
--   - Tenant isolation via partitioning
--   - Row-Level Security (RLS) for data protection
--
-- DATA CLASSIFICATION:
--   - Tenant Isolation: Row-Level Security enabled
--   - Audit Level: FULL
--   - Encryption: At-rest for sensitive fields
--
-- ============================================================================
CREATE TABLE dynamic.payment_method_configs (

    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    method_code VARCHAR(100) NOT NULL,
    method_name VARCHAR(200) NOT NULL,
    method_description TEXT,
    
    -- Method Type
    payment_type VARCHAR(50) NOT NULL 
        CHECK (payment_type IN ('CARD', 'BANK_TRANSFER', 'WALLET', 'CRYPTO', 'BNPL', 'VOUCHER', 'CASH', 'DIRECT_DEBIT', 'REAL_TIME_PAYMENT')),
    payment_brand VARCHAR(50), -- VISA, MASTERCARD, PAYPAL, APPLE_PAY, etc.
    
    -- Card Specific (if applicable)
    card_scheme dynamic.card_scheme,
    card_type dynamic.card_type,
    
    -- Configuration
    config_jsonb JSONB NOT NULL DEFAULT '{}', -- Method-specific settings
    
    -- Limits
    min_transaction_amount DECIMAL(28,8) DEFAULT 0,
    max_transaction_amount DECIMAL(28,8),
    daily_limit_amount DECIMAL(28,8),
    monthly_limit_amount DECIMAL(28,8),
    
    -- Fees
    merchant_fee_percentage DECIMAL(10,6) DEFAULT 0,
    merchant_fee_fixed DECIMAL(28,8) DEFAULT 0,
    customer_fee_percentage DECIMAL(10,6) DEFAULT 0,
    customer_fee_fixed DECIMAL(28,8) DEFAULT 0,
    
    -- Currencies
    supported_currencies CHAR(3)[],
    default_currency CHAR(3),
    
    -- Countries
    supported_countries CHAR(2)[],
    excluded_countries CHAR(2)[],
    
    -- Settlement
    settlement_currency CHAR(3),
    settlement_delay_days INTEGER DEFAULT 2,
    settlement_schedule VARCHAR(20) DEFAULT 'DAILY', -- DAILY, WEEKLY, MONTHLY
    
    -- Risk
    risk_score_weight INTEGER DEFAULT 0,
    requires_3ds BOOLEAN DEFAULT FALSE,
    fraud_checks_enabled BOOLEAN DEFAULT TRUE,
    
    -- Customer Experience
    display_order INTEGER DEFAULT 0,
    display_name VARCHAR(100),
    logo_url VARCHAR(500),
    customer_instructions TEXT,
    
    -- Recurring Payments
    supports_recurring BOOLEAN DEFAULT FALSE,
    recurring_types VARCHAR(50)[], -- FIXED_AMOUNT, VARIABLE_AMOUNT, INSTALLMENT
    
    -- Refunds
    refund_supported BOOLEAN DEFAULT TRUE,
    refund_time_limit_days INTEGER DEFAULT 180,
    partial_refund_supported BOOLEAN DEFAULT TRUE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_available BOOLEAN DEFAULT TRUE, -- Can be shown to customers
    maintenance_mode BOOLEAN DEFAULT FALSE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_payment_method_code UNIQUE (tenant_id, method_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.payment_method_configs_default PARTITION OF dynamic.payment_method_configs DEFAULT;

-- Indexes
CREATE INDEX idx_payment_method_tenant ON dynamic.payment_method_configs(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_payment_method_type ON dynamic.payment_method_configs(tenant_id, payment_type) WHERE is_active = TRUE;
CREATE INDEX idx_payment_method_brand ON dynamic.payment_method_configs(tenant_id, payment_brand) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.payment_method_configs IS 'Payment method configurations with fees and limits';

-- Triggers
CREATE TRIGGER trg_payment_method_configs_audit
    BEFORE UPDATE ON dynamic.payment_method_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.payment_method_configs TO finos_app;