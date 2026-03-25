-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 47: Regulatory Identifiers
-- Table: uti_upi_registry
-- Description: Unique Trade Identifier (UTI) and Unique Product Identifier (UPI)
--              registry for EMIR, MiFID II, and SFTR reporting
-- Compliance: EMIR REFIT, MiFID II RTS 22, CFTC Part 43/45, SFTR
-- ================================================================================

CREATE TABLE dynamic.uti_upi_registry (
    -- Primary Identity
    identifier_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- UTI - Unique Trade Identifier
    uti VARCHAR(100) NOT NULL,
    uti_generation_method VARCHAR(50) NOT NULL CHECK (uti_generation_method IN (
        'COUNTERPARTY', 'BOTH', 'ENTITY_RESPONSIBLE', 'ALLOCATING', 'CONFIRMING'
    )),
    uti_generator_lei VARCHAR(20), -- LEI of entity that generated UTI
    
    -- UPI - Unique Product Identifier (when applicable)
    upi VARCHAR(100),
    upi_reference_database VARCHAR(100), -- ANNA DSB, CFTC, etc.
    
    -- Trade Reference
    trade_id UUID NOT NULL,
    trade_timestamp TIMESTAMPTZ NOT NULL,
    
    -- Reporting Obligation
    reporting_entity_lei VARCHAR(20) NOT NULL,
    reporting_counterparty_lei VARCHAR(20) NOT NULL,
    reporting_counterparty_role VARCHAR(50) CHECK (reporting_counterparty_role IN ('REPORTING', 'NON_REPORTING')),
    
    -- Regulation Context
    reporting_regulation VARCHAR(50) NOT NULL CHECK (reporting_regulation IN (
        'EMIR', 'EMIR_REFIT', 'MIFID_II', 'SFTR', 'CFTC', 'SEC', 'ASIC', 'JFSA', 'MAS'
    )),
    reporting_jurisdiction CHAR(2) NOT NULL,
    
    -- Trade Repository / ARM
    reporting_venue VARCHAR(100), -- Trade repository or ARM
    reporting_venue_trade_id VARCHAR(100), -- TR's internal trade ID
    
    -- Lifecycle Events
    action_type VARCHAR(50) NOT NULL DEFAULT 'NEW' CHECK (action_type IN (
        'NEW', 'MODIFY', 'CORRECT', 'CANCEL', 'TERMINATE', 'COMPRESS', 'GIVE_UP', 'TAKE_UP'
    )),
    event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    previous_uti_reference VARCHAR(100), -- For modifications/corrections
    
    -- Compression
    is_compressed BOOLEAN DEFAULT FALSE,
    compressed_from_utis JSONB, -- Array of UTIs included in compression
    compression_timestamp TIMESTAMPTZ,
    
    -- Validation
    validation_status VARCHAR(50) DEFAULT 'PENDING' CHECK (validation_status IN (
        'PENDING', 'VALIDATED', 'REJECTED', 'ACCEPTED', 'WARNING'
    )),
    validation_errors JSONB,
    
    -- Reporting Status
    report_submitted BOOLEAN DEFAULT FALSE,
    submitted_at TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ,
    rejection_reason TEXT,
    
    -- Partitioning
    partition_key DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_uti_per_regulation UNIQUE (tenant_id, uti, reporting_regulation)
) PARTITION BY RANGE (partition_key);

-- Default partition
CREATE TABLE dynamic.uti_upi_registry_default PARTITION OF dynamic.uti_upi_registry
    DEFAULT;

-- Monthly partitions
CREATE TABLE dynamic.uti_upi_registry_2025_01 PARTITION OF dynamic.uti_upi_registry
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.uti_upi_registry_2025_02 PARTITION OF dynamic.uti_upi_registry
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Indexes
CREATE INDEX idx_uti_upi_registry_uti ON dynamic.uti_upi_registry (tenant_id, uti);
CREATE INDEX idx_uti_upi_registry_trade ON dynamic.uti_upi_registry (tenant_id, trade_id);
CREATE INDEX idx_uti_upi_registry_regulation ON dynamic.uti_upi_registry (tenant_id, reporting_regulation);
CREATE INDEX idx_uti_upi_registry_action ON dynamic.uti_upi_registry (tenant_id, action_type, event_timestamp);
CREATE INDEX idx_uti_upi_registry_submitted ON dynamic.uti_upi_registry (tenant_id, report_submitted) WHERE report_submitted = FALSE;
CREATE INDEX idx_uti_upi_registry_validation ON dynamic.uti_upi_registry (tenant_id, validation_status);

-- Comments
COMMENT ON TABLE dynamic.uti_upi_registry IS 'UTI/UPI registry for EMIR, MiFID II, and SFTR trade reporting';
COMMENT ON COLUMN dynamic.uti_upi_registry.uti IS 'Unique Trade Identifier per ISO 23897';
COMMENT ON COLUMN dynamic.uti_upi_registry.upi IS 'Unique Product Identifier for derivatives (ISO 4914)';
COMMENT ON COLUMN dynamic.uti_upi_registry.action_type IS 'Lifecycle event: NEW, MODIFY, CORRECT, CANCEL, etc.';

-- RLS
ALTER TABLE dynamic.uti_upi_registry ENABLE ROW LEVEL SECURITY;
CREATE POLICY uti_upi_registry_tenant_isolation ON dynamic.uti_upi_registry
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.uti_upi_registry TO finos_app_user;
GRANT SELECT ON dynamic.uti_upi_registry TO finos_readonly_user;
