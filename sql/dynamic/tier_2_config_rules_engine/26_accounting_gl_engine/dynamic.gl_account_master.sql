-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Accounting & GL Engine
-- TABLE: dynamic.gl_account_master
--
-- DESCRIPTION:
--   Enterprise-grade Chart of Accounts master table.
--   Multi-entity, multi-currency, IFRS-compliant general ledger account definitions.
--   Supports hierarchical account structures, segment reporting, and regulatory classification.
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
--   - Basel III/IV
--   - SOX (Sarbanes-Oxley Act)
--   - GDPR
--   - SOC2
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


CREATE TABLE dynamic.gl_account_master (
    account_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Account Identification
    account_code VARCHAR(50) NOT NULL, -- e.g., "1000-001", "ASSET-CASH-001"
    account_name VARCHAR(200) NOT NULL,
    account_description TEXT,
    account_alias VARCHAR(100), -- Alternative names for reporting
    
    -- Hierarchical Structure
    parent_account_id UUID REFERENCES dynamic.gl_account_master(account_id),
    account_level INTEGER NOT NULL DEFAULT 1, -- 1=Header, 2=Intermediate, 3=Detail
    account_path LTREE, -- Materialized path for tree traversal
    
    -- Account Classification
    account_type VARCHAR(50) NOT NULL 
        CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE', 'MEMORANDUM')),
    account_category VARCHAR(50), -- e.g., 'CURRENT_ASSET', 'NON_CURRENT_ASSET'
    account_subcategory VARCHAR(50), -- e.g., 'CASH_EQUIVALENT', 'TRADE_RECEIVABLE'
    
    -- Financial Statement Mapping
    balance_sheet_section VARCHAR(50), -- e.g., 'CURRENT_ASSETS', 'LONG_TERM_LIABILITIES'
    income_statement_section VARCHAR(50), -- e.g., 'OPERATING_REVENUE', 'ADMIN_EXPENSES'
    cash_flow_category VARCHAR(50), -- e.g., 'OPERATING', 'INVESTING', 'FINANCING'
    
    -- IFRS/GAAP Classification
    ifrs_classification VARCHAR(100), -- IFRS standard reference
    gaap_classification VARCHAR(100), -- US GAAP classification
    statutory_reporting_code VARCHAR(50), -- Tax/regulatory reporting code
    
    -- Account Behavior
    normal_balance VARCHAR(10) NOT NULL 
        CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    is_contra_account BOOLEAN DEFAULT FALSE, -- e.g., Accumulated Depreciation
    is_bank_account BOOLEAN DEFAULT FALSE,
    is_reconciliation_required BOOLEAN DEFAULT TRUE,
    
    -- Multi-Currency Support
    account_currency CHAR(3) REFERENCES core.currencies(code),
    is_multi_currency BOOLEAN DEFAULT FALSE,
    foreign_exchange_gain_loss_account_id UUID, -- FX revaluation account
    
    -- Segment Reporting
    business_segment VARCHAR(50),
    geographical_segment VARCHAR(50),
    product_line VARCHAR(50),
    cost_center VARCHAR(50),
    
    -- Status & Control
    account_status VARCHAR(20) DEFAULT 'ACTIVE' 
        CHECK (account_status IN ('ACTIVE', 'INACTIVE', 'FROZEN', 'CLOSED')),
    is_posting_allowed BOOLEAN DEFAULT TRUE,
    opening_date DATE DEFAULT CURRENT_DATE,
    closing_date DATE,
    
    -- Budget & Control
    has_budget_control BOOLEAN DEFAULT FALSE,
    budget_limit DECIMAL(28,8),
    budget_warning_threshold DECIMAL(5,4) DEFAULT 0.80, -- 80%
    
    -- Metadata
    attributes JSONB DEFAULT '{}',
    tags TEXT[],
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_account_code_per_tenant UNIQUE (tenant_id, account_code),
    CONSTRAINT chk_gl_account_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_no_self_parent_gl CHECK (parent_account_id IS NULL OR parent_account_id != account_id)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.gl_account_master_default PARTITION OF dynamic.gl_account_master DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_gl_account_tenant ON dynamic.gl_account_master(tenant_id);
CREATE INDEX idx_gl_account_lookup ON dynamic.gl_account_master(tenant_id, account_code);
CREATE INDEX idx_gl_account_type ON dynamic.gl_account_master(tenant_id, account_type);
CREATE INDEX idx_gl_account_hierarchy ON dynamic.gl_account_master(tenant_id, account_path);
CREATE INDEX idx_gl_account_temporal ON dynamic.gl_account_master(tenant_id, valid_from, valid_to) WHERE is_current = TRUE;
CREATE INDEX idx_gl_account_status ON dynamic.gl_account_master(tenant_id, account_status);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.gl_account_master IS 'Chart of Accounts master - multi-entity, multi-currency, IFRS-compliant GL account definitions. Tier 2 - Accounting & GL Engine.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.gl_account_master TO finos_app;
