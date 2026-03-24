-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 21 - Integration Hooks
-- TABLE: dynamic.data_import_mappings
-- COMPLIANCE: ISO 20022
--   - ISO 27001
--   - GDPR
--   - SOX
-- ============================================================================


CREATE TABLE dynamic.data_import_mappings (

    mapping_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    mapping_code VARCHAR(100) NOT NULL,
    mapping_name VARCHAR(200) NOT NULL,
    mapping_description TEXT,
    
    -- Source Format
    source_format VARCHAR(50) NOT NULL 
        CHECK (source_format IN ('CSV', 'JSON', 'XML', 'EXCEL', 'FIXED_WIDTH', 'PARQUET')),
    source_format_version VARCHAR(20),
    
    -- File Configuration
    file_config JSONB, -- {delimiter: ',', encoding: 'UTF-8', has_header: true, ...}
    
    -- Target
    target_table VARCHAR(200) NOT NULL,
    target_schema VARCHAR(100) DEFAULT 'dynamic',
    
    -- Field Mappings
    field_mappings JSONB NOT NULL, -- [{source_field: 'Customer Name', target_field: 'customer_name', transform: 'UPPER_CASE'}, ...]
    
    -- Transformations
    transformations JSONB, -- [{field: 'amount', operation: 'MULTIPLY', value: 100}, ...]
    
    -- Validation
    validation_rules JSONB, -- [{field: 'email', rule: 'EMAIL_FORMAT'}, {field: 'amount', rule: 'POSITIVE_NUMBER'}]
    skip_invalid_rows BOOLEAN DEFAULT FALSE,
    max_errors_allowed INTEGER DEFAULT 100,
    
    -- Processing
    batch_size INTEGER DEFAULT 1000,
    upsert_key_fields VARCHAR(100)[], -- For upsert operations
    pre_processing_sql TEXT,
    post_processing_sql TEXT,
    
    -- Schedule
    scheduled_import BOOLEAN DEFAULT FALSE,
    import_schedule_cron VARCHAR(100),
    source_location VARCHAR(500), -- URL or path pattern
    
    -- Notifications
    notify_on_success BOOLEAN DEFAULT TRUE,
    notify_on_failure BOOLEAN DEFAULT TRUE,
    notification_recipients TEXT[],
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    last_import_at TIMESTAMPTZ,
    last_import_status VARCHAR(20),
    last_import_records INTEGER,
    last_import_errors INTEGER,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_import_mapping_code UNIQUE (tenant_id, mapping_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.data_import_mappings_default PARTITION OF dynamic.data_import_mappings DEFAULT;

-- Indexes
CREATE INDEX idx_import_mappings_tenant ON dynamic.data_import_mappings(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_import_mappings_format ON dynamic.data_import_mappings(tenant_id, source_format) WHERE is_active = TRUE;
CREATE INDEX idx_import_mappings_target ON dynamic.data_import_mappings(tenant_id, target_table) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.data_import_mappings IS 'CSV/JSON/Excel import templates with field mapping';

-- Triggers
CREATE TRIGGER trg_data_import_mappings_audit
    BEFORE UPDATE ON dynamic.data_import_mappings
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.data_import_mappings TO finos_app;