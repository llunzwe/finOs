-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 36 - Payments Infrastructure
-- TABLE: dynamic.real_time_payment_rails
--
-- DESCRIPTION:
--   Enterprise-grade real-time payment rail configuration.
--   FedNow, RTP, SARB PayShute, instant payment schemes.
--
-- COMPLIANCE: SARB, RTP, FedNow, ISO 20022, PCI DSS
-- ============================================================================


CREATE TABLE dynamic.real_time_payment_rails (
    rail_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rail Identification
    rail_code VARCHAR(100) NOT NULL,
    rail_name VARCHAR(200) NOT NULL,
    rail_type VARCHAR(50) NOT NULL 
        CHECK (rail_type IN ('FEDNOW', 'RTP', 'SARB_PAYSHUTTLE', 'FPS', 'UPI', 'QR_CODE', 'CBDC', 'STABLECOIN')),
    
    -- Scheme Configuration
    scheme_operator VARCHAR(100), -- 'Federal Reserve', 'The Clearing House', 'SARB'
    scheme_country CHAR(2) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    
    -- API/Connectivity
    api_endpoint TEXT NOT NULL,
    api_version VARCHAR(20),
    authentication_type VARCHAR(50) DEFAULT 'MUTUAL_TLS' 
        CHECK (authentication_type IN ('MUTUAL_TLS', 'OAUTH2', 'API_KEY', 'CERTIFICATE')),
    certificate_expiry DATE,
    
    -- Message Format
    message_format VARCHAR(50) DEFAULT 'ISO20022' 
        CHECK (message_format IN ('ISO20022', 'JSON', 'XML', 'CUSTOM')),
    
    -- Transaction Limits
    minimum_transaction_amount DECIMAL(28,8) DEFAULT 0.01,
    maximum_transaction_amount DECIMAL(28,8),
    daily_limit_per_account DECIMAL(28,8),
    
    -- Timing
    operating_hours VARCHAR(50) DEFAULT '24/7',
    settlement_cycle VARCHAR(20) DEFAULT 'REALTIME' 
        CHECK (settlement_cycle IN ('REALTIME', 'NET_END_OF_DAY', 'NET_MULTIPLE')),
    settlement_time_seconds INTEGER DEFAULT 10,
    
    -- Fees
    fee_type VARCHAR(20) DEFAULT 'FLAT' 
        CHECK (fee_type IN ('FLAT', 'PERCENTAGE', 'TIERED', 'ZERO')),
    fee_amount DECIMAL(28,8),
    fee_percentage DECIMAL(5,4),
    
    -- Risk Controls
    sanctions_screening_required BOOLEAN DEFAULT TRUE,
    velocity_check_enabled BOOLEAN DEFAULT TRUE,
    duplicate_check_window_seconds INTEGER DEFAULT 300,
    
    -- Status
    rail_status VARCHAR(20) DEFAULT 'ACTIVE' 
        CHECK (rail_status IN ('ACTIVE', 'MAINTENANCE', 'SUSPENDED', 'DECOMMISSIONED')),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_rail_code UNIQUE (tenant_id, rail_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.real_time_payment_rails_default PARTITION OF dynamic.real_time_payment_rails DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.real_time_payment_rails IS 'Real-time payment rail configuration - FedNow, RTP, PayShute, instant payments. Tier 2 - Payments Infrastructure.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.real_time_payment_rails TO finos_app;
