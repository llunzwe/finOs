-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 06 - Accounting Financial Control
-- TABLE: dynamic.ecl_model_configuration
-- COMPLIANCE: IFRS 9
--   - IFRS 15
--   - SOX 404
--   - FCA CASS
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