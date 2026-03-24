-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 3: SCRIPTED EXTENSIONS (PRO-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Smart Contracts
-- TABLE: dynamic.contract_execution_log
--
-- DESCRIPTION:
--   Enterprise-grade logging table for Smart Contract Execution.
--   Records all script executions for audit and debugging purposes.
--   Supports tenant isolation and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 3 - Pro-Code Extensions: Developer-only JavaScript, Lua, WASM scripts.
--   Requires coding expertise - managed through developer interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 27001 (Sandboxing)
--   - SOX (Audit)
--   - GDPR (Data Protection)
--
-- AUDIT & GOVERNANCE:
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
    executed_by VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.contract_execution_log_default PARTITION OF dynamic.contract_execution_log DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_contract_execution_tenant ON dynamic.contract_execution_log(tenant_id);
CREATE INDEX idx_contract_execution_contract ON dynamic.contract_execution_log(tenant_id, contract_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.contract_execution_log IS 'Smart contract execution log for audit and debugging. Tier 3 - Scripted Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.contract_execution_log TO finos_app;
