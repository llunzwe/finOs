-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 11 - Integration Api Management
-- TABLE: dynamic_history.file_processing_log
-- COMPLIANCE: ISO 20022
--   - ISO 27001
--   - OpenAPI
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic_history.file_processing_log (

    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    profile_id UUID NOT NULL REFERENCES dynamic.file_ingestion_profile(profile_id),
    
    -- File Details
    filename VARCHAR(500) NOT NULL,
    file_size_bytes BIGINT,
    file_checksum VARCHAR(64),
    
    -- Processing
    record_count INTEGER,
    success_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    warning_count INTEGER DEFAULT 0,
    
    -- Timing
    processing_started_at TIMESTAMPTZ NOT NULL,
    processing_completed_at TIMESTAMPTZ,
    processing_duration_ms INTEGER,
    
    -- Status
    status VARCHAR(20) DEFAULT 'PROCESSING' 
        CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'PARTIAL')),
    
    -- Errors
    error_details JSONB,
    
    -- Storage
    archived_location VARCHAR(500),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.file_processing_log_default PARTITION OF dynamic_history.file_processing_log DEFAULT;

-- Indexes
CREATE INDEX idx_file_log_profile ON dynamic_history.file_processing_log(tenant_id, profile_id);
CREATE INDEX idx_file_log_status ON dynamic_history.file_processing_log(tenant_id, status);
CREATE INDEX idx_file_log_time ON dynamic_history.file_processing_log(processing_started_at DESC);

-- Comments
COMMENT ON TABLE dynamic_history.file_processing_log IS 'Batch file processing audit trail';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.file_processing_log TO finos_app;