-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 10 - Regulatory Reporting
-- TABLE: dynamic_history.basel_reporting_data
-- COMPLIANCE: XBRL
--   - Basel III/IV
--   - FATF
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic_history.basel_reporting_data (

    entry_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Reporting Date
    reporting_date DATE NOT NULL,
    
    -- Exposure Details
    exposure_id UUID,
    exposure_type VARCHAR(100) NOT NULL, -- SOVEREIGN, BANK, CORPORATE, RETAIL, etc.
    exposure_sub_type VARCHAR(100),
    
    -- Risk Weights
    risk_weight DECIMAL(5,4) NOT NULL,
    exposure_amount DECIMAL(28,8) NOT NULL,
    rw_adjusted_amount DECIMAL(28,8) NOT NULL,
    
    -- Credit Risk Mitigation
    crm_applied BOOLEAN DEFAULT FALSE,
    crm_amount DECIMAL(28,8),
    
    -- Expected Credit Loss
    expected_credit_loss_provisions DECIMAL(28,8),
    
    -- Off-Balance Sheet
    off_balance_sheet_amount DECIMAL(28,8),
    credit_conversion_factor DECIMAL(5,4),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.basel_reporting_data_default PARTITION OF dynamic_history.basel_reporting_data DEFAULT;

-- Indexes
CREATE INDEX idx_baselt_data_date ON dynamic_history.basel_reporting_data(tenant_id, reporting_date);

-- Comments
COMMENT ON TABLE dynamic_history.basel_reporting_data IS 'Basel III/IV capital adequacy reporting data';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.basel_reporting_data TO finos_app;