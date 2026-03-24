-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.journal_entries
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.journal_entries (

    entry_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    credit_account_id UUID NOT NULL REFERENCES dynamic.credit_accounts(account_id),
    
    -- Entry Details
    entry_type VARCHAR(50) NOT NULL 
        CHECK (entry_type IN ('purchase', 'payment', 'fee', 'interest', 'adjustment', 'refund', 'chargeback')),
    
    -- Amounts
    amount DECIMAL(28,8) NOT NULL,
    currency CHAR(3) NOT NULL,
    
    -- Direction
    debit_credit VARCHAR(6) NOT NULL CHECK (debit_credit IN ('debit', 'credit')),
    
    -- Description
    description TEXT,
    reference_number VARCHAR(100),
    
    -- Linked Transaction
    original_transaction_id UUID,
    core_movement_id UUID REFERENCES core.value_movements(id),
    
    -- Posting Date
    posting_date DATE NOT NULL,
    effective_date DATE NOT NULL,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.journal_entries_default PARTITION OF dynamic.journal_entries DEFAULT;

-- Indexes
CREATE INDEX idx_journal_entries_account ON dynamic.journal_entries(tenant_id, credit_account_id, posting_date DESC);

GRANT SELECT, INSERT, UPDATE ON dynamic.journal_entries TO finos_app;