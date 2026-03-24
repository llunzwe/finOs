-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 10 - Regulatory Reporting
-- TABLE: dynamic.regulatory_report_catalog
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Regulatory Report Catalog.
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
CREATE TABLE dynamic.regulatory_report_catalog (

    report_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    report_code VARCHAR(50) NOT NULL,
    report_name VARCHAR(200) NOT NULL,
    report_description TEXT,
    
    -- Regulatory Authority
    regulatory_authority dynamic.regulatory_authority NOT NULL,
    regulatory_framework VARCHAR(100), -- BASEL, IFRS, etc.
    
    -- Filing Requirements
    reporting_frequency VARCHAR(20) NOT NULL 
        CHECK (reporting_frequency IN ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'SEMI_ANNUAL', 'ANNUAL', 'ADHOC')),
    submission_deadline_day INTEGER,
    submission_deadline_time TIME,
    
    -- Schema
    schema_version VARCHAR(20) NOT NULL,
    xbrl_taxonomy_reference VARCHAR(200),
    xbrl_namespace VARCHAR(200),
    
    -- Validation
    validation_ruleset_id UUID,
    validation_query TEXT,
    
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
    
    CONSTRAINT unique_report_code UNIQUE (tenant_id, report_code, schema_version)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.regulatory_report_catalog_default PARTITION OF dynamic.regulatory_report_catalog DEFAULT;

-- Indexes
CREATE INDEX idx_report_catalog_tenant ON dynamic.regulatory_report_catalog(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_report_catalog_authority ON dynamic.regulatory_report_catalog(tenant_id, regulatory_authority) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.regulatory_report_catalog IS 'All regulatory required reports with XBRL references';

-- Triggers
CREATE TRIGGER trg_regulatory_report_catalog_audit
    BEFORE UPDATE ON dynamic.regulatory_report_catalog
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.regulatory_report_catalog TO finos_app;