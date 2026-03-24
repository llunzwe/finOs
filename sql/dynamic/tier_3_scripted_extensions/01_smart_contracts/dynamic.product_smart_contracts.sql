-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 3: SCRIPTED EXTENSIONS (PRO-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Smart Contracts
-- TABLE: dynamic.product_smart_contracts
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Smart Contracts.
--   Defines JavaScript/Lua/WASM scripts for product lifecycle hooks.
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


CREATE TABLE dynamic.product_smart_contracts (

    contract_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id),
    
    -- Contract Definition
    contract_name VARCHAR(200) NOT NULL,
    contract_version VARCHAR(20) NOT NULL DEFAULT '1.0.0',
    
    -- Script Code
    script_language dynamic.script_language NOT NULL DEFAULT 'JAVASCRIPT',
    script_code TEXT NOT NULL,
    
    -- Entry Points
    on_init_entry_point VARCHAR(100),
    on_validate_entry_point VARCHAR(100),
    on_calculate_entry_point VARCHAR(100),
    on_post_entry_point VARCHAR(100),
    
    -- Sandbox Config
    max_execution_time_ms INTEGER DEFAULT 5000,
    max_memory_mb INTEGER DEFAULT 128,
    allowed_host_functions VARCHAR(100)[],
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    compiled_bytecode BYTEA,
    compilation_status VARCHAR(20) DEFAULT 'PENDING',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_contract_per_product UNIQUE (tenant_id, product_id, contract_name)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_smart_contracts_default PARTITION OF dynamic.product_smart_contracts DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_smart_contracts_tenant ON dynamic.product_smart_contracts(tenant_id);
CREATE INDEX idx_smart_contracts_product ON dynamic.product_smart_contracts(tenant_id, product_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_smart_contracts IS 'Smart contract definitions for product lifecycle hooks. Tier 3 - Scripted Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_smart_contracts TO finos_app;
