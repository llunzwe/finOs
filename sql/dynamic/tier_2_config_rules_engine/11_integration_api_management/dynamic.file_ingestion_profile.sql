-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 11 - Integration Api Management
-- TABLE: dynamic.file_ingestion_profile
-- COMPLIANCE: ISO 20022
--   - ISO 27001
--   - OpenAPI
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.file_ingestion_profile (

    profile_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    profile_name VARCHAR(200) NOT NULL,
    profile_description TEXT,
    
    -- File Format
    file_type dynamic.file_type NOT NULL,
    delimiter VARCHAR(10), -- For CSV
    text_qualifier VARCHAR(5),
    encoding VARCHAR(20) DEFAULT 'UTF-8',
    has_header BOOLEAN DEFAULT TRUE,
    
    -- Structure
    field_definitions JSONB NOT NULL, -- [{name: '...', type: '...', position: 1, length: 10}, ...]
    
    -- Validation
    validation_schema JSONB,
    pre_processing_rules JSONB,
    
    -- Processing
    post_processing_actions JSONB, -- [{action: 'ARCHIVE', location: '...'}, ...]
    target_table VARCHAR(100),
    upsert_key_columns TEXT[],
    
    -- Schedule
    ingestion_schedule VARCHAR(100), -- Cron expression
    source_location VARCHAR(500),
    
    -- Notifications
    success_notification_emails TEXT[],
    failure_notification_emails TEXT[],
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.file_ingestion_profile_default PARTITION OF dynamic.file_ingestion_profile DEFAULT;

-- Indexes
CREATE INDEX idx_file_profile_tenant ON dynamic.file_ingestion_profile(tenant_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.file_ingestion_profile IS 'Batch file specification and processing rules';

-- Triggers
CREATE TRIGGER trg_file_profile_audit
    BEFORE UPDATE ON dynamic.file_ingestion_profile
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.file_ingestion_profile TO finos_app;