-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 46: Counterparty & Credit Management
-- Table: counterparty_master
-- Description: Counterparty master data with LEI integration, entity hierarchy,
--              and relationship management for credit risk
-- Compliance: Basel III/IV, EMIR, MiFID II LEI Requirements, KYC
-- ================================================================================

CREATE TABLE dynamic.counterparty_master (
    -- Primary Identity
    counterparty_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Legal Entity Identifier (Critical for regulatory reporting)
    lei_code VARCHAR(20),
    lei_validation_status VARCHAR(50) CHECK (lei_validation_status IN ('VALID', 'INVALID', 'PENDING', 'EXPIRED', 'LAPSED')),
    lei_registration_date DATE,
    lei_last_verified_at TIMESTAMPTZ,
    
    -- Entity Names
    legal_entity_name VARCHAR(500) NOT NULL,
    short_name VARCHAR(200),
    trading_name VARCHAR(500),
    previous_names JSONB, -- Historical name changes
    
    -- Legal Details
    legal_form VARCHAR(100),
    jurisdiction_code CHAR(2) NOT NULL, -- ISO country code
    registration_number VARCHAR(100),
    registration_authority VARCHAR(200),
    tax_id VARCHAR(100),
    tax_country CHAR(2),
    
    -- Entity Hierarchy
    parent_entity_id UUID REFERENCES dynamic.counterparty_master(counterparty_id),
    ultimate_parent_id UUID REFERENCES dynamic.counterparty_master(counterparty_id),
    entity_level VARCHAR(50) CHECK (entity_level IN ('HEADQUARTERS', 'BRANCH', 'SUBSIDIARY', 'AFFILIATE', 'FUND')),
    consolidation_scope BOOLEAN DEFAULT TRUE, -- Include in consolidated exposure?
    
    -- Classification
    sector_code VARCHAR(50), -- NACE, NAICS, GICS
    sector_classification VARCHAR(100),
    industry_group VARCHAR(100),
    
    -- Counterparty Type
    counterparty_type VARCHAR(50) NOT NULL CHECK (counterparty_type IN (
        'BANK', 'BROKER_DEALER', 'INSURANCE', 'ASSET_MANAGER', 'CORPORATE',
        'SOVEREIGN', 'MUNICIPAL', 'SUPRANATIONAL', 'RETAIL', 'PENSION_FUND',
        'HEDGE_FUND', 'PRIVATE_EQUITY', 'SPV', 'INDIVIDUAL'
    )),
    financial_entity BOOLEAN DEFAULT FALSE, -- EMIR financial entity flag
    
    -- Systemic Importance
    sifi_classification VARCHAR(50) CHECK (sifi_classification IN ('G_SIB', 'D_SIB', 'NONE')),
    
    -- Address
    registered_address JSONB, -- Structured address
    headquarters_address JSONB,
    primary_operating_address JSONB,
    
    -- Contact
    primary_contact_name VARCHAR(200),
    primary_contact_email VARCHAR(255),
    primary_contact_phone VARCHAR(50),
    
    -- Status
    entity_status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (entity_status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'LIQUIDATED', 'MERGED')),
    onboarding_date DATE,
    offboarding_date DATE,
    offboarding_reason TEXT,
    
    -- KYC Status
    kyc_status VARCHAR(50) DEFAULT 'PENDING' CHECK (kyc_status IN ('PENDING', 'IN_PROGRESS', 'APPROVED', 'REJECTED', 'SUSPENDED')),
    kyc_renewal_date DATE,
    kyc_risk_rating VARCHAR(20) CHECK (kyc_risk_rating IN ('LOW', 'MEDIUM', 'HIGH', 'PROHIBITED')),
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31',
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_lei_per_tenant UNIQUE (tenant_id, lei_code) WHERE lei_code IS NOT NULL,
    CONSTRAINT valid_counterparty_dates CHECK (valid_from < valid_to)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE dynamic.counterparty_master_default PARTITION OF dynamic.counterparty_master
    DEFAULT;

-- Indexes
CREATE INDEX idx_counterparty_master_lei ON dynamic.counterparty_master (tenant_id, lei_code) WHERE lei_code IS NOT NULL;
CREATE INDEX idx_counterparty_master_name ON dynamic.counterparty_master (tenant_id, legal_entity_name);
CREATE INDEX idx_counterparty_master_type ON dynamic.counterparty_master (tenant_id, counterparty_type);
CREATE INDEX idx_counterparty_master_parent ON dynamic.counterparty_master (tenant_id, parent_entity_id);
CREATE INDEX idx_counterparty_master_ultimate ON dynamic.counterparty_master (tenant_id, ultimate_parent_id);
CREATE INDEX idx_counterparty_master_kyc ON dynamic.counterparty_master (tenant_id, kyc_status, kyc_risk_rating);
CREATE INDEX idx_counterparty_master_current ON dynamic.counterparty_master (tenant_id, lei_code) WHERE is_current = TRUE;

-- Comments
COMMENT ON TABLE dynamic.counterparty_master IS 'Counterparty master data with LEI integration and entity hierarchy';
COMMENT ON COLUMN dynamic.counterparty_master.lei_code IS 'ISO 17442 Legal Entity Identifier (20-character code)';
COMMENT ON COLUMN dynamic.counterparty_master.consolidation_scope IS 'Include entity in consolidated exposure calculations for Basel';

-- RLS
ALTER TABLE dynamic.counterparty_master ENABLE ROW LEVEL SECURITY;
CREATE POLICY counterparty_master_tenant_isolation ON dynamic.counterparty_master
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.counterparty_master TO finos_app_user;
GRANT SELECT ON dynamic.counterparty_master TO finos_readonly_user;
