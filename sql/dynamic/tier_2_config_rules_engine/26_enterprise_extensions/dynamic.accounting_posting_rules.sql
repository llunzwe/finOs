-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Enterprise Extensions
-- TABLE: dynamic.accounting_posting_rules
--
-- DESCRIPTION:
--   Enterprise-grade accounting posting rules engine.
--   Full double-entry automation from business events to GL.
--
-- ============================================================================


CREATE TABLE dynamic.accounting_posting_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Event Trigger
    event_category VARCHAR(50) NOT NULL, -- 'TRANSACTION', 'INTEREST', 'FEE', 'TAX'
    event_type VARCHAR(100) NOT NULL, -- 'LOAN_DISBURSEMENT', 'DEPOSIT', 'WITHDRAWAL'
    event_sub_type VARCHAR(100),
    
    -- Product Filter
    applicable_product_types VARCHAR(50)[],
    applicable_product_ids UUID[],
    
    -- Double-Entry Mapping
    debit_account_rule TEXT NOT NULL, -- Account selection logic
    credit_account_rule TEXT NOT NULL,
    
    -- Alternative: Direct Account References
    debit_account_id UUID REFERENCES dynamic.gl_account_master(account_id),
    credit_account_id UUID REFERENCES dynamic.gl_account_master(account_id),
    
    -- Amount Calculation
    amount_source VARCHAR(50) DEFAULT 'TRANSACTION_AMOUNT', -- 'TRANSACTION_AMOUNT', 'FEE', 'PRINCIPAL', 'INTEREST'
    amount_multiplier DECIMAL(10,6) DEFAULT 1.0,
    amount_formula TEXT, -- SQL expression for complex calculations
    
    -- Conditions
    condition_expression TEXT, -- SQL WHERE clause
    min_amount DECIMAL(28,8),
    max_amount DECIMAL(28,8),
    
    -- Segmentation
    cost_center_source VARCHAR(100),
    profit_center_source VARCHAR(100),
    
    -- Posting Control
    posting_timing VARCHAR(50) DEFAULT 'IMMEDIATE',
    posting_batch_type VARCHAR(50),
    requires_approval BOOLEAN DEFAULT FALSE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    priority INTEGER DEFAULT 100,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_posting_rule_code UNIQUE (tenant_id, rule_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.accounting_posting_rules_default PARTITION OF dynamic.accounting_posting_rules DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_accounting_posting_tenant ON dynamic.accounting_posting_rules(tenant_id);
CREATE INDEX idx_accounting_posting_event ON dynamic.accounting_posting_rules(tenant_id, event_category, event_type);
CREATE INDEX idx_accounting_posting_active ON dynamic.accounting_posting_rules(tenant_id, is_active);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.accounting_posting_rules IS 'Accounting posting rules engine - full double-entry automation. Tier 2 - Enterprise Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.accounting_posting_rules TO finos_app;
