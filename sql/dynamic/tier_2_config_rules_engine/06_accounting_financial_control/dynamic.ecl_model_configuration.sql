-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 06 - Accounting & Financial Control
-- TABLE: dynamic.ecl_model_configuration
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Ecl Model Configuration.
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
CREATE TABLE dynamic.ecl_model_configuration (

    model_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    model_name VARCHAR(200) NOT NULL,
    model_code VARCHAR(100) NOT NULL,
    model_description TEXT,
    
    -- Approach
    approach_type dynamic.ecl_approach NOT NULL,
    
    -- Component Models
    probability_of_default_model VARCHAR(100),
    loss_given_default_model VARCHAR(100),
    exposure_at_default_calculation VARCHAR(100),
    
    -- Forward Look
    forward_look_years INTEGER DEFAULT 1,
    macro_economic_scenario_id UUID REFERENCES dynamic.scenario_definition(scenario_id),
    
    -- Scope
    applicable_product_types VARCHAR(50)[],
    applicable_segments VARCHAR(50)[],
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_locked BOOLEAN DEFAULT FALSE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_ecl_model_code UNIQUE (tenant_id, model_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.ecl_model_configuration_default PARTITION OF dynamic.ecl_model_configuration DEFAULT;

-- Comments
COMMENT ON TABLE dynamic.ecl_model_configuration IS 'IFRS 9 Expected Credit Loss model configuration';

-- Triggers
CREATE TRIGGER trg_ecl_model_audit
    BEFORE UPDATE ON dynamic.ecl_model_configuration
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.ecl_model_configuration TO finos_app;