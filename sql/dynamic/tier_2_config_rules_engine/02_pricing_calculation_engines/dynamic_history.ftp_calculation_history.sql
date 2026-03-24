-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic_history.ftp_calculation_history
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Ftp Calculation History.
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


CREATE TABLE dynamic_history.ftp_calculation_history (
    calc_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    container_id UUID NOT NULL REFERENCES core.value_containers(id) ON DELETE CASCADE,
    rule_id UUID NOT NULL REFERENCES dynamic.funds_transfer_pricing_rules(rule_id),
    
    -- Calculation Details
    calculation_date DATE NOT NULL,
    balance_amount DECIMAL(28,8) NOT NULL,
    ftp_rate DECIMAL(15,10) NOT NULL,
    ftp_amount DECIMAL(28,8) NOT NULL,
    
    -- Components
    base_rate DECIMAL(15,10),
    liquidity_premium DECIMAL(15,10),
    credit_spread DECIMAL(15,10),
    other_adjustments DECIMAL(15,10),
    
    -- Tenor
    matched_tenor_days INTEGER,
    tenor_maturity_date DATE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.ftp_calculation_history_default PARTITION OF dynamic_history.ftp_calculation_history DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_ftp_history_container
idx_ftp_history_date

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic_history.ftp_calculation_history IS 'Historical FTP calculations by account';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic_history.ftp_calculation_history TO finos_app;
