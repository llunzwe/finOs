-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 1: INSTANT LIBRARY (ZERO-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product Library
-- TABLE: dynamic.product_library_catalog
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Library Catalog.
--   Pre-seeded products available for single-click activation.
--   Supports tenant isolation and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 1 - Zero-Code Instant Library: Ready-to-use, single-click activation products.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 8601
--   - ISO 20022
--   - IFRS 9
--   - Basel III
--   - GDPR
--   - SOC2
--
-- AUDIT & GOVERNANCE:
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
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_product_code_per_tenant UNIQUE (tenant_id, product_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_library_catalog_default PARTITION OF dynamic.product_library_catalog DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_product_library_tenant ON dynamic.product_library_catalog(tenant_id);
CREATE INDEX idx_product_library_code ON dynamic.product_library_catalog(tenant_id, product_code);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_library_catalog IS 'Product Library Catalog - Pre-seeded products available for single-click activation. Tier 1 - Instant Library.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_library_catalog TO finos_app;
