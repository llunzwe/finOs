-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 48: Hedge Accounting (IFRS 9)
-- Table: hedge_accounting_entries
-- Description: Journal entries for hedge accounting - ineffective portion,
--              OCI recycling, basis adjustments, and reclassifications
-- Compliance: IFRS 9 (2014), IAS 1 Presentation of Financial Statements
-- ================================================================================

CREATE TABLE dynamic.hedge_accounting_entries (
    -- Primary Identity
    entry_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Hedge Reference
    hedge_id UUID NOT NULL REFERENCES dynamic.hedge_designation(hedge_id),
    
    -- Entry Identification
    entry_reference VARCHAR(100) NOT NULL,
    accounting_date DATE NOT NULL,
    entry_type VARCHAR(100) NOT NULL CHECK (entry_type IN (
        'EFFECTIVE_PORTION_OCI', 'INEFFECTIVE_PORTION_PNL',
        'BASIS_ADJUSTMENT', 'OCI_RECYCLING',
        'HEDGE_TERMINATION', 'REBALANCING_ADJUSTMENT',
        'DISCONTINUATION_TRANSFER', 'FORECAST_TRANSACTION_REALIZED'
    )),
    
    -- Amounts
    amount DECIMAL(28,8) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    
    -- Accounting Treatment
    debit_account_id UUID NOT NULL REFERENCES dynamic.gl_account_master(account_id),
    credit_account_id UUID NOT NULL REFERENCES dynamic.gl_account_master(account_id),
    
    -- P&L Impact
    pnl_impact DECIMAL(28,8),
    oci_impact DECIMAL(28,8),
    balance_sheet_impact DECIMAL(28,8),
    
    -- For Cash Flow Hedges - OCI Tracking
    oci_recycling_event VARCHAR(100), -- When OCI is recycled to P&L
    forecast_transaction_date DATE, -- Expected date of forecast transaction
    actual_transaction_id UUID, -- Link to actual transaction when realized
    
    -- Supporting Information
    calculation_basis JSONB,
    supporting_calculation_ref VARCHAR(255),
    
    -- Journal Status
    posted_to_gl BOOLEAN DEFAULT FALSE,
    gl_journal_entry_id UUID,
    posted_at TIMESTAMPTZ,
    posted_by VARCHAR(100),
    
    -- Reversal (if needed)
    reversed BOOLEAN DEFAULT FALSE,
    reversal_of_entry_id UUID REFERENCES dynamic.hedge_accounting_entries(entry_id),
    reversal_reason TEXT,
    
    -- Partitioning
    partition_key DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_entry_ref_per_tenant UNIQUE (tenant_id, entry_reference)
) PARTITION BY RANGE (partition_key);

-- Default partition
CREATE TABLE dynamic.hedge_accounting_entries_default PARTITION OF dynamic.hedge_accounting_entries
    DEFAULT;

-- Monthly partitions
CREATE TABLE dynamic.hedge_accounting_entries_2025_01 PARTITION OF dynamic.hedge_accounting_entries
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.hedge_accounting_entries_2025_02 PARTITION OF dynamic.hedge_accounting_entries
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Indexes
CREATE INDEX idx_hedge_entries_hedge ON dynamic.hedge_accounting_entries (tenant_id, hedge_id, accounting_date);
CREATE INDEX idx_hedge_entries_type ON dynamic.hedge_accounting_entries (tenant_id, entry_type);
CREATE INDEX idx_hedge_entries_date ON dynamic.hedge_accounting_entries (tenant_id, accounting_date);
CREATE INDEX idx_hedge_entries_gl ON dynamic.hedge_accounting_entries (tenant_id, posted_to_gl) WHERE posted_to_gl = FALSE;
CREATE INDEX idx_hedge_entries_oci ON dynamic.hedge_accounting_entries (tenant_id, oci_impact) WHERE oci_impact IS NOT NULL AND oci_impact != 0;

-- Comments
COMMENT ON TABLE dynamic.hedge_accounting_entries IS 'Journal entries for hedge accounting - OCI, ineffective portion, basis adjustments';
COMMENT ON COLUMN dynamic.hedge_accounting_entries.entry_type IS 'Type of hedge accounting entry per IFRS 9';
COMMENT ON COLUMN dynamic.hedge_accounting_entries.oci_recycling_event IS 'Event triggering OCI recycling to P&L (e.g., transaction realization)';

-- RLS
ALTER TABLE dynamic.hedge_accounting_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY hedge_accounting_entries_tenant_isolation ON dynamic.hedge_accounting_entries
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.hedge_accounting_entries TO finos_app_user;
GRANT SELECT ON dynamic.hedge_accounting_entries TO finos_readonly_user;
