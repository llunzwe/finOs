-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 09 - Settlement Configuration
-- TABLE: dynamic.settlement_method_config
--
-- DESCRIPTION:
--   Enterprise-grade configuration for settlement methods.
--   Maps to core.settlement_instructions - enables low-code configuration
--   of RTGS, DNS, Bilateral settlement rules per CSDR/ISO 20022.
--
-- CORE DEPENDENCY: 009_settlement_and_finality.sql
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--
-- COMPLIANCE FRAMEWORK:
--   - CSDR (Central Securities Depositories Regulation)
--   - ISO 20022 (pacs.008, pacs.009, camt.053)
--   - Dodd-Frank (US)
--   - PFMI (CPMI-IOSCO Principles for Financial Market Infrastructures)
--
-- AUDIT & GOVERNANCE:
--   - Bitemporal tracking (valid_from, valid_to)
--   - Full audit trail
--   - Version control for change management
--   - Tenant isolation via partitioning
--
-- ============================================================================

CREATE TABLE dynamic.settlement_method_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Configuration Identification
    config_code VARCHAR(100) NOT NULL,
    config_name VARCHAR(200) NOT NULL,
    config_description TEXT,
    
    -- Settlement Method (maps to core.settlement_instructions.settlement_method)
    settlement_method dynamic.settlement_method NOT NULL,
    
    -- Settlement Cycle
    settlement_cycle VARCHAR(10) NOT NULL DEFAULT 'T+2', -- T+0, T+1, T+2, T+3
    cutoff_time TIME NOT NULL DEFAULT '16:00:00',
    
    -- Finality Configuration
    finality_threshold_seconds INTEGER DEFAULT 0, -- 0 = immediate, >0 = provisional period
    auto_finalize BOOLEAN DEFAULT TRUE,
    revocable_period_seconds INTEGER DEFAULT 0,
    
    -- RTGS Specific
    rtgs_ledger_id UUID, -- References core.liquidity_positions for RTGS
    rtgs_minimum_amount DECIMAL(28,8),
    
    -- DNS Specific
    dns_batch_window_minutes INTEGER DEFAULT 60,
    dns_netting_algorithm VARCHAR(50) DEFAULT 'bilateral', -- bilateral, multilateral
    dns_failure_handling VARCHAR(50) DEFAULT 'partial', -- partial, all_or_nothing
    
    -- Bilateral Specific
    bilateral_counterparty_required BOOLEAN DEFAULT TRUE,
    bilateral_confirmation_required BOOLEAN DEFAULT TRUE,
    bilateral_confirmation_timeout_minutes INTEGER DEFAULT 30,
    
    -- Liquidity Management
    liquidity_reserve_percentage DECIMAL(5,4) DEFAULT 0.00, -- 0% to 100%
    liquidity_check_required BOOLEAN DEFAULT TRUE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    
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
    
    -- Constraints
    CONSTRAINT unique_settlement_config_code UNIQUE (tenant_id, config_code),
    CONSTRAINT chk_settlement_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_liquidity_reserve CHECK (liquidity_reserve_percentage BETWEEN 0 AND 1)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.settlement_method_config_default PARTITION OF dynamic.settlement_method_config DEFAULT;

-- Indexes
CREATE INDEX idx_settlement_config_method ON dynamic.settlement_method_config(tenant_id, settlement_method) WHERE is_active = TRUE AND is_current = TRUE;
CREATE INDEX idx_settlement_config_default ON dynamic.settlement_method_config(tenant_id) WHERE is_default = TRUE;
CREATE INDEX idx_settlement_config_temporal ON dynamic.settlement_method_config(tenant_id, valid_from, valid_to) WHERE is_current = TRUE;

-- Comments
COMMENT ON TABLE dynamic.settlement_method_config IS 'Settlement method configuration (RTGS/DNS/Bilateral) - maps to core.settlement_instructions. Tier 2 Low-Code';
COMMENT ON COLUMN dynamic.settlement_method_config.finality_threshold_seconds IS 'Time before settlement achieves finality per CSDR Article 5';
COMMENT ON COLUMN dynamic.settlement_method_config.liquidity_reserve_percentage IS 'Required liquidity reserve as percentage of settlement amount';

-- Trigger
CREATE TRIGGER trg_settlement_method_config_audit
    BEFORE UPDATE ON dynamic.settlement_method_config
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.settlement_method_config TO finos_app;
