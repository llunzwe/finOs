-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 19 - Kernel Wiring
-- TABLE: dynamic.trigger_configurations
--
-- DESCRIPTION:
--   Database trigger configuration UI table.
--   Configures audit, validation, and business rule triggers.
--
-- CORE DEPENDENCY: 019_kernel_wiring.sql
--
-- ============================================================================

CREATE TABLE dynamic.trigger_configurations (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Trigger Identification
    trigger_code VARCHAR(100) NOT NULL,
    trigger_name VARCHAR(200) NOT NULL,
    trigger_description TEXT,
    
    -- Target
    target_schema VARCHAR(100) NOT NULL,
    target_table VARCHAR(100) NOT NULL,
    
    -- Trigger Specs
    trigger_timing VARCHAR(20) NOT NULL, -- BEFORE, AFTER, INSTEAD OF
    trigger_events VARCHAR(20)[] NOT NULL, -- INSERT, UPDATE, DELETE
    trigger_when TEXT, -- Optional WHEN clause
    
    -- Trigger Logic
    trigger_function VARCHAR(200) NOT NULL, -- Function to execute
    function_parameters JSONB, -- Parameters to pass to function
    execution_order INTEGER DEFAULT 100, -- Lower = earlier execution
    
    -- Conditions
    condition_expression TEXT, -- SQL expression that must be true
    skip_if_replica BOOLEAN DEFAULT TRUE, -- Skip on read replicas
    
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
    
    CONSTRAINT unique_trigger_config_code UNIQUE (tenant_id, trigger_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.trigger_configurations_default PARTITION OF dynamic.trigger_configurations DEFAULT;

CREATE INDEX idx_trigger_config_target ON dynamic.trigger_configurations(tenant_id, target_schema, target_table) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.trigger_configurations IS 'Database trigger configuration for audit and business rules. Tier 2 Low-Code';

CREATE TRIGGER trg_trigger_configurations_audit
    BEFORE UPDATE ON dynamic.trigger_configurations
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.trigger_configurations TO finos_app;
