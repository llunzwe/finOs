-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 35 - Accounts & Deposits
-- TABLE: dynamic.sweep_account_rules
--
-- DESCRIPTION:
--   Enterprise-grade sweep account and zero-balance account management.
--   Automated fund transfers between master and sub-accounts.
--
-- COMPLIANCE: Banking Regulations, Cash Management Standards
-- ============================================================================


CREATE TABLE dynamic.sweep_account_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_name VARCHAR(200) NOT NULL,
    rule_type VARCHAR(50) NOT NULL 
        CHECK (rule_type IN ('ZERO_BALANCE_SWEEP', 'TARGET_BALANCE_SWEEP', 'THRESHOLD_SWEEP', 'INVESTMENT_SWEEP')),
    
    -- Master Account (Concentration Account)
    master_account_id UUID NOT NULL REFERENCES core.accounts(id),
    
    -- Sweep Direction
    sweep_direction VARCHAR(20) DEFAULT 'BOTH' 
        CHECK (sweep_direction IN ('IN', 'OUT', 'BOTH')), -- IN: to master, OUT: from master
    
    -- Balance Targets
    target_balance DECIMAL(28,8), -- Target balance for sub-accounts
    minimum_balance_threshold DECIMAL(28,8), -- Sweep out if above
    maximum_balance_threshold DECIMAL(28,8), -- Sweep in if below
    
    -- Sweep Amounts
    sweep_increment DECIMAL(28,8), -- Sweep in multiples of
    minimum_sweep_amount DECIMAL(28,8) DEFAULT 1.00,
    maximum_sweep_amount DECIMAL(28,8),
    
    -- Timing
    sweep_frequency VARCHAR(20) DEFAULT 'DAILY' 
        CHECK (sweep_frequency IN ('REALTIME', 'HOURLY', 'DAILY', 'END_OF_DAY')),
    sweep_time TIME DEFAULT '23:30:00',
    
    -- Investment Sweep Specific
    investment_account_id UUID REFERENCES core.accounts(id),
    investment_trigger_amount DECIMAL(28,8),
    redemption_trigger_amount DECIMAL(28,8),
    
    -- Sub-accounts (can be linked via separate table for many-to-many)
    applicable_account_types VARCHAR(50)[], -- ['CHECKING', 'SAVINGS', 'SUB_ACCOUNT']
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.sweep_account_rules_default PARTITION OF dynamic.sweep_account_rules DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.sweep_account_rules IS 'Sweep account rules - zero-balance, target-balance, investment sweeps. Tier 2 - Accounts & Deposits.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.sweep_account_rules TO finos_app;
