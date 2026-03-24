-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 14 - Rules Engines
-- TABLE: dynamic.underwriting_rules
-- COMPLIANCE: Basel
--   - IFRS
--   - GDPR
--   - SOX
-- ============================================================================


CREATE TABLE dynamic.underwriting_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Product Scope
    product_id UUID REFERENCES dynamic.product_template_master(product_id),
    product_category_id UUID REFERENCES dynamic.product_category(category_id),
    coverage_type dynamic.coverage_type,
    
    -- Risk Factors
    risk_factors JSONB NOT NULL, -- [{factor: 'age', weight: 0.3, type: 'numeric'}, ...]
    
    -- Scoring Logic
    scoring_model_type VARCHAR(50) DEFAULT 'DECISION_TREE' 
        CHECK (scoring_model_type IN ('DECISION_TREE', 'LINEAR_REGRESSION', 'LOGISTIC_REGRESSION', 'NEURAL_NETWORK', 'RULE_BASED')),
    decision_tree_jsonb JSONB, -- JSON representation of decision tree
    scoring_formula TEXT, -- Mathematical formula if applicable
    
    -- Decision Outcomes
    auto_approve_threshold DECIMAL(10,6),
    auto_decline_threshold DECIMAL(10,6),
    manual_review_range_min DECIMAL(10,6),
    manual_review_range_max DECIMAL(10,6),
    
    -- Outcome Actions
    approval_actions JSONB, -- [{action: 'SET_PREMIUM', parameters: {...}}]
    decline_reasons JSONB, -- [{code: '...', description: '...'}]
    
    -- Loading Factors
    loading_rules JSONB, -- [{condition: '...', loading_percentage: 10}]
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Version
    model_version VARCHAR(20) DEFAULT '1.0',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_underwriting_rule_code UNIQUE (tenant_id, rule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.underwriting_rules_default PARTITION OF dynamic.underwriting_rules DEFAULT;

-- Indexes
CREATE INDEX idx_underwriting_rules_tenant ON dynamic.underwriting_rules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_underwriting_rules_product ON dynamic.underwriting_rules(tenant_id, product_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.underwriting_rules IS 'Insurance risk scoring and underwriting decision rules';

-- Triggers
CREATE TRIGGER trg_underwriting_rules_audit
    BEFORE UPDATE ON dynamic.underwriting_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.underwriting_rules TO finos_app;