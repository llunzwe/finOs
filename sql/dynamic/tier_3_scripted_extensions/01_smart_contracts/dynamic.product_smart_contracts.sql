-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 3: SCRIPTED EXTENSIONS (SMART CONTRACTS)
-- ============================================================================
-- TABLE: dynamic.product_smart_contracts
-- DESCRIPTION: Product Smart Contracts
-- COMPLIANCE: ISO 27001 (Sandboxing), SOX (Audit), GDPR (Data Protection)
-- TIER: 3 - Developer-Only (JavaScript, Lua, WASM scripts)
-- ============================================================================

CREATE TABLE dynamic.product_smart_contracts (

    contract_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Contract Identity
    contract_name VARCHAR(200) NOT NULL,
    contract_version VARCHAR(20) NOT NULL DEFAULT '1.0.0',
    
    -- Execution Language
    language VARCHAR(20) NOT NULL DEFAULT 'WASM'
        CHECK (language IN ('WASM', 'LUA', 'JAVASCRIPT', 'PYTHON', 'SOLIDITY', 'MOVE', 'JSON_LOGIC')),
    
    -- Entry Points (JSON Schema for contract interface)
    entry_points JSONB NOT NULL DEFAULT '[]', -- [{name: 'onDebit', params: [...]}, ...]
    
    -- Parameters Schema (JSON Schema for validation)
    parameters_schema JSONB NOT NULL DEFAULT '{}',
    parameters_ui_schema JSONB DEFAULT '{}', -- UI rendering hints
    
    -- Contract Code
    source_code TEXT, -- Human-readable source
    compiled_bytecode BYTEA, -- Compiled WASM/bytecode
    source_hash VARCHAR(64), -- SHA-256 of source for verification
    
    -- Version Hash (links to core anchor)
    version_hash UUID REFERENCES core.product_contract_anchors(contract_hash),
    
    -- Execution Context
    max_execution_time_ms INTEGER DEFAULT 1000,
    max_memory_mb INTEGER DEFAULT 64,
    allowed_host_functions TEXT[] DEFAULT ARRAY['log', 'emit', 'math'],
    
    -- Status
    contract_status VARCHAR(20) DEFAULT 'draft' 
        CHECK (contract_status IN ('draft', 'testing', 'verified', 'active', 'deprecated')),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_contract_name_version UNIQUE (tenant_id, contract_name, contract_version)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_smart_contracts_default PARTITION OF dynamic.product_smart_contracts DEFAULT;

COMMENT ON TABLE dynamic.product_smart_contracts IS 'Product Smart Contracts. Tier 3 - Scripted Extensions (Developer Only).';

GRANT SELECT, INSERT, UPDATE ON dynamic.product_smart_contracts TO finos_app;
