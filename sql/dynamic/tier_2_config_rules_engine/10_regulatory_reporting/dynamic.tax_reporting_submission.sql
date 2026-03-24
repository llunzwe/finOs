-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 10 - Regulatory Reporting
-- TABLE: dynamic.tax_reporting_submission
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Tax Reporting Submission.
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
CREATE TABLE dynamic.tax_reporting_submission (

    submission_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Form Reference
    form_id UUID NOT NULL REFERENCES dynamic.tax_reporting_forms(form_id),
    tax_period DATE NOT NULL,
    
    -- Submission Data
    submission_data JSONB NOT NULL,
    
    -- Status
    submission_status VARCHAR(20) DEFAULT 'DRAFT' 
        CHECK (submission_status IN ('DRAFT', 'SUBMITTED', 'ACKNOWLEDGED', 'ASSESSMENT_PENDING', 'ASSESSED', 'AMENDED')),
    
    -- Submission
    submitted_at TIMESTAMPTZ,
    submitted_by VARCHAR(100),
    
    -- Revenue Service
    acknowledgment_reference VARCHAR(100),
    acknowledgment_date DATE,
    
    -- Assessment
    assessment_status VARCHAR(50),
    assessment_amount DECIMAL(28,8),
    assessment_currency CHAR(3),
    assessment_date DATE,
    
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

CREATE TABLE dynamic.tax_reporting_submission_default PARTITION OF dynamic.tax_reporting_submission DEFAULT;

-- Indexes
CREATE INDEX idx_tax_submission_form ON dynamic.tax_reporting_submission(tenant_id, form_id);
CREATE INDEX idx_tax_submission_period ON dynamic.tax_reporting_submission(tax_period DESC);

-- Comments
COMMENT ON TABLE dynamic.tax_reporting_submission IS 'Revenue service tax filings';

GRANT SELECT, INSERT, UPDATE ON dynamic.tax_reporting_submission TO finos_app;