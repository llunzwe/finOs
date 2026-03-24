-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 3: SCRIPTED EXTENSIONS (SMART CONTRACTS)
-- ============================================================================
-- TABLE: dynamic_history.business_rule_execution_log
-- DESCRIPTION:
--   Enterprise-grade execution log for Business Rules.
-- COMPLIANCE: ISO 27001 (Sandboxing), SOX (Audit), GDPR (Data Protection)

-- TIER CLASSIFICATION:
--   Tier 3 - Pro-Code Extensions: Developer-only JavaScript, Lua, WASM scripts.
--   Requires coding expertise - managed through developer interfaces.
-- ============================================================================

CREATE TABLE dynamic_history.business_rule_execution_log (

    execution_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    rule_id UUID NOT NULL REFERENCES dynamic.business_rule_engine(rule_id),
    
    -- Execution Context
    context_entity_type VARCHAR(50),
    context_entity_id UUID,
    correlation_id UUID,
    
    -- Inputs
    input_data JSONB,
    
    -- Output
    rule_result BOOLEAN,
    output_data JSONB,
    
    -- Performance
    execution_start_time TIMESTAMPTZ NOT NULL,
    execution_end_time TIMESTAMPTZ,
    execution_duration_ms INTEGER,
    
    -- Status
    execution_status VARCHAR(20) DEFAULT 'SUCCESS' CHECK (execution_status IN ('SUCCESS', 'FAILED', 'TIMEOUT', 'ERROR')),
    error_message TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.business_rule_execution_log_default PARTITION OF dynamic_history.business_rule_execution_log DEFAULT;

COMMENT ON TABLE dynamic_history.business_rule_execution_log IS 'Business Rule Execution Log. Tier 3 - Scripted Extensions (Developer Only).';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.business_rule_execution_log TO finos_app;
