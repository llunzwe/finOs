-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 14 - Rules Engines
-- TABLE: dynamic.accounting_rules
-- COMPLIANCE: Basel
--   - IFRS
--   - GDPR
--   - SOX
-- ============================================================================


CREATE TABLE dynamic.accounting_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Event Trigger
    event_type VARCHAR(100) NOT NULL, -- VALUE_MOVEMENT_CREATED, INTEREST_ACCRUED, FEE_CHARGED, etc.
    event_sub_type VARCHAR(100),
    
    -- Product Scope
    product_id UUID REFERENCES dynamic.product_template_master(product_id),
    product_category_id UUID REFERENCES dynamic.product_category(category_id),
    all_products BOOLEAN DEFAULT FALSE,
    
    -- GL Accounts
    debit_account_code VARCHAR(50) NOT NULL,
    credit_account_code VARCHAR(50) NOT NULL,
    
    -- Multi-dimensional Segments
    segment_1 VARCHAR(50), -- Business Unit
    segment_2 VARCHAR(50), -- Product Line
    segment_3 VARCHAR(50), -- Geography
    segment_4 VARCHAR(50), -- Channel
    segment_5 VARCHAR(50), -- Cost Center
    segment_6 VARCHAR(50), -- Project
    segment_7 VARCHAR(50), -- Intercompany
    segment_8 VARCHAR(50), -- Custom
    
    -- Conditions
    condition_expression JSONB, -- JSONLogic or custom DSL
    min_amount DECIMAL(28,8),
    max_amount DECIMAL(28,8),
    applicable_currencies CHAR(3)[],
    
    -- Posting Logic
    posting_sequence INTEGER DEFAULT 0,
    posting_description_template TEXT,
    
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
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_accounting_rule_code UNIQUE (tenant_id, rule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.accounting_rules_default PARTITION OF dynamic.accounting_rules DEFAULT;

-- Indexes
CREATE INDEX idx_accounting_rules_tenant ON dynamic.accounting_rules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_accounting_rules_event ON dynamic.accounting_rules(tenant_id, event_type) WHERE is_active = TRUE;
CREATE INDEX idx_accounting_rules_product ON dynamic.accounting_rules(tenant_id, product_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.accounting_rules IS 'Event to GL mapping rules for automated double-entry posting';

-- Triggers
CREATE TRIGGER trg_accounting_rules_audit
    BEFORE UPDATE ON dynamic.accounting_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.accounting_rules TO finos_app;