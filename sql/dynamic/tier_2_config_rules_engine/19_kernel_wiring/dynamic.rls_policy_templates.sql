-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 19 - Kernel Wiring
-- TABLE: dynamic.rls_policy_templates
--
-- DESCRIPTION:
--   Row-Level Security policy templates.
--   Configures RLS policies for multi-tenant data isolation.
--
-- CORE DEPENDENCY: 019_kernel_wiring.sql
--
-- ============================================================================

CREATE TABLE dynamic.rls_policy_templates (
    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Template Identification
    template_code VARCHAR(100) NOT NULL,
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    
    -- Target
    target_schema VARCHAR(100) NOT NULL, -- 'core', 'dynamic'
    target_table VARCHAR(100) NOT NULL,
    
    -- RLS Configuration
    policy_name VARCHAR(100) NOT NULL,
    policy_type VARCHAR(50) DEFAULT 'SELECT', -- SELECT, INSERT, UPDATE, DELETE, ALL
    using_expression TEXT NOT NULL, -- RLS USING clause
    with_check_expression TEXT, -- RLS WITH CHECK clause for INSERT/UPDATE
    
    -- Roles
    applies_to_roles VARCHAR(100)[], -- Roles this policy applies to
    exempt_roles VARCHAR(100)[], -- Roles exempt from this policy (e.g., admin)
    
    -- Tenant Isolation
    tenant_isolation_column VARCHAR(100) DEFAULT 'tenant_id',
    enable_tenant_isolation BOOLEAN DEFAULT TRUE,
    
    -- Additional Filters
    additional_filters JSONB, -- Additional WHERE conditions
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_system_defined BOOLEAN DEFAULT FALSE,
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_rls_template_code UNIQUE (tenant_id, template_code),
    CONSTRAINT unique_rls_policy_target UNIQUE (tenant_id, target_schema, target_table, policy_name)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.rls_policy_templates_default PARTITION OF dynamic.rls_policy_templates DEFAULT;

CREATE INDEX idx_rls_template_target ON dynamic.rls_policy_templates(tenant_id, target_schema, target_table) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.rls_policy_templates IS 'Row-Level Security policy templates for multi-tenant data isolation. Tier 2 Low-Code';

CREATE TRIGGER trg_rls_policy_templates_audit
    BEFORE UPDATE ON dynamic.rls_policy_templates
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.rls_policy_templates TO finos_app;
