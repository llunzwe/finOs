-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 3: SCRIPTED EXTENSIONS (SMART CONTRACTS)
-- ============================================================================
-- TABLE: dynamic.contract_execution_log
-- DESCRIPTION: Contract Execution Log
-- COMPLIANCE: ISO 27001 (Sandboxing), SOX (Audit), GDPR (Data Protection)
-- TIER: 3 - Developer-Only (JavaScript, Lua, WASM scripts)
-- ============================================================================

CREATE TABLE dynamic.contract_execution_log (

    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    contract_id UUID NOT NULL REFERENCES dynamic.product_smart_contracts(contract_id),
    
    -- Execution Context
    entry_point VARCHAR(100) NOT NULL,
    input_params JSONB NOT NULL,
    
    -- Execution Results
    execution_status VARCHAR(20) NOT NULL 
        CHECK (execution_status IN ('success', 'error', 'timeout', 'rejected')),
    output_result JSONB,
    error_message TEXT,
    
    -- Performance
    execution_time_ms INTEGER,
    memory_used_kb INTEGER,
    
    -- Linked Transaction
    movement_id UUID REFERENCES core.value_movements(id),
    posting_id UUID REFERENCES core.real_time_postings(id),
    
    -- Audit
    executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    executed_by VARCHAR(100)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.contract_execution_log_default PARTITION OF dynamic.contract_execution_log DEFAULT;

COMMENT ON TABLE dynamic.contract_execution_log IS 'Contract Execution Log. Tier 3 - Scripted Extensions (Developer Only).';

GRANT SELECT, INSERT, UPDATE ON dynamic.contract_execution_log TO finos_app;
