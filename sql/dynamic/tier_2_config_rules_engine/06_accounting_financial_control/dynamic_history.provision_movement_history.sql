-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 06 - Accounting Financial Control
-- TABLE: dynamic_history.provision_movement_history
-- COMPLIANCE: IFRS 9
--   - IFRS 15
--   - SOX 404
--   - FCA CASS
-- ============================================================================


CREATE TABLE dynamic_history.provision_movement_history (

    movement_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    account_id UUID NOT NULL REFERENCES core.value_containers(id),
    model_id UUID NOT NULL REFERENCES dynamic.ecl_model_configuration(model_id),
    
    -- Reporting Date
    reporting_date DATE NOT NULL,
    
    -- Stage at Reporting
    stage_at_reporting INTEGER NOT NULL CHECK (stage_at_reporting BETWEEN 1 AND 3),
    previous_stage INTEGER,
    stage_change_reason VARCHAR(100),
    
    -- ECL Calculations
    twelve_month_ecl DECIMAL(28,8),
    lifetime_ecl DECIMAL(28,8),
    provision_amount DECIMAL(28,8) NOT NULL,
    
    -- Movement
    provision_charged DECIMAL(28,8),
    provision_released DECIMAL(28,8),
    provision_write_off DECIMAL(28,8),
    provision_recovery DECIMAL(28,8),
    
    -- Components
    probability_of_default DECIMAL(5,4),
    loss_given_default DECIMAL(5,4),
    exposure_at_default DECIMAL(28,8),
    discount_rate DECIMAL(10,6),
    
    -- Macro Factors
    macro_scenario_weights JSONB,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_provision_snapshot UNIQUE (tenant_id, account_id, reporting_date)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.provision_movement_history_default PARTITION OF dynamic_history.provision_movement_history DEFAULT;

-- Indexes
CREATE INDEX idx_provision_account ON dynamic_history.provision_movement_history(tenant_id, account_id);
CREATE INDEX idx_provision_date ON dynamic_history.provision_movement_history(reporting_date DESC);
CREATE INDEX idx_provision_model ON dynamic_history.provision_movement_history(tenant_id, model_id);

-- Comments
COMMENT ON TABLE dynamic_history.provision_movement_history IS 'Monthly provision movements under IFRS 9';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.provision_movement_history TO finos_app;