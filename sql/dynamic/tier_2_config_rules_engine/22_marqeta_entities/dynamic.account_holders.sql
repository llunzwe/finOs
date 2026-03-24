-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.account_holders
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.account_holders (

    holder_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identity
    holder_type VARCHAR(20) NOT NULL 
        CHECK (holder_type IN ('individual', 'business')),
    external_id VARCHAR(100), -- Reference to external system
    
    -- Personal/Business Details
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    business_name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(50),
    
    -- Address
    address_1 VARCHAR(255),
    address_2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country CHAR(2),
    
    -- Identification
    id_type VARCHAR(50), -- passport, national_id, business_reg
    id_number VARCHAR(100),
    id_expiry_date DATE,
    tax_id VARCHAR(50),
    
    -- Status
    status VARCHAR(20) DEFAULT 'ACTIVE' 
        CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'CLOSED')),
    status_reason TEXT,
    
    -- KYC
    kyc_status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (kyc_status IN ('PENDING', 'VERIFIED', 'FAILED', 'RESTRICTED')),
    kyc_verified_at TIMESTAMPTZ,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    tags TEXT[],
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.account_holders_default PARTITION OF dynamic.account_holders DEFAULT;

-- Indexes
CREATE INDEX idx_account_holders_tenant ON dynamic.account_holders(tenant_id, status) WHERE status = 'ACTIVE';
CREATE INDEX idx_account_holders_external ON dynamic.account_holders(tenant_id, external_id);
CREATE INDEX idx_account_holders_kyc ON dynamic.account_holders(tenant_id, kyc_status);

-- Comments
COMMENT ON TABLE dynamic.account_holders IS 'Account holders - users and businesses (Marqeta-style)';

-- Triggers
CREATE TRIGGER trg_account_holders_update
    BEFORE UPDATE ON dynamic.account_holders
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_marqeta_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.account_holders TO finos_app;