-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 23 - Api Streaming Config
-- TABLE: dynamic.migration_validation_results
-- COMPLIANCE: OpenAPI
--   - OAuth 2.0
--   - ISO 20022
--   - GDPR
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

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.migration_validation_results_default PARTITION OF dynamic.migration_validation_results DEFAULT;

-- Indexes
CREATE INDEX idx_validation_results_config ON dynamic.migration_validation_results(tenant_id, config_id);

GRANT SELECT, INSERT, UPDATE ON dynamic.migration_validation_results TO finos_app;