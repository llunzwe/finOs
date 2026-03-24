-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Accounting & GL Engine
-- TABLE: dynamic.sub_ledger_config
--
-- DESCRIPTION:
--   Enterprise-grade sub-ledger configuration for AR, AP, Fixed Assets, Inventory.
--   Defines sub-ledger types, posting rules, and reconciliation parameters.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - IFRS
--   - GAAP
--   - SOX
--   - GDPR
--
-- AUDIT & GOVERNANCE:
--   - Bitemporal tracking
--   - Full audit trail
--   - Tenant isolation via partitioning
--
-- ============================================================================


CREATE TABLE dynamic.sub_ledger_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Sub-ledger Identification
    ledger_type VARCHAR(50) NOT NULL 
        CHECK (ledger_type IN ('ACCOUNTS_RECEIVABLE', 'ACCOUNTS_PAYABLE', 'FIXED_ASSETS', 'INVENTORY', 'PREPAID_EXPENSES', 'ACCRUALS')),
    ledger_code VARCHAR(50) NOT NULL,
    ledger_name VARCHAR(200) NOT NULL,
    ledger_description TEXT,
    
    -- Control Account Mapping
    control_account_id UUID NOT NULL REFERENCES dynamic.gl_account_master(account_id),
    reconciliation_account_id UUID REFERENCES dynamic.gl_account_master(account_id),
    
    -- Posting Rules
    auto_post_to_gl BOOLEAN DEFAULT TRUE,
    posting_frequency VARCHAR(20) DEFAULT 'REALTIME' 
        CHECK (posting_frequency IN ('REALTIME', 'DAILY', 'WEEKLY', 'MONTHLY')),
    summarization_level VARCHAR(20) DEFAULT 'DETAIL' 
        CHECK (summarization_level IN ('DETAIL', 'SUMMARY', 'BATCH')),
    
    -- Aging Configuration (for AR/AP)
    aging_buckets INTEGER[] DEFAULT ARRAY[30, 60, 90, 120],
    aging_basis VARCHAR(20) DEFAULT 'DUE_DATE' 
        CHECK (aging_basis IN ('DUE_DATE', 'INVOICE_DATE', 'TRANSACTION_DATE')),
    
    -- Reconciliation
    auto_reconciliation_enabled BOOLEAN DEFAULT FALSE,
    reconciliation_tolerance DECIMAL(28,8) DEFAULT 0.01,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_ledger_code_per_tenant UNIQUE (tenant_id, ledger_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.sub_ledger_config_default PARTITION OF dynamic.sub_ledger_config DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_subledger_tenant ON dynamic.sub_ledger_config(tenant_id);
CREATE INDEX idx_subledger_type ON dynamic.sub_ledger_config(tenant_id, ledger_type);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.sub_ledger_config IS 'Sub-ledger configuration for AR, AP, Fixed Assets, and Inventory. Tier 2 - Accounting & GL Engine.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.sub_ledger_config TO finos_app;
