-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 3: SCRIPTED EXTENSIONS (SMART CONTRACTS)
-- ============================================================================
-- TABLE: dynamic.hook_definition
-- DESCRIPTION:
--   Enterprise-grade configuration table for Hook Definitions. - Sandboxed scripts
-- COMPLIANCE: ISO 27001 (Sandboxing), SOX (Audit), GDPR (Data Protection)

-- TIER CLASSIFICATION:
--   Tier 3 - Pro-Code Extensions: Developer-only JavaScript, Lua, WASM scripts.
--   Requires coding expertise - managed through developer interfaces.
-- ============================================================================

CREATE TABLE dynamic.hook_definition (

    hook_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    hook_name VARCHAR(200) NOT NULL,
    hook_code VARCHAR(100) NOT NULL,
    hook_description TEXT,
    
    -- Trigger Scope
    trigger_scope dynamic.hook_scope DEFAULT 'GLOBAL',
    trigger_event VARCHAR(100) NOT NULL, -- VALUE_MOVEMENT_CREATED, EOD_BATCH, etc.
    
    -- Target Scope (if not GLOBAL)
    specific_product_id UUID REFERENCES dynamic.product_template_master(product_id),
    specific_entity_type VARCHAR(50),
    
    -- Execution
    execution_order INTEGER DEFAULT 0,
    parallelizable BOOLEAN DEFAULT FALSE,
    continue_on_failure BOOLEAN DEFAULT TRUE,
    
    -- Script
    script_language dynamic.script_language NOT NULL DEFAULT 'PYTHON',
    script_code TEXT NOT NULL,
    script_version INTEGER DEFAULT 1,
    
    -- Sandbox Limits
    timeout_seconds INTEGER DEFAULT 30,
    memory_mb INTEGER DEFAULT 128,
    allowed_imports TEXT[],
    blocked_operations TEXT[],
    
    -- Return Type
    return_schema JSONB,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_hook_code_per_tenant UNIQUE (tenant_id, hook_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.hook_definition_default PARTITION OF dynamic.hook_definition DEFAULT;

COMMENT ON TABLE dynamic.hook_definition IS 'Hook Definition - Sandboxed scripts. Tier 3 - Scripted Extensions (Developer Only).';

GRANT SELECT, INSERT, UPDATE ON dynamic.hook_definition TO finos_app;
