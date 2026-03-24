-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 06 - Accounting Financial Control
-- TABLE: dynamic.sub_ledger_posting_rules
-- COMPLIANCE: IFRS 9
--   - IFRS 15
--   - SOX 404
--   - FCA CASS
-- ============================================================================


CREATE TABLE dynamic.sub_ledger_posting_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    sub_ledger_id UUID NOT NULL REFERENCES dynamic.sub_ledger_definition(sub_ledger_id),
    
    rule_name VARCHAR(200) NOT NULL,
    
    -- Transaction Filter
    transaction_type VARCHAR(100) NOT NULL,
    product_id UUID REFERENCES dynamic.product_template_master(product_id),
    
    -- Grouping
    grouping_criteria VARCHAR(50) DEFAULT 'BY_CLIENT' 
        CHECK (grouping_criteria IN ('BY_CLIENT', 'BY_DATE', 'BY_PRODUCT', 'BY_CURRENCY', 'NONE')),
    
    -- Posting Frequency
    posting_frequency VARCHAR(20) DEFAULT 'REALTIME' 
        CHECK (posting_frequency IN ('REALTIME', 'END_OF_DAY', 'END_OF_WEEK', 'END_OF_MONTH')),
    
    -- GL Mapping
    debit_account_code VARCHAR(50) NOT NULL,
    credit_account_code VARCHAR(50) NOT NULL,
    
    -- Conditions
    min_amount DECIMAL(28,8),
    condition_expression TEXT,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.sub_ledger_posting_rules_default PARTITION OF dynamic.sub_ledger_posting_rules DEFAULT;

-- Indexes
CREATE INDEX idx_sub_ledger_rules_sub ON dynamic.sub_ledger_posting_rules(tenant_id, sub_ledger_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.sub_ledger_posting_rules IS 'Sub-ledger to GL aggregation and posting rules';

GRANT SELECT, INSERT, UPDATE ON dynamic.sub_ledger_posting_rules TO finos_app;