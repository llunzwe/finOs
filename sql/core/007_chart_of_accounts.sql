-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 7: CHART OF ACCOUNTS
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: Hierarchical Structure, Multi-GAAP Support, Temporal Validity
-- Standards: IFRS, US GAAP, IAS 1
-- =============================================================================

-- =============================================================================
-- CHART OF ACCOUNTS (Hierarchical)
-- =============================================================================
CREATE TABLE core.chart_of_accounts (
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    
    -- Hierarchy
    name VARCHAR(255) NOT NULL,
    type VARCHAR(20) NOT NULL 
        CHECK (type IN ('ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE', 'SUSPENSE', 'OFF_BALANCE')),
    parent_code VARCHAR(50),
    
    -- Classification
    subtype VARCHAR(50), -- 'current_asset', 'long_term_liability', 'operating_income', etc.
    category VARCHAR(50), -- Further classification
    
    -- Financial Statement Mapping
    financial_statement VARCHAR(50) CHECK (financial_statement IN ('BALANCE_SHEET', 'INCOME_STATEMENT', 'CASH_FLOW', 'EQUITY_STATEMENT', 'NOTES')),
    statement_section VARCHAR(100), -- 'Current Assets', 'Operating Activities', etc.
    statement_line_item INTEGER, -- Order within statement
    
    -- Debit/Credit Behavior
    normal_balance VARCHAR(6) NOT NULL CHECK (normal_balance IN ('debit', 'credit')),
    is_contra_account BOOLEAN DEFAULT FALSE,
    contra_to_account VARCHAR(50), -- If contra, what is the parent
    
    -- Accounting Standards
    ifrs_reference VARCHAR(50), -- e.g., 'IFRS 9.5.4', 'IAS 1.54'
    us_gaap_reference VARCHAR(50), -- e.g., 'ASC 310-10'
    local_gaap_reference VARCHAR(50),
    
    -- Operational Settings
    is_bank_account BOOLEAN DEFAULT FALSE,
    is_cash_equivalent BOOLEAN DEFAULT FALSE,
    is_reconciliation_required BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Hierarchy Management
    level INTEGER NOT NULL DEFAULT 1,
    is_leaf BOOLEAN NOT NULL DEFAULT TRUE,
    path LTREE,
    
    -- Temporal
    valid_from DATE NOT NULL DEFAULT '1900-01-01',
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    
    -- Metadata
    description TEXT,
    attributes JSONB DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version INTEGER NOT NULL DEFAULT 1,
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    
    -- Soft Delete
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    PRIMARY KEY (tenant_id, code),
    FOREIGN KEY (tenant_id, parent_code) REFERENCES core.chart_of_accounts(tenant_id, code)
        DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT chk_coa_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_no_self_parent CHECK (parent_code IS NULL OR parent_code != code)
);

-- Indexes (-3.2)
CREATE INDEX idx_coa_type ON core.chart_of_accounts(tenant_id, type, is_active) WHERE is_active = TRUE AND is_deleted = FALSE;
CREATE INDEX idx_coa_hierarchy ON core.chart_of_accounts(tenant_id, parent_code) WHERE parent_code IS NOT NULL;
CREATE INDEX idx_coa_path ON core.chart_of_accounts USING GIST(path);
CREATE INDEX idx_coa_statement ON core.chart_of_accounts(tenant_id, financial_statement, statement_section, statement_line_item);
CREATE INDEX idx_coa_leaf ON core.chart_of_accounts(tenant_id, is_leaf) WHERE is_leaf = TRUE;
CREATE INDEX idx_coa_correlation ON core.chart_of_accounts(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_coa_active_composite ON core.chart_of_accounts(tenant_id, type, valid_from, valid_to) 
    WHERE is_active = TRUE AND is_deleted = FALSE;

COMMENT ON TABLE core.chart_of_accounts IS 'Hierarchical chart of accounts supporting IFRS/US GAAP/local GAAP';

-- Trigger for hierarchy management
CREATE OR REPLACE FUNCTION core.update_coa_hierarchy()
RETURNS TRIGGER AS $$
BEGIN
    -- Calculate level
    IF NEW.parent_code IS NULL THEN
        NEW.level := 1;
        NEW.path := NEW.code::ltree;
    ELSE
        SELECT level + 1, path || NEW.code::ltree
        INTO NEW.level, NEW.path
        FROM core.chart_of_accounts
        WHERE tenant_id = NEW.tenant_id AND code = NEW.parent_code;
    END IF;
    
    -- Update parent is_leaf
    IF NEW.parent_code IS NOT NULL THEN
        UPDATE core.chart_of_accounts
        SET is_leaf = FALSE
        WHERE tenant_id = NEW.tenant_id AND code = NEW.parent_code;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_coa_hierarchy
    BEFORE INSERT OR UPDATE ON core.chart_of_accounts
    FOR EACH ROW EXECUTE FUNCTION core.update_coa_hierarchy();

-- =============================================================================
-- ACCOUNT MAPPINGS (Multi-GAAP)
-- =============================================================================
CREATE TABLE core.account_mappings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Source Account
    source_account_code VARCHAR(50) NOT NULL,
    source_gaap VARCHAR(20) NOT NULL CHECK (source_gaap IN ('IFRS', 'US_GAAP', 'LOCAL_GAAP')),
    
    -- Target Account
    target_account_code VARCHAR(50) NOT NULL,
    target_gaap VARCHAR(20) NOT NULL CHECK (target_gaap IN ('IFRS', 'US_GAAP', 'LOCAL_GAAP')),
    
    -- Mapping Rules
    mapping_type VARCHAR(20) NOT NULL CHECK (mapping_type IN ('one_to_one', 'one_to_many', 'many_to_one', 'formula')),
    mapping_formula TEXT, -- For complex mappings
    
    -- Conversion Factors
    conversion_factor DECIMAL(28,8) DEFAULT 1.0,
    conversion_currency CHAR(3),
    
    -- Temporal
    valid_from DATE NOT NULL DEFAULT '1900-01-01',
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    CONSTRAINT unique_account_mapping UNIQUE (tenant_id, source_account_code, source_gaap, target_gaap, valid_from)
);

CREATE INDEX idx_account_mappings_source ON core.account_mappings(tenant_id, source_account_code, source_gaap);
CREATE INDEX idx_account_mappings_target ON core.account_mappings(tenant_id, target_account_code, target_gaap);

COMMENT ON TABLE core.account_mappings IS 'Mappings between accounts for different GAAP standards';

-- =============================================================================
-- ACCOUNT BALANCES (Aggregated)
-- =============================================================================
CREATE TABLE core.account_balances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    account_code VARCHAR(50) NOT NULL,
    currency_code CHAR(3) NOT NULL REFERENCES core.currencies(code),
    
    -- Balance Types
    opening_balance DECIMAL(28,8) DEFAULT 0,
    debits_ytd DECIMAL(28,8) DEFAULT 0,
    credits_ytd DECIMAL(28,8) DEFAULT 0,
    period_movement DECIMAL(28,8) DEFAULT 0,
    closing_balance DECIMAL(28,8) DEFAULT 0,
    
    -- Period
    fiscal_year INTEGER NOT NULL,
    period INTEGER NOT NULL, -- 1-12 for months, or 1-4 for quarters
    period_type VARCHAR(20) NOT NULL CHECK (period_type IN ('month', 'quarter', 'year')),
    
    -- Status
    is_closed BOOLEAN DEFAULT FALSE,
    closed_at TIMESTAMPTZ,
    closed_by VARCHAR(100),
    
    -- Audit
    last_movement_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    
    CONSTRAINT unique_account_balance UNIQUE (tenant_id, account_code, currency_code, fiscal_year, period, period_type)
);

CREATE INDEX idx_account_balances_period ON core.account_balances(tenant_id, fiscal_year, period);
CREATE INDEX idx_account_balances_account ON core.account_balances(tenant_id, account_code);

COMMENT ON TABLE core.account_balances IS 'Aggregated account balances by period for financial reporting';

-- =============================================================================
-- TRIAL BALANCE
-- =============================================================================
CREATE TABLE core.trial_balances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Period
    as_of_date DATE NOT NULL,
    fiscal_year INTEGER NOT NULL,
    period INTEGER NOT NULL,
    
    -- Totals
    total_debits DECIMAL(28,8) NOT NULL DEFAULT 0,
    total_credits DECIMAL(28,8) NOT NULL DEFAULT 0,
    difference DECIMAL(28,8) GENERATED ALWAYS AS (total_debits - total_credits) STORED,
    is_balanced BOOLEAN GENERATED ALWAYS AS (total_debits = total_credits) STORED,
    
    -- Status
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'reviewed', 'adjusted', 'approved')),
    
    -- Audit
    prepared_by VARCHAR(100),
    reviewed_by VARCHAR(100),
    approved_by VARCHAR(100),
    prepared_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT unique_trial_balance UNIQUE (tenant_id, as_of_date)
);

CREATE INDEX idx_trial_balances_period ON core.trial_balances(tenant_id, fiscal_year, period);

COMMENT ON TABLE core.trial_balances IS 'Trial balance snapshots for period-end closing';

-- =============================================================================
-- TRIAL BALANCE DETAIL
-- =============================================================================
CREATE TABLE core.trial_balance_details (
    trial_balance_id UUID NOT NULL REFERENCES core.trial_balances(id) ON DELETE CASCADE,
    account_code VARCHAR(50) NOT NULL,
    
    opening_balance DECIMAL(28,8) DEFAULT 0,
    period_debits DECIMAL(28,8) DEFAULT 0,
    period_credits DECIMAL(28,8) DEFAULT 0,
    closing_balance DECIMAL(28,8) DEFAULT 0,
    
    PRIMARY KEY (trial_balance_id, account_code)
);

COMMENT ON TABLE core.trial_balance_details IS 'Line items for trial balance';

-- =============================================================================
-- SEED DATA - STANDARD CHART OF ACCOUNTS
-- =============================================================================

-- Assets (1xxx)
INSERT INTO core.chart_of_accounts (tenant_id, code, name, type, normal_balance, level, financial_statement, statement_section, ifrs_reference) VALUES
('00000000-0000-0000-0000-000000000000', '1000', 'Assets', 'ASSET', 'debit', 1, 'BALANCE_SHEET', 'Assets', 'IAS 1.54'),
('00000000-0000-0000-0000-000000000000', '1100', 'Current Assets', 'ASSET', 'debit', 2, 'BALANCE_SHEET', 'Current Assets', 'IAS 1.54'),
('00000000-0000-0000-0000-000000000000', '1110', 'Cash and Cash Equivalents', 'ASSET', 'debit', 3, 'BALANCE_SHEET', 'Current Assets', 'IAS 7'),
('00000000-0000-0000-0000-000000000000', '1111', 'Cash on Hand', 'ASSET', 'debit', 4, 'BALANCE_SHEET', 'Current Assets', 'IAS 7'),
('00000000-0000-0000-0000-000000000000', '1112', 'Bank Accounts', 'ASSET', 'debit', 4, 'BALANCE_SHEET', 'Current Assets', 'IAS 7'),
('00000000-0000-0000-0000-000000000000', '1120', 'Accounts Receivable', 'ASSET', 'debit', 3, 'BALANCE_SHEET', 'Current Assets', 'IFRS 9'),
('00000000-0000-0000-0000-000000000000', '1200', 'Non-Current Assets', 'ASSET', 'debit', 2, 'BALANCE_SHEET', 'Non-Current Assets', 'IAS 1.54')
ON CONFLICT (tenant_id, code) DO NOTHING;

-- Liabilities (2xxx)
INSERT INTO core.chart_of_accounts (tenant_id, code, name, type, normal_balance, level, financial_statement, statement_section, ifrs_reference) VALUES
('00000000-0000-0000-0000-000000000000', '2000', 'Liabilities', 'LIABILITY', 'credit', 1, 'BALANCE_SHEET', 'Liabilities', 'IAS 1.54'),
('00000000-0000-0000-0000-000000000000', '2100', 'Current Liabilities', 'LIABILITY', 'credit', 2, 'BALANCE_SHEET', 'Current Liabilities', 'IAS 1.54'),
('00000000-0000-0000-0000-000000000000', '2110', 'Accounts Payable', 'LIABILITY', 'credit', 3, 'BALANCE_SHEET', 'Current Liabilities', 'IAS 1.54'),
('00000000-0000-0000-0000-000000000000', '2120', 'Customer Deposits', 'LIABILITY', 'credit', 3, 'BALANCE_SHEET', 'Current Liabilities', 'IFRS 9'),
('00000000-0000-0000-0000-000000000000', '2200', 'Non-Current Liabilities', 'LIABILITY', 'credit', 2, 'BALANCE_SHEET', 'Non-Current Liabilities', 'IAS 1.54')
ON CONFLICT (tenant_id, code) DO NOTHING;

-- Equity (3xxx)
INSERT INTO core.chart_of_accounts (tenant_id, code, name, type, normal_balance, level, financial_statement, statement_section, ifrs_reference) VALUES
('00000000-0000-0000-0000-000000000000', '3000', 'Equity', 'EQUITY', 'credit', 1, 'BALANCE_SHEET', 'Equity', 'IAS 1.54'),
('00000000-0000-0000-0000-000000000000', '3100', 'Share Capital', 'EQUITY', 'credit', 2, 'BALANCE_SHEET', 'Equity', 'IAS 1.54'),
('00000000-0000-0000-0000-000000000000', '3200', 'Retained Earnings', 'EQUITY', 'credit', 2, 'BALANCE_SHEET', 'Equity', 'IAS 1.54')
ON CONFLICT (tenant_id, code) DO NOTHING;

-- Income (4xxx)
INSERT INTO core.chart_of_accounts (tenant_id, code, name, type, normal_balance, level, financial_statement, statement_section, ifrs_reference) VALUES
('00000000-0000-0000-0000-000000000000', '4000', 'Income', 'INCOME', 'credit', 1, 'INCOME_STATEMENT', 'Revenue', 'IAS 1.82'),
('00000000-0000-0000-0000-000000000000', '4100', 'Operating Income', 'INCOME', 'credit', 2, 'INCOME_STATEMENT', 'Revenue', 'IAS 1.82'),
('00000000-0000-0000-0000-000000000000', '4110', 'Interest Income', 'INCOME', 'credit', 3, 'INCOME_STATEMENT', 'Revenue', 'IFRS 9'),
('00000000-0000-0000-0000-000000000000', '4120', 'Fee Income', 'INCOME', 'credit', 3, 'INCOME_STATEMENT', 'Revenue', 'IFRS 15')
ON CONFLICT (tenant_id, code) DO NOTHING;

-- Expenses (5xxx)
INSERT INTO core.chart_of_accounts (tenant_id, code, name, type, normal_balance, level, financial_statement, statement_section, ifrs_reference) VALUES
('00000000-0000-0000-0000-000000000000', '5000', 'Expenses', 'EXPENSE', 'debit', 1, 'INCOME_STATEMENT', 'Expenses', 'IAS 1.82'),
('00000000-0000-0000-0000-000000000000', '5100', 'Operating Expenses', 'EXPENSE', 'debit', 2, 'INCOME_STATEMENT', 'Expenses', 'IAS 1.82'),
('00000000-0000-0000-0000-000000000000', '5110', 'Interest Expense', 'EXPENSE', 'debit', 3, 'INCOME_STATEMENT', 'Expenses', 'IFRS 9'),
('00000000-0000-0000-0000-000000000000', '5120', 'Provision for Credit Losses', 'EXPENSE', 'debit', 3, 'INCOME_STATEMENT', 'Expenses', 'IFRS 9')
ON CONFLICT (tenant_id, code) DO NOTHING;

-- Suspense (6xxx)
INSERT INTO core.chart_of_accounts (tenant_id, code, name, type, normal_balance, level, financial_statement, statement_section, ifrs_reference) VALUES
('00000000-0000-0000-0000-000000000000', '6000', 'Suspense Accounts', 'SUSPENSE', 'debit', 1, NULL, NULL, NULL),
('00000000-0000-0000-0000-000000000000', '6100', 'Unallocated Receipts', 'SUSPENSE', 'credit', 2, NULL, NULL, NULL),
('00000000-0000-0000-0000-000000000000', '6200', 'Pending Transfers', 'SUSPENSE', 'debit', 2, NULL, NULL, NULL)
ON CONFLICT (tenant_id, code) DO NOTHING;

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.chart_of_accounts TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.account_mappings TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.account_balances TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.trial_balances TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.trial_balance_details TO finos_app;
