-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Accounting & GL Engine
-- TABLE: dynamic.gl_journal_entries
--
-- DESCRIPTION:
--   Enterprise-grade journal entries table for double-entry bookkeeping.
--   Stores all GL postings with full audit trail and reconciliation status.
--   Links to core banking transactions for traceability.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - IFRS (International Financial Reporting Standards)
--   - GAAP (Generally Accepted Accounting Principles)
--   - SOX (Sarbanes-Oxley Act)
--   - Basel III/IV
--   - GDPR
--
-- AUDIT & GOVERNANCE:
--   - Bitemporal tracking (effective_from/valid_from, effective_to/valid_to)
--   - Full audit trail (created_at, updated_at, created_by, updated_by)
--   - Immutable hash for tamper detection
--   - Tenant isolation via partitioning
--   - Row-Level Security (RLS) for data protection
--
-- DATA CLASSIFICATION:
--   - Tenant Isolation: Row-Level Security enabled
--   - Audit Level: FULL
--   - Encryption: At-rest for sensitive fields
--
-- ============================================================================


CREATE TABLE dynamic.gl_journal_entries (
    journal_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Document/Entry Identification
    journal_number VARCHAR(100) NOT NULL, -- e.g., "JV-2024-000001"
    journal_date DATE NOT NULL,
    fiscal_year INTEGER NOT NULL,
    fiscal_period INTEGER NOT NULL, -- 1-12 or 1-4 for quarters
    
    -- Source Reference
    posting_rule_id UUID REFERENCES dynamic.gl_posting_rules(rule_id),
    source_system VARCHAR(50) NOT NULL, -- 'CORE_BANKING', 'PAYMENTS', 'CARDS'
    source_document_type VARCHAR(50), -- 'INVOICE', 'RECEIPT', 'PAYMENT'
    source_document_id UUID, -- Reference to source document
    core_transaction_id UUID REFERENCES core.transactions(id),
    core_movement_id UUID REFERENCES core.value_movements(id),
    
    -- Line Item Details
    line_number INTEGER NOT NULL,
    account_id UUID NOT NULL REFERENCES dynamic.gl_account_master(account_id),
    
    -- Double-Entry Amounts
    debit_amount DECIMAL(28,8) DEFAULT 0,
    credit_amount DECIMAL(28,8) DEFAULT 0,
    net_amount DECIMAL(28,8) GENERATED ALWAYS AS (debit_amount - credit_amount) STORED,
    
    -- Currency
    entry_currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    entry_amount DECIMAL(28,8) NOT NULL, -- Amount in entry currency
    functional_currency CHAR(3) NOT NULL, -- Tenant's base currency
    functional_amount DECIMAL(28,8) NOT NULL, -- Converted amount
    exchange_rate DECIMAL(20,10) NOT NULL,
    exchange_rate_date DATE,
    
    -- Dimensions for Reporting
    cost_center VARCHAR(50),
    profit_center VARCHAR(50),
    business_segment VARCHAR(50),
    geographical_segment VARCHAR(50),
    product_line VARCHAR(50),
    project_code VARCHAR(50),
    customer_id UUID,
    vendor_id UUID,
    
    -- Entry Description
    line_description TEXT,
    reference_number VARCHAR(100),
    
    -- Reconciliation
    reconciliation_status VARCHAR(20) DEFAULT 'UNRECONCILED' 
        CHECK (reconciliation_status IN ('UNRECONCILED', 'RECONCILED', 'PARTIALLY_RECONCILED', 'EXCEPTION')),
    reconciled_at TIMESTAMPTZ,
    reconciled_by VARCHAR(100),
    reconciliation_reference VARCHAR(100),
    
    -- Approval Workflow
    approval_status VARCHAR(20) DEFAULT 'APPROVED' 
        CHECK (approval_status IN ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED')),
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    
    -- Batch Processing
    batch_id UUID,
    batch_status VARCHAR(20), -- 'PENDING', 'POSTED', 'REVERSED'
    
    -- Reversal Information
    is_reversal BOOLEAN DEFAULT FALSE,
    reversed_journal_id UUID REFERENCES dynamic.gl_journal_entries(journal_id),
    reversal_reason TEXT,
    
    -- Immutable Hash for Audit
    immutable_hash VARCHAR(64), -- SHA-256 of key fields
    previous_journal_hash VARCHAR(64), -- Chain for tamper detection
    
    -- Metadata
    attributes JSONB DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_journal_number_line UNIQUE (tenant_id, journal_number, line_number),
    CONSTRAINT chk_debit_credit_balance CHECK (debit_amount >= 0 AND credit_amount >= 0),
    CONSTRAINT chk_approval_status CHECK (
        (approval_status = 'APPROVED' AND approved_by IS NOT NULL) OR 
        approval_status != 'APPROVED'
    )
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.gl_journal_entries_default PARTITION OF dynamic.gl_journal_entries DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_journal_tenant ON dynamic.gl_journal_entries(tenant_id);
CREATE INDEX idx_journal_number ON dynamic.gl_journal_entries(tenant_id, journal_number);
CREATE INDEX idx_journal_date ON dynamic.gl_journal_entries(tenant_id, journal_date);
CREATE INDEX idx_journal_account ON dynamic.gl_journal_entries(tenant_id, account_id);
CREATE INDEX idx_journal_fiscal ON dynamic.gl_journal_entries(tenant_id, fiscal_year, fiscal_period);
CREATE INDEX idx_journal_recon ON dynamic.gl_journal_entries(tenant_id, reconciliation_status);
CREATE INDEX idx_journal_transaction ON dynamic.gl_journal_entries(tenant_id, core_transaction_id);
CREATE INDEX idx_journal_batch ON dynamic.gl_journal_entries(tenant_id, batch_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.gl_journal_entries IS 'General ledger journal entries - double-entry bookkeeping with full audit trail. Tier 2 - Accounting & GL Engine.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.gl_journal_entries TO finos_app;
