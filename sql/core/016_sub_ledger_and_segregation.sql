-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 17: SUB-LEDGER & SEGREGATION
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: Client Money Segregation, Sub-ledger Reconciliation, FCA CASS
-- Standards: FCA CASS, SEC Rule 15c3-3, MiFID II, Basel III
-- =============================================================================

-- =============================================================================
-- MASTER ACCOUNTS (Omnibus/FBO)
-- =============================================================================
CREATE TABLE core.master_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Links to Core Container
    container_id UUID NOT NULL REFERENCES core.value_containers(id),
    
    -- Master Account Identification
    master_account_code VARCHAR(100) NOT NULL,
    master_account_name VARCHAR(255),
    
    -- Account Type
    account_type VARCHAR(50) NOT NULL 
        CHECK (account_type IN ('fbo_master', 'omnibus', 'pooled', 'trust', 'escrow_master', 'segregated_client')),
    segregation_type VARCHAR(50) NOT NULL 
        CHECK (segregation_type IN ('client_money', 'trust', 'escrow', 'custody', 'margin', 'safeguarding')),
    
    -- Regulatory Framework
    regulatory_framework VARCHAR(50), -- 'CASS', 'SEC_15c3-3', 'MiFID_II', 'Basel_III', 'EMD'
    regulatory_reporting_required BOOLEAN NOT NULL DEFAULT TRUE,
    regulator_reference VARCHAR(100),
    
    -- Institution Details
    holding_institution VARCHAR(200),
    institution_bic VARCHAR(11),
    institution_account_number VARCHAR(100),
    institution_country CHAR(2),
    
    -- Aggregation Tracking
    total_subledger_balance DECIMAL(28,8) NOT NULL DEFAULT 0,
    total_subledger_count INTEGER NOT NULL DEFAULT 0,
    master_physical_balance DECIMAL(28,8),
    pending_credits DECIMAL(28,8) DEFAULT 0,
    pending_debits DECIMAL(28,8) DEFAULT 0,
    
    -- Reconciliation Gap (Must Be Zero)
    reconciliation_gap DECIMAL(28,8) GENERATED ALWAYS AS (
        COALESCE(master_physical_balance, 0) - COALESCE(total_subledger_balance, 0) - COALESCE(pending_credits, 0) + COALESCE(pending_debits, 0)
    ) STORED,
    reconciliation_tolerance DECIMAL(10,6) DEFAULT 0.01,
    is_reconciled BOOLEAN GENERATED ALWAYS AS (
        ABS(COALESCE(master_physical_balance, 0) - COALESCE(total_subledger_balance, 0) - COALESCE(pending_credits, 0) + COALESCE(pending_debits, 0)) <= 0.01
    ) STORED,
    last_reconciled_at TIMESTAMPTZ,
    last_reconciliation_id UUID,
    
    -- Denormalized Sub-ledger IDs (for quick reference)
    sub_account_ids UUID[],
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'active' 
        CHECK (status IN ('active', 'frozen', 'winding_down', 'closed')),
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    
    -- Audit
    appointed_auditor VARCHAR(200),
    last_audit_date DATE,
    next_audit_date DATE,
    audit_notes TEXT,
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER DEFAULT 1,
    
    CONSTRAINT unique_master_code UNIQUE (tenant_id, master_account_code)
);

CREATE INDEX idx_master_accounts_container ON core.master_accounts(container_id);
CREATE INDEX idx_master_accounts_status ON core.master_accounts(tenant_id, status) WHERE status = 'active';
CREATE INDEX idx_master_accounts_reconciled ON core.master_accounts(tenant_id, is_reconciled) WHERE is_reconciled = FALSE;
CREATE INDEX idx_master_accounts_segregation ON core.master_accounts(tenant_id, segregation_type);
CREATE INDEX idx_master_accounts_correlation ON core.master_accounts(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_sub_accounts_correlation ON core.sub_accounts(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core.master_accounts IS 'Master accounts for client money segregation and sub-ledger aggregation';
COMMENT ON TABLE core.sub_accounts IS 'Individual sub-accounts rolling up to master accounts';
COMMENT ON COLUMN core.master_accounts.reconciliation_gap IS 'Difference between master balance and sum of sub-ledgers (must be zero)';

-- =============================================================================
-- SUB-ACCOUNTS (Client/Beneficiary Level)
-- =============================================================================
CREATE TABLE core.sub_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    master_account_id UUID NOT NULL REFERENCES core.master_accounts(id),
    
    -- Links to Core Container
    container_id UUID NOT NULL REFERENCES core.value_containers(id),
    
    -- Ownership
    owner_agent_id UUID NOT NULL REFERENCES core.economic_agents(id),
    beneficial_owner_id UUID REFERENCES core.economic_agents(id),
    
    -- Virtual Addressing
    sub_account_code VARCHAR(100) NOT NULL,
    virtual_account_number VARCHAR(100),
    virtual_iban VARCHAR(34),
    virtual_sort_code VARCHAR(20),
    
    -- Purpose
    account_purpose VARCHAR(50), -- 'trading', 'savings', 'operational', 'margin', 'collateral'
    product_code VARCHAR(50),
    
    -- Balances (Must Roll Up to Master)
    balance DECIMAL(28,8) NOT NULL DEFAULT 0,
    available_balance DECIMAL(28,8) NOT NULL DEFAULT 0,
    held_balance DECIMAL(28,8) NOT NULL DEFAULT 0,
    pending_balance DECIMAL(28,8) NOT NULL DEFAULT 0,
    
    -- Specific Constraints (Overrides Container Limits)
    specific_limits JSONB DEFAULT '{}',
    
    -- Interest
    interest_rate DECIMAL(10,6),
    interest_accrual_method VARCHAR(50),
    last_interest_posted_at TIMESTAMPTZ,
    accrued_interest DECIMAL(28,8) DEFAULT 0,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'active' 
        CHECK (status IN ('active', 'suspended', 'frozen', 'dormant', 'closed')),
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    closure_reason VARCHAR(100),
    
    -- CASS Specific
    cass_category VARCHAR(50), -- 'individual_client', 'net margined', 'gross margined'
    daily_calculation_required BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER DEFAULT 1,
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    idempotency_key VARCHAR(100),
    
    CONSTRAINT unique_sub_account_code UNIQUE (tenant_id, sub_account_code),
    CONSTRAINT unique_virtual_account UNIQUE (master_account_id, virtual_account_number)
);

CREATE INDEX idx_sub_accounts_master ON core.sub_accounts(master_account_id, status);
CREATE INDEX idx_sub_accounts_owner ON core.sub_accounts(owner_agent_id);
CREATE INDEX idx_sub_accounts_container ON core.sub_accounts(container_id);
CREATE INDEX idx_sub_accounts_status ON core.sub_accounts(tenant_id, status) WHERE status = 'active';
CREATE INDEX idx_sub_accounts_virtual ON core.sub_accounts(virtual_account_number, virtual_iban);

COMMENT ON TABLE core.sub_accounts IS 'Individual sub-accounts rolling up to master accounts';

-- =============================================================================
-- SUB-LEDGER BALANCE HISTORY
-- =============================================================================
CREATE TABLE core_history.sub_ledger_balances (
    time TIMESTAMPTZ NOT NULL,
    tenant_id UUID NOT NULL,
    
    master_account_id UUID NOT NULL,
    sub_account_id UUID NOT NULL,
    
    -- Balances
    balance DECIMAL(28,8) NOT NULL,
    available_balance DECIMAL(28,8) NOT NULL,
    held_balance DECIMAL(28,8) NOT NULL,
    
    -- Reconciliation
    master_balance_at_time DECIMAL(28,8),
    sub_ledger_total_at_time DECIMAL(28,8),
    gap_at_time DECIMAL(28,8),
    
    PRIMARY KEY (time, sub_account_id)
);

SELECT create_hypertable('core_history.sub_ledger_balances', 'time', 
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists => TRUE);

CREATE INDEX idx_sub_ledger_master ON core_history.sub_ledger_balances(master_account_id, time DESC);
CREATE INDEX idx_sub_ledger_sub ON core_history.sub_ledger_balances(sub_account_id, time DESC);

COMMENT ON TABLE core_history.sub_ledger_balances IS 'Time-series sub-ledger balance history';

-- =============================================================================
-- SUB-LEDGER RECONCILIATION
-- =============================================================================
CREATE TABLE core.sub_ledger_reconciliations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    master_account_id UUID NOT NULL REFERENCES core.master_accounts(id),
    
    -- Reconciliation Date
    recon_date DATE NOT NULL,
    recon_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Balances
    master_physical_balance DECIMAL(28,8) NOT NULL,
    sub_ledger_total DECIMAL(28,8) NOT NULL,
    pending_credits DECIMAL(28,8) DEFAULT 0,
    pending_debits DECIMAL(28,8) DEFAULT 0,
    
    -- Gap
    gross_gap DECIMAL(28,8) GENERATED ALWAYS AS (master_physical_balance - sub_ledger_total) STORED,
    net_gap DECIMAL(28,8) GENERATED ALWAYS AS (master_physical_balance - sub_ledger_total - pending_credits + pending_debits) STORED,
    
    -- Status
    is_reconciled BOOLEAN GENERATED ALWAYS AS (ABS(master_physical_balance - sub_ledger_total - pending_credits + pending_debits) <= 0.01) STORED,
    status VARCHAR(20) NOT NULL DEFAULT 'in_progress' 
        CHECK (status IN ('in_progress', 'reconciled', 'unreconciled', 'adjusted')),
    
    -- Breaks (if any)
    break_items JSONB DEFAULT '[]',
    
    -- Approval
    prepared_by UUID REFERENCES core.economic_agents(id),
    reviewed_by UUID REFERENCES core.economic_agents(id),
    approved_by UUID REFERENCES core.economic_agents(id),
    approved_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sub_ledger_recon_master ON core.sub_ledger_reconciliations(master_account_id, recon_date DESC);
CREATE INDEX idx_sub_ledger_recon_status ON core.sub_ledger_reconciliations(tenant_id, status) WHERE status != 'reconciled';

COMMENT ON TABLE core.sub_ledger_reconciliations IS 'Daily sub-ledger to master reconciliation records';

-- =============================================================================
-- SEGREGATION RULES
-- =============================================================================
CREATE TABLE core.segregation_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    rule_name VARCHAR(100) NOT NULL,
    rule_type VARCHAR(50) NOT NULL CHECK (rule_type IN ('auto_allocate', 'sweep', 'reserve', 'block')),
    
    -- Applicability
    applies_to_master_account_id UUID REFERENCES core.master_accounts(id),
    applies_to_client_category VARCHAR(50),
    applies_to_product_type VARCHAR(50),
    
    -- Conditions
    trigger_condition JSONB NOT NULL, -- {"field": "balance", "operator": ">", "value": 100000}
    action JSONB NOT NULL, -- {"type": "sweep", "target_account": "reserve_account"}
    
    -- Limits
    max_sweep_amount DECIMAL(28,8),
    min_balance_required DECIMAL(28,8),
    
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 100,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE core.segregation_rules IS 'Automated rules for client money segregation';

-- =============================================================================
-- CLIENT MONEY CALCULATIONS (CASS)
-- =============================================================================
CREATE TABLE core.client_money_calculations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    calculation_date DATE NOT NULL,
    master_account_id UUID NOT NULL REFERENCES core.master_accounts(id),
    
    -- CASS 7 Calculation
    total_client_money DECIMAL(28,8) NOT NULL,
    individual_client_balances JSONB NOT NULL, -- {client_id: amount}
    
    -- Margined vs Non-Margined
    net_margined_amount DECIMAL(28,8),
    gross_margined_amount DECIMAL(28,8),
    non_margined_amount DECIMAL(28,8),
    
    -- Required Reserve
    required_reserve DECIMAL(28,8),
    actual_reserve DECIMAL(28,8),
    shortfall DECIMAL(28,8) GENERATED ALWAYS AS (GREATEST(0, required_reserve - actual_reserve)) STORED,
    
    -- Status
    is_compliant BOOLEAN GENERATED ALWAYS AS (actual_reserve >= required_reserve) STORED,
    
    -- Audit
    calculated_by UUID,
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_by UUID,
    reviewed_at TIMESTAMPTZ,
    
    CONSTRAINT unique_cass_calculation UNIQUE (tenant_id, master_account_id, calculation_date)
);

CREATE INDEX idx_client_money_calc_master ON core.client_money_calculations(master_account_id, calculation_date DESC);
CREATE INDEX idx_client_money_calc_compliance ON core.client_money_calculations(tenant_id, is_compliant) WHERE is_compliant = FALSE;

COMMENT ON TABLE core.client_money_calculations IS 'FCA CASS 7 client money calculations';

-- =============================================================================
-- CONSERVATION OF VALUE TRIGGER
-- =============================================================================
CREATE OR REPLACE FUNCTION core.enforce_subledger_conservation()
RETURNS TRIGGER AS $$
DECLARE
    v_master_id UUID;
    v_sum DECIMAL(28,8);
    v_master_balance DECIMAL(28,8);
    v_tolerance DECIMAL(28,8);
BEGIN
    -- Get master account
    SELECT master_account_id INTO v_master_id
    FROM core.sub_accounts
    WHERE id = NEW.id;
    
    -- Calculate sum of all active sub-accounts
    SELECT COALESCE(SUM(balance), 0) INTO v_sum
    FROM core.sub_accounts
    WHERE master_account_id = v_master_id AND status = 'active';
    
    -- Get master physical balance and tolerance
    SELECT master_physical_balance, reconciliation_tolerance 
    INTO v_master_balance, v_tolerance
    FROM core.master_accounts
    WHERE id = v_master_id;
    
    -- Update master account totals
    UPDATE core.master_accounts
    SET total_subledger_balance = v_sum,
        total_subledger_count = (SELECT COUNT(*) FROM core.sub_accounts WHERE master_account_id = v_master_id AND status = 'active'),
        sub_account_ids = (SELECT ARRAY_AGG(id) FROM core.sub_accounts WHERE master_account_id = v_master_id AND status = 'active'),
        updated_at = NOW()
    WHERE id = v_master_id;
    
    -- Check conservation (with tolerance)
    IF ABS(COALESCE(v_sum, 0) - COALESCE(v_master_balance, 0)) > COALESCE(v_tolerance, 0.01) THEN
        RAISE WARNING 'SUBLEDGER_CONSERVATION_WARNING: Master % physical balance % != sum of subs % (gap: %)',
            v_master_id, v_master_balance, v_sum, v_master_balance - v_sum;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_subledger_conservation
    AFTER INSERT OR UPDATE OF balance ON core.sub_accounts
    FOR EACH ROW EXECUTE FUNCTION core.enforce_subledger_conservation();

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.master_accounts TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.sub_accounts TO finos_app;
GRANT SELECT, INSERT ON core_history.sub_ledger_balances TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.sub_ledger_reconciliations TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.segregation_rules TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.client_money_calculations TO finos_app;
