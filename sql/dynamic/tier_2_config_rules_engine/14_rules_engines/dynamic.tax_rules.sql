-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 14 - Rules Engines
-- TABLE: dynamic.tax_rules
-- COMPLIANCE: Basel
--   - IFRS
--   - GDPR
--   - SOX
-- ============================================================================


CREATE TABLE dynamic.tax_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    
    -- Jurisdiction
    jurisdiction_id UUID REFERENCES dynamic.tax_jurisdiction_master(jurisdiction_id),
    country_code CHAR(2) REFERENCES core.country_codes(iso_code),
    regional_code VARCHAR(50), -- State/Province
    city_code VARCHAR(50),
    
    -- Tax Type
    tax_type dynamic.tax_type NOT NULL,
    tax_sub_type VARCHAR(50),
    
    -- Applicability
    applicable_product_types VARCHAR(50)[],
    applicable_customer_types VARCHAR(50)[],
    applicable_transaction_types VARCHAR(50)[],
    
    -- Calculation
    calculation_method VARCHAR(50) DEFAULT 'PERCENTAGE' 
        CHECK (calculation_method IN ('PERCENTAGE', 'FIXED_AMOUNT', 'TIERED', 'COMPOSITE')),
    rate_percentage DECIMAL(10,6),
    fixed_amount DECIMAL(28,8),
    
    -- Tiered Rates
    tier_structure JSONB, -- [{min_amount: 0, max_amount: 10000, rate: 0.15}, ...]
    
    -- Formula
    formula_expression TEXT, -- Custom formula if needed
    formula_variables JSONB, -- Variable definitions
    
    -- Exemptions
    exemption_threshold DECIMAL(28,8),
    exemption_conditions JSONB,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE NOT NULL,
    effective_to DATE NOT NULL DEFAULT '9999-12-31',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_tax_rule_code UNIQUE (tenant_id, rule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.tax_rules_default PARTITION OF dynamic.tax_rules DEFAULT;

-- Indexes
CREATE INDEX idx_tax_rules_tenant ON dynamic.tax_rules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_tax_rules_jurisdiction ON dynamic.tax_rules(tenant_id, jurisdiction_id) WHERE is_active = TRUE;
CREATE INDEX idx_tax_rules_type ON dynamic.tax_rules(tenant_id, tax_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.tax_rules IS 'Jurisdiction-specific tax calculation rules';

-- Triggers
CREATE TRIGGER trg_tax_rules_audit
    BEFORE UPDATE ON dynamic.tax_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.tax_rules TO finos_app;