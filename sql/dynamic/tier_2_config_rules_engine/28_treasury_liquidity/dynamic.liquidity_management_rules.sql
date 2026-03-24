-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 28 - Treasury & Liquidity Management
-- TABLE: dynamic.liquidity_management_rules
--
-- DESCRIPTION:
--   Enterprise-grade liquidity management and cash positioning rules.
--   LCR/NSFR calculations, liquidity buffers, stress testing parameters.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- COMPLIANCE: Basel III/IV (LCR, NSFR), IFRS, SARB/RBZ Regulations
-- ============================================================================


CREATE TABLE dynamic.liquidity_management_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Liquidity Metric Type
    metric_type VARCHAR(50) NOT NULL 
        CHECK (metric_type IN ('LCR', 'NSFR', 'LIQUIDITY_RATIO', 'CASH_FLOW_GAP', 'STRESS_TEST')),
    
    -- Calculation Parameters
    calculation_method TEXT NOT NULL, -- SQL or formula reference
    reporting_frequency VARCHAR(20) DEFAULT 'DAILY' 
        CHECK (reporting_frequency IN ('INTRADAY', 'DAILY', 'WEEKLY', 'MONTHLY')),
    reporting_currency CHAR(3) NOT NULL,
    
    -- HQLA (High Quality Liquid Assets) Classification
    hqla_level INTEGER CHECK (hqla_level IN (1, 2, 3)),
    haircut_percentage DECIMAL(5,4) DEFAULT 0.0,
    
    -- Cash Flow Buckets
    time_buckets INTEGER[] DEFAULT ARRAY[1, 7, 30, 90, 180, 365], -- Days
    
    -- Limits & Thresholds
    minimum_ratio DECIMAL(5,4) DEFAULT 1.0, -- 100% for LCR
    warning_threshold DECIMAL(5,4) DEFAULT 1.05,
    breach_threshold DECIMAL(5,4) DEFAULT 1.0,
    
    -- Stress Testing
    stress_scenario VARCHAR(50), -- 'IDIOSYNCRATIC', 'MARKET_WIDE', 'COMBINED'
    stress_multiplier DECIMAL(5,2) DEFAULT 1.0,
    run_off_rate DECIMAL(5,4), -- Deposit run-off assumptions
    
    -- Sweep Configuration
    auto_sweep_enabled BOOLEAN DEFAULT FALSE,
    sweep_target_account_id UUID REFERENCES dynamic.gl_account_master(account_id),
    sweep_threshold DECIMAL(28,8),
    sweep_target_balance DECIMAL(28,8),
    
    -- Scope
    applicable_entities UUID[], -- Branch/legal entity scope
    applicable_currencies CHAR(3)[],
    
    -- Status
    rule_status VARCHAR(20) DEFAULT 'ACTIVE' 
        CHECK (rule_status IN ('DRAFT', 'ACTIVE', 'INACTIVE')),
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_rule_code_per_tenant UNIQUE (tenant_id, rule_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.liquidity_management_rules_default PARTITION OF dynamic.liquidity_management_rules DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_liquidity_rule_tenant ON dynamic.liquidity_management_rules(tenant_id);
CREATE INDEX idx_liquidity_rule_type ON dynamic.liquidity_management_rules(tenant_id, metric_type);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.liquidity_management_rules IS 'Liquidity management rules - LCR/NSFR calculations and cash positioning. Tier 2 - Treasury & Liquidity Management.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.liquidity_management_rules TO finos_app;
