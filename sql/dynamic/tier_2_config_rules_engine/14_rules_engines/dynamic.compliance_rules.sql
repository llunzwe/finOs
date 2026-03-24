-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 14 - Rules Engines
-- TABLE: dynamic.compliance_rules
-- COMPLIANCE: Basel
--   - IFRS
--   - GDPR
--   - SOX
-- ============================================================================


CREATE TABLE dynamic.compliance_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Regulatory Framework
    regulation_code VARCHAR(50) NOT NULL, -- BASEL_III, IFRS9, IFRS15, POPIA, GDPR, FATCA, CRS, etc.
    regulatory_authority dynamic.regulatory_authority,
    compliance_domain VARCHAR(50) NOT NULL 
        CHECK (compliance_domain IN ('CAPITAL_ADEQUACY', 'LIQUIDITY', 'CONDUCT', 'CONSUMER_PROTECTION', 'DATA_PRIVACY', 'AML', 'MARKET_ABUSE', 'REPORTING')),
    
    -- Rule Logic
    condition_expression JSONB NOT NULL, -- JSONLogic condition
    rule_logic TEXT, -- Additional Lua/SQL logic
    
    -- Thresholds
    warning_threshold DECIMAL(28,8),
    breach_threshold DECIMAL(28,8),
    
    -- Applicability
    applicable_entity_types VARCHAR(50)[], -- PRODUCT, CUSTOMER, TRANSACTION, ACCOUNT
    applicable_product_categories UUID[],
    
    -- Actions
    warning_action VARCHAR(50) DEFAULT 'NOTIFY',
    breach_action VARCHAR(50) DEFAULT 'ESCALATE',
    action_recipients TEXT[], -- Email addresses or role codes
    
    -- Reporting
    report_in_regulatory_filing BOOLEAN DEFAULT TRUE,
    report_field_mapping JSONB, -- Maps to specific report fields
    
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
    
    CONSTRAINT unique_compliance_rule_code UNIQUE (tenant_id, rule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.compliance_rules_default PARTITION OF dynamic.compliance_rules DEFAULT;

-- Indexes
CREATE INDEX idx_compliance_rules_tenant ON dynamic.compliance_rules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_compliance_rules_regulation ON dynamic.compliance_rules(tenant_id, regulation_code) WHERE is_active = TRUE;
CREATE INDEX idx_compliance_rules_domain ON dynamic.compliance_rules(tenant_id, compliance_domain) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.compliance_rules IS 'Regulatory compliance rules for Basel, IFRS, POPIA, GDPR, etc.';

-- Triggers
CREATE TRIGGER trg_compliance_rules_audit
    BEFORE UPDATE ON dynamic.compliance_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.compliance_rules TO finos_app;