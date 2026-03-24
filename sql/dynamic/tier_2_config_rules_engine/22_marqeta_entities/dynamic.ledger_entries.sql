-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.ledger_entries
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.ledger_entries (

    entry_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    journal_entry_id UUID REFERENCES dynamic.journal_entries(entry_id),
    
    -- Account Detail
    ledger_account_code VARCHAR(50) NOT NULL, -- e.g., '1200-CARD-RECEIVABLES'
    
    -- Amount
    amount DECIMAL(28,8) NOT NULL,
    currency CHAR(3) NOT NULL,
    debit_credit VARCHAR(6) NOT NULL,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.ledger_entries_default PARTITION OF dynamic.ledger_entries DEFAULT;

GRANT SELECT, INSERT, UPDATE ON dynamic.ledger_entries TO finos_app;