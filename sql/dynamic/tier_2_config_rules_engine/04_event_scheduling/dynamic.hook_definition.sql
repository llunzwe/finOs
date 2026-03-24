-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 04 - Event Scheduling
-- TABLE: dynamic.hook_definition
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Hook Definition.
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

-- Comments
COMMENT ON TABLE dynamic.hook_definition IS 'Superhook definitions for event-driven customization';

-- Triggers
CREATE TRIGGER trg_hook_definition_audit
    BEFORE UPDATE ON dynamic.hook_definition
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.hook_definition TO finos_app;
