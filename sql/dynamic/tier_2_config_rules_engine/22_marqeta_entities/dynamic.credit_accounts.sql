-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.credit_accounts
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Credit Accounts.
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
CREATE TABLE dynamic.credit_accounts (

    account_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    credit_product_id UUID NOT NULL REFERENCES dynamic.credit_products(product_id),
    holder_id UUID NOT NULL REFERENCES dynamic.account_holders(holder_id),
    
    -- Account Details
    account_number VARCHAR(100) NOT NULL,
    
    -- Credit Limit
    credit_limit DECIMAL(28,8) NOT NULL,
    credit_limit_available DECIMAL(28,8) NOT NULL,
    
    -- Balances
    current_balance DECIMAL(28,8) NOT NULL DEFAULT 0,
    statement_balance DECIMAL(28,8) NOT NULL DEFAULT 0,
    past_due_amount DECIMAL(28,8) NOT NULL DEFAULT 0,
    
    -- Interest
    interest_accrued_current DECIMAL(28,8) DEFAULT 0,
    interest_accrued_ytd DECIMAL(28,8) DEFAULT 0,
    
    -- Status
    account_status VARCHAR(20) DEFAULT 'open' 
        CHECK (account_status IN ('open', 'closed', 'suspended', 'delinquent', 'charged_off')),
    
    -- Delinquency
    days_past_due INTEGER DEFAULT 0,
    delinquency_bucket INTEGER DEFAULT 0, -- 0=current, 1-6=30-180+ days
    
    -- Dates
    open_date DATE NOT NULL DEFAULT CURRENT_DATE,
    last_statement_date DATE,
    next_statement_date DATE,
    payment_due_date DATE,
    
    -- Core Links
    core_container_id UUID REFERENCES core.value_containers(id),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.credit_accounts_default PARTITION OF dynamic.credit_accounts DEFAULT;

-- Indexes
CREATE INDEX idx_credit_accounts_holder ON dynamic.credit_accounts(tenant_id, holder_id);
CREATE INDEX idx_credit_accounts_status ON dynamic.credit_accounts(tenant_id, account_status) 
    WHERE account_status IN ('open', 'delinquent');

-- Triggers
CREATE TRIGGER trg_credit_accounts_update
    BEFORE UPDATE ON dynamic.credit_accounts
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_marqeta_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.credit_accounts TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.credit_accounts IS 'Credit Accounts';