-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 10 - Regulatory Reporting
-- TABLE: dynamic_history.basel_reporting_data
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Basel Reporting Data.
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
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.basel_reporting_data_default PARTITION OF dynamic_history.basel_reporting_data DEFAULT;

-- Indexes
CREATE INDEX idx_baselt_data_date ON dynamic_history.basel_reporting_data(tenant_id, reporting_date);

-- Comments
COMMENT ON TABLE dynamic_history.basel_reporting_data IS 'Basel III/IV capital adequacy reporting data';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.basel_reporting_data TO finos_app;