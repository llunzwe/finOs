-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 11 - Integration Api Management
-- TABLE: dynamic_history.file_validation_error
-- COMPLIANCE: ISO 20022
--   - ISO 27001
--   - OpenAPI
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic_history.file_validation_error (

    error_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    log_id UUID NOT NULL REFERENCES dynamic_history.file_processing_log(log_id),
    
    -- Error Location
    row_number INTEGER,
    column_name VARCHAR(100),
    
    -- Error Details
    error_type VARCHAR(50) NOT NULL, -- FORMAT, VALIDATION, DUPLICATE, etc.
    error_message TEXT NOT NULL,
    error_value TEXT, -- The invalid value
    
    -- Data
    raw_data TEXT,
    
    -- Resolution
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMPTZ,
    resolved_by VARCHAR(100),
    resolution_action VARCHAR(50), -- CORRECTED, SKIPPED, REPROCESSED
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.file_validation_error_default PARTITION OF dynamic_history.file_validation_error DEFAULT;

-- Indexes
CREATE INDEX idx_file_error_log ON dynamic_history.file_validation_error(tenant_id, log_id);
CREATE INDEX idx_file_error_unresolved ON dynamic_history.file_validation_error(tenant_id, resolved) WHERE resolved = FALSE;

-- Comments
COMMENT ON TABLE dynamic_history.file_validation_error IS 'Individual record validation errors';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.file_validation_error TO finos_app;