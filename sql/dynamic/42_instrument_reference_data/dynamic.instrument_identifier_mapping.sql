-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 42: Instrument Reference Data Management
-- Table: instrument_identifier_mapping
-- Description: Multi-venue identifier reconciliation - ISIN, CUSIP, SEDOL, FIGI, RIC
--              mapping with temporal validity and source attribution
-- Compliance: MiFID II, SFTR, Best Execution
-- ================================================================================

CREATE TABLE dynamic.instrument_identifier_mapping (
    -- Primary Identity
    mapping_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Instrument Reference
    instrument_id UUID NOT NULL REFERENCES dynamic.securities_master(security_id),
    
    -- Identifier Details
    identifier_scheme VARCHAR(50) NOT NULL CHECK (identifier_scheme IN (
        'ISIN', 'CUSIP', 'SEDOL', 'WKN', 'VALOR', 'FIGI', 'RIC', 'BLOOMBERG_TICKER',
        'REUTERS_RIC', 'TRADEWEB_ID', 'MARKIT_AXES', 'CLEARSTREAM_ID', 'EUROCLEAR_ID',
        'DTCC_ID', 'LCH_ID', 'CME_ID', 'ICE_ID', 'INTERNAL'
    )),
    identifier_value VARCHAR(100) NOT NULL,
    identifier_country_code CHAR(2), -- ISO country for ISIN prefix, etc.
    
    -- Source Attribution
    primary_source VARCHAR(100) NOT NULL, -- Bloomberg, Refinitiv, Markit, Internal
    secondary_source VARCHAR(100),
    data_quality_score DECIMAL(3,2), -- 0.00 to 1.00
    
    -- Identifier Status
    identifier_status VARCHAR(50) DEFAULT 'ACTIVE' CHECK (identifier_status IN ('ACTIVE', 'INACTIVE', 'PENDING', 'SUSPENDED', 'EXPIRED')),
    
    -- Bitemporal Validity (Critical for identifier changes over time)
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31',
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Cross-Reference Mapping
    canonical_identifier BOOLEAN DEFAULT FALSE, -- Primary identifier for the instrument
    mapping_confidence VARCHAR(20) CHECK (mapping_confidence IN ('EXACT', 'PROBABLE', 'POSSIBLE', 'MANUAL')),
    
    -- Verification
    verified_at TIMESTAMPTZ,
    verified_by VARCHAR(100),
    verification_method VARCHAR(100),
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_identifier_per_scheme UNIQUE (tenant_id, identifier_scheme, identifier_value, valid_from),
    CONSTRAINT valid_identifier_dates CHECK (valid_from < valid_to),
    CONSTRAINT valid_quality_score CHECK (data_quality_score >= 0 AND data_quality_score <= 1)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE dynamic.instrument_identifier_mapping_default PARTITION OF dynamic.instrument_identifier_mapping
    DEFAULT;

-- Indexes
CREATE INDEX idx_instrument_identifier_mapping_instrument ON dynamic.instrument_identifier_mapping (tenant_id, instrument_id);
CREATE INDEX idx_instrument_identifier_mapping_scheme ON dynamic.instrument_identifier_mapping (tenant_id, identifier_scheme, identifier_value);
CREATE UNIQUE INDEX idx_instrument_identifier_mapping_canonical ON dynamic.instrument_identifier_mapping (tenant_id, instrument_id, identifier_scheme) 
    WHERE canonical_identifier = TRUE AND is_current = TRUE;
CREATE INDEX idx_instrument_identifier_mapping_status ON dynamic.instrument_identifier_mapping (tenant_id, identifier_status);
CREATE INDEX idx_instrument_identifier_mapping_current ON dynamic.instrument_identifier_mapping (tenant_id, instrument_id, identifier_scheme) 
    WHERE is_current = TRUE;

-- Comments
COMMENT ON TABLE dynamic.instrument_identifier_mapping IS 'Multi-venue identifier reconciliation - ISIN, CUSIP, SEDOL, FIGI, RIC mapping';
COMMENT ON COLUMN dynamic.instrument_identifier_mapping.canonical_identifier IS 'Primary identifier for the instrument within this scheme';
COMMENT ON COLUMN dynamic.instrument_identifier_mapping.mapping_confidence IS 'Confidence level in the cross-reference mapping';

-- RLS
ALTER TABLE dynamic.instrument_identifier_mapping ENABLE ROW LEVEL SECURITY;
CREATE POLICY instrument_identifier_mapping_tenant_isolation ON dynamic.instrument_identifier_mapping
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.instrument_identifier_mapping TO finos_app_user;
GRANT SELECT ON dynamic.instrument_identifier_mapping TO finos_readonly_user;
