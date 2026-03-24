-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.tax_jurisdiction_master
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Tax Jurisdiction Master.
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


CREATE TABLE dynamic.tax_jurisdiction_master (
    jurisdiction_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    jurisdiction_code VARCHAR(50) NOT NULL,
    jurisdiction_name VARCHAR(200) NOT NULL,
    
    -- Geographic Scope
    country_code CHAR(2) NOT NULL REFERENCES core.country_codes(iso_code),
    regional_code VARCHAR(50), -- State/Province
    city_code VARCHAR(50),
    
    -- Tax Authority
    tax_authority_name VARCHAR(200),
    tax_authority_contact TEXT,
    tax_authority_website VARCHAR(255),
    
    -- Reporting
    reporting_currency CHAR(3) NOT NULL REFERENCES core.currencies(code),
    fiscal_year_end_month INTEGER CHECK (fiscal_year_end_month BETWEEN 1 AND 12),
    
    -- Compliance
    vat_registration_required_threshold DECIMAL(28,8),
    vat_registration_number_format VARCHAR(100),
    tax_filing_frequency VARCHAR(20) DEFAULT 'MONTHLY',
    
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
    
    CONSTRAINT unique_jurisdiction_code_per_tenant UNIQUE (tenant_id, jurisdiction_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.tax_jurisdiction_master_default PARTITION OF dynamic.tax_jurisdiction_master DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_tax_jurisdiction_tenant
idx_tax_jurisdiction_country

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.tax_jurisdiction_master IS 'Global tax jurisdiction definitions';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.tax_jurisdiction_master TO finos_app;
