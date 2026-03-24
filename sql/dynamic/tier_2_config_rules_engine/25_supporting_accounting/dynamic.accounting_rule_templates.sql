-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 25 - Supporting Accounting
-- TABLE: dynamic.accounting_rule_templates
-- COMPLIANCE: IFRS
--   - SOX
--   - CASS
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.accounting_rule_templates (

    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    
    -- Template Category
    category VARCHAR(50) NOT NULL 
        CHECK (category IN ('LOAN', 'DEPOSIT', 'CARD', 'PAYMENT', 'INVESTMENT', 'INSURANCE', 'GENERAL')),
    
    -- The Rules
    event_type VARCHAR(50) NOT NULL,
    debit_account_rules JSONB NOT NULL DEFAULT '{}',
    credit_account_rules JSONB NOT NULL DEFAULT '{}',
    additional_legs JSONB DEFAULT '[]',
    
    -- Sample Data
    example_transaction JSONB,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.accounting_rule_templates_default PARTITION OF dynamic.accounting_rule_templates DEFAULT;

-- Indexes
CREATE INDEX idx_accounting_templates_category ON dynamic.accounting_rule_templates(tenant_id, category);

-- Triggers
CREATE TRIGGER trg_accounting_templates_update
    BEFORE UPDATE ON dynamic.accounting_rule_templates
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_supporting_accounting_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.accounting_rule_templates TO finos_app;