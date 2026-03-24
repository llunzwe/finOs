-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.statements
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.statements (

    statement_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    account_id UUID NOT NULL, -- Can be credit account, deposit, etc.
    account_type VARCHAR(30) NOT NULL,
    
    -- Statement Period
    statement_period_start DATE NOT NULL,
    statement_period_end DATE NOT NULL,
    
    -- Statement Data
    opening_balance DECIMAL(28,8) NOT NULL,
    closing_balance DECIMAL(28,8) NOT NULL,
    total_credits DECIMAL(28,8) DEFAULT 0,
    total_debits DECIMAL(28,8) DEFAULT 0,
    
    -- For Credit
    minimum_payment_due DECIMAL(28,8),
    payment_due_date DATE,
    
    -- Statement Document
    statement_template VARCHAR(100),
    statement_data JSONB DEFAULT '{}',
    generated_document_url TEXT,
    
    -- Delivery
    delivery_status VARCHAR(20) DEFAULT 'pending' 
        CHECK (delivery_status IN ('pending', 'generated', 'sent', 'failed')),
    delivered_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.statements_default PARTITION OF dynamic.statements DEFAULT;

-- Indexes
CREATE INDEX idx_statements_account ON dynamic.statements(tenant_id, account_id, statement_period_end DESC);

GRANT SELECT, INSERT, UPDATE ON dynamic.statements TO finos_app;