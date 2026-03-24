-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 06 - Accounting Financial Control
-- TABLE: dynamic.coa_account_master
-- COMPLIANCE: IFRS 9
--   - IFRS 15
--   - SOX 404
--   - FCA CASS
-- ============================================================================


CREATE TABLE dynamic.coa_account_master (

    account_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Account Identification
    account_code VARCHAR(50) NOT NULL,
    account_name VARCHAR(200) NOT NULL,
    account_description TEXT,
    
    -- Classification
    account_type VARCHAR(20) NOT NULL 
        CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE', 'MEMO', 'OFF_BALANCE')),
    account_subtype VARCHAR(50),
    
    -- Reporting Categories
    statutory_reporting_category VARCHAR(100),
    management_reporting_category VARCHAR(100),
    regulatory_reporting_category VARCHAR(100),
    
    -- Currency
    currency_code CHAR(3) REFERENCES core.currencies(code),
    is_monetary BOOLEAN DEFAULT TRUE,
    
    -- Balance
    balance_type VARCHAR(10) DEFAULT 'DEBIT' CHECK (balance_type IN ('DEBIT', 'CREDIT')),
    
    -- Hierarchy
    parent_account_code VARCHAR(50) REFERENCES dynamic.coa_account_master(account_code),
    account_level INTEGER DEFAULT 1,
    is_leaf BOOLEAN DEFAULT TRUE,
    
    -- Status
    active_status BOOLEAN DEFAULT TRUE,
    open_date DATE DEFAULT CURRENT_DATE,
    close_date DATE,
    
    -- Attributes
    attributes JSONB DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_account_code UNIQUE (tenant_id, account_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.coa_account_master_default PARTITION OF dynamic.coa_account_master DEFAULT;

-- Indexes
CREATE INDEX idx_coa_account_tenant ON dynamic.coa_account_master(tenant_id) WHERE active_status = TRUE;
CREATE INDEX idx_coa_account_type ON dynamic.coa_account_master(tenant_id, account_type) WHERE active_status = TRUE;
CREATE INDEX idx_coa_account_lookup ON dynamic.coa_account_master(tenant_id, account_code) WHERE active_status = TRUE;

-- Comments
COMMENT ON TABLE dynamic.coa_account_master IS 'Dynamic Chart of Accounts with multi-dimensional reporting';

-- Triggers
CREATE TRIGGER trg_coa_account_master_audit
    BEFORE UPDATE ON dynamic.coa_account_master
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.coa_account_master TO finos_app;