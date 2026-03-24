-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 21 - Integration Hooks
-- TABLE: dynamic_history.import_execution_log
-- COMPLIANCE: ISO 20022
--   - ISO 27001
--   - GDPR
--   - SOX
-- ============================================================================


CREATE TABLE dynamic_history.import_execution_log (

    execution_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    mapping_id UUID NOT NULL REFERENCES dynamic.data_import_mappings(mapping_id),
    
    -- File Details
    source_filename VARCHAR(500),
    source_file_size_bytes BIGINT,
    source_file_checksum VARCHAR(64),
    
    -- Execution
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    duration_ms INTEGER,
    
    -- Statistics
    total_rows INTEGER,
    processed_rows INTEGER,
    inserted_rows INTEGER DEFAULT 0,
    updated_rows INTEGER DEFAULT 0,
    skipped_rows INTEGER DEFAULT 0,
    error_rows INTEGER DEFAULT 0,
    
    -- Status
    execution_status VARCHAR(20) NOT NULL 
        CHECK (execution_status IN ('RUNNING', 'COMPLETED', 'FAILED', 'PARTIAL', 'CANCELLED')),
    
    -- Errors
    error_details JSONB, -- [{row_number: 5, error: 'Invalid email'}]
    error_file_location VARCHAR(500), -- Path to error report
    
    -- Output
    output_file_location VARCHAR(500),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.import_execution_log_default PARTITION OF dynamic_history.import_execution_log DEFAULT;

-- Indexes
CREATE INDEX idx_import_exec_mapping ON dynamic_history.import_execution_log(tenant_id, mapping_id);
CREATE INDEX idx_import_exec_status ON dynamic_history.import_execution_log(tenant_id, execution_status);
CREATE INDEX idx_import_exec_time ON dynamic_history.import_execution_log(started_at DESC);

-- Comments
COMMENT ON TABLE dynamic_history.import_execution_log IS 'Data import execution history and error tracking';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.import_execution_log TO finos_app;