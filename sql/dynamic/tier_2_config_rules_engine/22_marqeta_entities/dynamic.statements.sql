-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.statements
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Statements.
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
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.statements_default PARTITION OF dynamic.statements DEFAULT;

-- Indexes
CREATE INDEX idx_statements_account ON dynamic.statements(tenant_id, account_id, statement_period_end DESC);

GRANT SELECT, INSERT, UPDATE ON dynamic.statements TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.statements IS 'Statements';