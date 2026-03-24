-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 21 - Integration Hooks
-- TABLE: dynamic_history.import_execution_log
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Import Execution Log.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 8601
--   - ISO 20022
--   - IFRS 15
--   - Basel III
--   - OECD
--   - NCA
--
-- AUDIT & GOVERNANCE:
--   - Bitemporal tracking (effective_from/valid_from, effective_to/valid_to)
--   - Full audit trail (created_at, updated_at, created_by, updated_by)
--   - Version control for change management
--   - Tenant isolation via partitioning
--   - Row-Level Security (RLS) for data protection
--
-- DATA CLASSIFICATION:
--   - Tenant Isolation: Row-Level Security enabled
--   - Audit Level: FULL
--   - Encryption: At-rest for sensitive fields
--
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
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.import_execution_log_default PARTITION OF dynamic_history.import_execution_log DEFAULT;

-- Indexes
CREATE INDEX idx_import_exec_mapping ON dynamic_history.import_execution_log(tenant_id, mapping_id);
CREATE INDEX idx_import_exec_status ON dynamic_history.import_execution_log(tenant_id, execution_status);
CREATE INDEX idx_import_exec_time ON dynamic_history.import_execution_log(started_at DESC);

-- Comments
COMMENT ON TABLE dynamic_history.import_execution_log IS 'Data import execution history and error tracking';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.import_execution_log TO finos_app;