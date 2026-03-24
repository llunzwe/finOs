-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 33 - Regulatory Reporting
-- TABLE: dynamic.tax_engine_config
--
-- DESCRIPTION:
--   Enterprise-grade tax engine configuration.
--   VAT, income tax, withholding tax, regional compliance rules.
--
-- COMPLIANCE: OECD, FATCA, CRS, Regional Tax Regulations
-- ============================================================================


CREATE TABLE dynamic.tax_engine_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Tax Configuration
    tax_name VARCHAR(200) NOT NULL,
    tax_type VARCHAR(50) NOT NULL 
        CHECK (tax_type IN ('VAT', 'GST', 'INCOME_TAX', 'WITHHOLDING_TAX', 'STAMP_DUTY', 'CAPITAL_GAINS', 'EXCISE', 'CUSTOMS')),
    
    -- Jurisdiction
    country_code CHAR(2) NOT NULL,
    region_code VARCHAR(20), -- State/Province for regional variations
    
    -- Tax Rates
    standard_rate DECIMAL(10,6) NOT NULL,
    reduced_rate DECIMAL(10,6),
    zero_rate_applicable BOOLEAN DEFAULT FALSE,
    exempt_applicable BOOLEAN DEFAULT FALSE,
    
    -- Rate Tiers
    tiered_rates JSONB DEFAULT '[]', -- [{"threshold": 100000, "rate": 0.25}, ...] for income tax
    
    -- Applicability
    applicable_transaction_types VARCHAR(50)[], -- ['INTEREST', 'FEES', 'FX', 'TRADING']
    applicable_product_types VARCHAR(50)[],
    applicable_customer_types VARCHAR(50)[], -- ['INDIVIDUAL', 'CORPORATE', 'NON_RESIDENT']
    
    -- Thresholds
    registration_threshold DECIMAL(28,8),
    minimum_taxable_amount DECIMAL(28,8) DEFAULT 0,
    
    -- Withholding Specific
    withholding_percentage DECIMAL(5,4),
    withholding_account_id UUID REFERENCES dynamic.gl_account_master(account_id),
    
    -- Reporting
    tax_period VARCHAR(20) DEFAULT 'MONTHLY' 
        CHECK (tax_period IN ('MONTHLY', 'QUARTERLY', 'BI_ANNUAL', 'ANNUAL')),
    filing_deadline_day INTEGER, -- Day of month
    payment_deadline_day INTEGER,
    
    -- Exemptions
    exemption_conditions JSONB DEFAULT '{}',
    
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
    
    CONSTRAINT unique_tax_type_country UNIQUE (tenant_id, tax_type, country_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.tax_engine_config_default PARTITION OF dynamic.tax_engine_config DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.tax_engine_config IS 'Tax engine configuration - VAT, income tax, withholding tax, regional compliance. Tier 2 - Regulatory Reporting.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.tax_engine_config TO finos_app;
