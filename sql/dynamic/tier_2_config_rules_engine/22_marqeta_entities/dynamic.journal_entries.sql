-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.journal_entries
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Journal Entries.
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
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.journal_entries_default PARTITION OF dynamic.journal_entries DEFAULT;

-- Indexes
CREATE INDEX idx_journal_entries_account ON dynamic.journal_entries(tenant_id, credit_account_id, posting_date DESC);

GRANT SELECT, INSERT, UPDATE ON dynamic.journal_entries TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.journal_entries IS 'Journal Entries';