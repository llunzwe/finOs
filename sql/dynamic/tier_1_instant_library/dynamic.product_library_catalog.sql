-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 1: INSTANT LIBRARY (ZERO-CODE)
-- ============================================================================
-- TABLE: dynamic.product_library_catalog
-- DESCRIPTION: Product Library Catalog - Pre-seeded products
-- COMPLIANCE: IFRS 9, Basel III, GDPR, POPIA, AAOIFI
-- TIER: 1 - Zero-Code (Ready-to-use, single-click activation)
-- ============================================================================

CREATE TABLE dynamic.product_library_catalog (

    catalog_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Product Code (e.g., OFFSET_MORTGAGE, CREDIT_CARD_VISA)
    product_code VARCHAR(100) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    product_description TEXT,
    
    -- Classification
    category VARCHAR(50) NOT NULL 
        CHECK (category IN (
            'MORTGAGE', 'LOAN', 'DEPOSIT', 'REVOLVING_CREDIT', 'WALLET',
            'CREDIT_CARD', 'DEBIT_CARD', 'PREPAID_CARD', 'REWARD_ACCOUNT',
            'INSURANCE', 'INVESTMENT', 'SAVINGS', 'CURRENT_ACCOUNT',
            'PROGRAM_RESERVE', 'GROUP_BANKING', 'ISLAMIC_FINANCE'
        )),
    sub_category VARCHAR(50),
    
    -- Flags
    shariah_flag BOOLEAN DEFAULT FALSE,
    is_commercial BOOLEAN DEFAULT TRUE,
    is_retail BOOLEAN DEFAULT TRUE,
    
    -- Geographic Support
    country_support CHAR(2)[], -- ISO country codes
    currency_support CHAR(3)[], -- ISO currency codes
    
    -- Template Reference
    base_contract_id UUID REFERENCES dynamic.product_smart_contracts(contract_id),
    default_parameters JSONB DEFAULT '{}',
    
    -- Pricing Template
    pricing_template_id UUID REFERENCES dynamic.pricing_template_headers(pricing_template_id),
    
    -- Risk & Compliance
    risk_rating INTEGER CHECK (risk_rating BETWEEN 1 AND 10),
    regulatory_framework VARCHAR(50)[], -- ['IFRS9', 'BASEL3', 'SARB', 'FSCA']
    
    -- Documentation
    documentation_url TEXT,
    sample_config JSONB,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_seeded BOOLEAN DEFAULT FALSE, -- System-provided vs custom
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_product_code_per_tenant UNIQUE (tenant_id, product_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_library_catalog_default PARTITION OF dynamic.product_library_catalog DEFAULT;

COMMENT ON TABLE dynamic.product_library_catalog IS 'Product Library Catalog - Pre-seeded products. Tier 1 - Instant Library.';

GRANT SELECT, INSERT, UPDATE ON dynamic.product_library_catalog TO finos_app;
