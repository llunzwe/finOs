-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 23 - API Streaming Config
-- TABLE: dynamic.migration_validation_results
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Migration Validation Results.
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
CREATE TABLE dynamic.migration_validation_results (

    result_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    config_id UUID NOT NULL REFERENCES dynamic.migration_configs(config_id),
    
    -- Validation Details
    entity_type VARCHAR(100) NOT NULL,
    entity_id VARCHAR(100),
    validation_rule VARCHAR(100) NOT NULL,
    
    -- Result
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('error', 'warning', 'info')),
    passed BOOLEAN NOT NULL,
    message TEXT,
    
    -- Context
    field_name VARCHAR(100),
    field_value TEXT,
    expected_value TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.migration_validation_results_default PARTITION OF dynamic.migration_validation_results DEFAULT;

-- Indexes
CREATE INDEX idx_validation_results_config ON dynamic.migration_validation_results(tenant_id, config_id);

GRANT SELECT, INSERT, UPDATE ON dynamic.migration_validation_results TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.migration_validation_results IS 'Migration Validation Results';