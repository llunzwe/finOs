-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 06 - Accounting Financial Control
-- TABLE: dynamic.coa_mapping_rules
-- COMPLIANCE: IFRS 9
--   - IFRS 15
--   - SOX 404
--   - FCA CASS
-- ============================================================================


CREATE TABLE dynamic.coa_mapping_rules (

    mapping_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    mapping_name VARCHAR(200) NOT NULL,
    mapping_description TEXT,
    
    -- Product Scope
    product_id UUID REFERENCES dynamic.product_template_master(product_id),
    product_category_id UUID REFERENCES dynamic.product_category(category_id),
    all_products BOOLEAN DEFAULT FALSE,
    
    -- Event Trigger
    accounting_event VARCHAR(100) NOT NULL, -- DISBURSEMENT, REPAYMENT, INTEREST_ACCRUAL, etc.
    movement_type VARCHAR(50), -- DEBIT, CREDIT context
    
    -- GL Accounts
    debit_account_code VARCHAR(50) NOT NULL,
    credit_account_code VARCHAR(50) NOT NULL,
    
    -- Posting Sequence
    posting_sequence INTEGER DEFAULT 0,
    posting_description_template TEXT,
    
    -- Multi-dimensional Segments
    segment_1 VARCHAR(50), -- Business Unit
    segment_2 VARCHAR(50), -- Product Line
    segment_3 VARCHAR(50), -- Geography
    segment_4 VARCHAR(50), -- Channel
    segment_5 VARCHAR(50), -- Cost Center
    segment_6 VARCHAR(50), -- Project
    segment_7 VARCHAR(50), -- Intercompany
    segment_8 VARCHAR(50), -- Custom
    
    -- Intercompany
    intercompany_flag BOOLEAN DEFAULT FALSE,
    counterparty_entity_code VARCHAR(50),
    
    -- Elimination
    elimination_flag BOOLEAN DEFAULT FALSE,
    elimination_group VARCHAR(50),
    
    -- Conditions
    condition_expression TEXT, -- SQL condition for applicability
    min_amount DECIMAL(28,8),
    max_amount DECIMAL(28,8),
    applicable_currencies CHAR(3)[],
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    priority INTEGER DEFAULT 0,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.coa_mapping_rules_default PARTITION OF dynamic.coa_mapping_rules DEFAULT;

-- Indexes
CREATE INDEX idx_coa_mapping_tenant ON dynamic.coa_mapping_rules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_coa_mapping_product ON dynamic.coa_mapping_rules(tenant_id, product_id) WHERE is_active = TRUE;
CREATE INDEX idx_coa_mapping_event ON dynamic.coa_mapping_rules(tenant_id, accounting_event) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.coa_mapping_rules IS 'Product to General Ledger account mapping rules';

-- Triggers
CREATE TRIGGER trg_coa_mapping_rules_audit
    BEFORE UPDATE ON dynamic.coa_mapping_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.coa_mapping_rules TO finos_app;