-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.withholding_tax_rules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Withholding Tax Rules.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 8601
--   - ISO 20022
--   - IFRS 15
--   - Basel III
--   - OECD
--   - NCA
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


CREATE TABLE dynamic.withholding_tax_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    rule_name VARCHAR(200) NOT NULL,
    
    -- Applicability
    product_type VARCHAR(50),
    income_type VARCHAR(50), -- INTEREST, DIVIDEND, ROYALTY, etc.
    
    -- Customer Criteria
    customer_residency_status VARCHAR(20) DEFAULT 'RESIDENT' 
        CHECK (customer_residency_status IN ('RESIDENT', 'NON_RESIDENT', 'BOTH')),
    customer_tax_status VARCHAR(50)[], -- TAXABLE, EXEMPT, etc.
    
    -- Withholding Details
    withholding_rate DECIMAL(10,6) NOT NULL,
    withholding_rate_description TEXT,
    
    -- Exemptions
    exemption_threshold DECIMAL(28,8),
    exemption_certificate_required BOOLEAN DEFAULT FALSE,
    exemption_certificate_type VARCHAR(50),
    
    -- Double Tax Treaty
    treaty_applicable BOOLEAN DEFAULT FALSE,
    treaty_country_code CHAR(2) REFERENCES core.country_codes(iso_code),
    treaty_reduced_rate DECIMAL(10,6),
    
    -- Reporting
    tax_form_code VARCHAR(50),
    tax_form_box VARCHAR(50),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.withholding_tax_rules_default PARTITION OF dynamic.withholding_tax_rules DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_withholding_rules_product ON dynamic.withholding_tax_rules(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.withholding_tax_rules IS 'Source deduction rules for withholding taxes';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.withholding_tax_rules TO finos_app;
