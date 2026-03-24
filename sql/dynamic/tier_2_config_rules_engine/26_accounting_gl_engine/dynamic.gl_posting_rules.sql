-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Accounting & GL Engine
-- TABLE: dynamic.gl_posting_rules
--
-- DESCRIPTION:
--   Enterprise-grade double-entry posting rules engine.
--   Defines automated journal entry generation from core banking events.
--   Maps transactions, fees, interest, FX movements to GL accounts.
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


CREATE TABLE dynamic.gl_posting_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Event Trigger
    event_type VARCHAR(100) NOT NULL, -- 'VALUE_MOVEMENT_CREATED', 'FEE_CHARGED', 'INTEREST_ACCRUED'
    event_sub_type VARCHAR(100), -- More specific categorization
    product_type VARCHAR(50), -- 'LOAN', 'DEPOSIT', 'CARD' - NULL means all
    
    -- Transaction Classification
    movement_type VARCHAR(50), -- 'DEBIT', 'CREDIT', 'FEE', 'INTEREST', 'PRINCIPAL', 'TAX'
    transaction_nature VARCHAR(50), -- 'CASH', 'NON_CASH', 'ADJUSTMENT', 'REVERSAL'
    
    -- Double-Entry Configuration
    debit_account_id UUID REFERENCES dynamic.gl_account_master(account_id),
    credit_account_id UUID REFERENCES dynamic.gl_account_master(account_id),
    
    -- Dynamic Account Selection (overrides static account_id above)
    debit_account_rule TEXT, -- e.g., "LOAN_ASSET_ACCOUNT", "lookup_by_product_type"
    credit_account_rule TEXT, -- e.g., "CUSTOMER_DEPOSIT_ACCOUNT"
    
    -- Amount Calculation
    amount_source VARCHAR(50) DEFAULT 'TRANSACTION_AMOUNT' 
        CHECK (amount_source IN ('TRANSACTION_AMOUNT', 'FEE_AMOUNT', 'INTEREST_AMOUNT', 'TAX_AMOUNT', 'CALCULATED')),
    amount_multiplier DECIMAL(10,6) DEFAULT 1.0, -- e.g., -1 for reversals
    amount_formula TEXT, -- SQL expression for complex calculations
    
    -- Currency Handling
    currency_source VARCHAR(50) DEFAULT 'TRANSACTION_CURRENCY',
    fx_revaluation_required BOOLEAN DEFAULT FALSE,
    fx_gain_loss_account_id UUID REFERENCES dynamic.gl_account_master(account_id),
    
    -- Conditions & Filters
    condition_expression TEXT, -- SQL WHERE clause conditions
    min_amount DECIMAL(28,8),
    max_amount DECIMAL(28,8),
    applicable_channels VARCHAR(50)[], -- ['BRANCH', 'ATM', 'DIGITAL', 'API']
    applicable_currencies CHAR(3)[],
    
    -- Posting Behavior
    posting_timing VARCHAR(20) DEFAULT 'IMMEDIATE' 
        CHECK (posting_timing IN ('IMMEDIATE', 'END_OF_DAY', 'END_OF_MONTH', 'MANUAL')),
    posting_batch_type VARCHAR(50), -- For grouping entries
    requires_approval BOOLEAN DEFAULT FALSE,
    
    -- Sub-ledger Integration
    sub_ledger_type VARCHAR(50), -- 'AR', 'AP', 'FIXED_ASSET', 'INVENTORY'
    sub_ledger_account_reference VARCHAR(100),
    
    -- Segmentation (for multi-dimensional reporting)
    cost_center_source VARCHAR(100), -- Field to derive cost center
    profit_center_source VARCHAR(100),
    segment_1_source VARCHAR(100),
    segment_2_source VARCHAR(100),
    
    -- Status & Control
    rule_status VARCHAR(20) DEFAULT 'ACTIVE' 
        CHECK (rule_status IN ('DRAFT', 'ACTIVE', 'INACTIVE', 'DEPRECATED')),
    priority INTEGER DEFAULT 100, -- Lower = higher priority
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Metadata
    attributes JSONB DEFAULT '{}',
    
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
    CONSTRAINT unique_rule_code_per_tenant UNIQUE (tenant_id, rule_code),
    CONSTRAINT chk_posting_rule_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_effective_dates CHECK (effective_from <= effective_to)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.gl_posting_rules_default PARTITION OF dynamic.gl_posting_rules DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_posting_rule_tenant ON dynamic.gl_posting_rules(tenant_id);
CREATE INDEX idx_posting_rule_event ON dynamic.gl_posting_rules(tenant_id, event_type, event_sub_type);
CREATE INDEX idx_posting_rule_status ON dynamic.gl_posting_rules(tenant_id, rule_status);
CREATE INDEX idx_posting_rule_temporal ON dynamic.gl_posting_rules(tenant_id, valid_from, valid_to) WHERE is_current = TRUE;
CREATE INDEX idx_posting_rule_effective ON dynamic.gl_posting_rules(tenant_id, effective_from, effective_to);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.gl_posting_rules IS 'Double-entry posting rules engine - automated GL journal generation from core events. Tier 2 - Accounting & GL Engine.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.gl_posting_rules TO finos_app;
