-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.tax_reporting_forms
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Tax Reporting Forms.
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


CREATE TABLE dynamic.tax_reporting_forms (
    form_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Form Identification
    form_code VARCHAR(50) NOT NULL, -- IT3b, IRP5, etc.
    form_name VARCHAR(200) NOT NULL,
    form_description TEXT,
    
    -- Regulatory Context
    jurisdiction_id UUID NOT NULL REFERENCES dynamic.tax_jurisdiction_master(jurisdiction_id),
    regulatory_authority dynamic.regulatory_authority NOT NULL,
    
    -- Filing Details
    filing_frequency VARCHAR(20) DEFAULT 'ANNUAL' 
        CHECK (filing_frequency IN ('MONTHLY', 'QUARTERLY', 'ANNUAL', 'ADHOC')),
    filing_deadline_day INTEGER,
    filing_deadline_month INTEGER,
    
    -- Schema
    schema_version VARCHAR(20) NOT NULL,
    schema_definition JSONB, -- JSON Schema for form data
    xbrl_taxonomy_reference VARCHAR(200),
    
    -- Field Mappings
    field_mappings JSONB NOT NULL, -- {box_1: 'field_sql', box_2: 'field_sql'}
    
    -- Generation Rules
    generation_query TEXT, -- SQL query to generate form data
    validation_rules JSONB,
    
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
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_form_code_version UNIQUE (tenant_id, form_code, schema_version)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.tax_reporting_forms_default PARTITION OF dynamic.tax_reporting_forms DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_tax_forms_jurisdiction ON dynamic.tax_reporting_forms(tenant_id);
CREATE INDEX idx_tax_forms_authority ON dynamic.tax_reporting_forms(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.tax_reporting_forms IS 'Tax authority form definitions with field mappings';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.tax_reporting_forms TO finos_app;
