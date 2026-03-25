-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 47: Regulatory Identifiers
-- Table: regulatory_data_lineage
-- Description: Data lineage tracking for regulatory reports - source systems,
--              transformations, and audit trail for data quality investigations
-- Compliance: BCBS 239, Data Quality Management, Regulatory Audit
-- ================================================================================

CREATE TABLE dynamic.regulatory_data_lineage (
    -- Primary Identity
    lineage_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Report Reference
    report_id UUID NOT NULL,
    report_type VARCHAR(100) NOT NULL,
    reporting_regulation VARCHAR(50) NOT NULL,
    reporting_period DATE NOT NULL,
    
    -- Data Element
    data_element_name VARCHAR(200) NOT NULL, -- Field name in report
    data_element_path VARCHAR(500), -- JSON path or field hierarchy
    
    -- Source Information
    source_system VARCHAR(100) NOT NULL,
    source_table VARCHAR(200),
    source_column VARCHAR(200),
    source_record_id VARCHAR(100), -- Primary key of source record
    source_timestamp TIMESTAMPTZ,
    
    -- Transformation Chain
    transformations JSONB NOT NULL,
    -- Example:
    -- [
    --   {"step": 1, "type": "AGGREGATION", "description": "Sum of trades"},
    --   {"step": 2, "type": "CONVERSION", "description": "USD to EUR conversion"},
    --   {"step": 3, "type": "DERIVATION", "description": "Notional calculation"}
    -- ]
    
    -- Data Quality
    quality_score DECIMAL(3,2), -- 0.00 to 1.00
    quality_checks JSONB, -- Array of validation results
    
    -- Lineage Metadata
    extraction_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    lineage_version VARCHAR(20) DEFAULT '1.0',
    
    -- Business Context
    business_definition TEXT,
    calculation_logic TEXT,
    
    -- Partitioning
    partition_key DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY RANGE (partition_key);

-- Default partition
CREATE TABLE dynamic.regulatory_data_lineage_default PARTITION OF dynamic.regulatory_data_lineage
    DEFAULT;

-- Monthly partitions
CREATE TABLE dynamic.regulatory_data_lineage_2025_01 PARTITION OF dynamic.regulatory_data_lineage
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.regulatory_data_lineage_2025_02 PARTITION OF dynamic.regulatory_data_lineage
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Indexes
CREATE INDEX idx_regulatory_lineage_report ON dynamic.regulatory_data_lineage (tenant_id, report_id);
CREATE INDEX idx_regulatory_lineage_element ON dynamic.regulatory_data_lineage (tenant_id, data_element_name);
CREATE INDEX idx_regulatory_lineage_source ON dynamic.regulatory_data_lineage (tenant_id, source_system);
CREATE INDEX idx_regulatory_lineage_period ON dynamic.regulatory_data_lineage (tenant_id, reporting_period);

-- Comments
COMMENT ON TABLE dynamic.regulatory_data_lineage IS 'Data lineage tracking for regulatory reports - BCBS 239 compliance';
COMMENT ON COLUMN dynamic.regulatory_data_lineage.transformations IS 'JSON array documenting all transformations applied to data element';

-- RLS
ALTER TABLE dynamic.regulatory_data_lineage ENABLE ROW LEVEL SECURITY;
CREATE POLICY regulatory_data_lineage_tenant_isolation ON dynamic.regulatory_data_lineage
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT ON dynamic.regulatory_data_lineage TO finos_app_user;
GRANT SELECT ON dynamic.regulatory_data_lineage TO finos_readonly_user;
