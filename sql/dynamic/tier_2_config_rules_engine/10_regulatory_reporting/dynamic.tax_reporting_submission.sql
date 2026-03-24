-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 10 - Regulatory Reporting
-- TABLE: dynamic.tax_reporting_submission
-- COMPLIANCE: XBRL
--   - Basel III/IV
--   - FATF
--   - BCBS 239
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
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.tax_reporting_submission_default PARTITION OF dynamic.tax_reporting_submission DEFAULT;

-- Indexes
CREATE INDEX idx_tax_submission_form ON dynamic.tax_reporting_submission(tenant_id, form_id);
CREATE INDEX idx_tax_submission_period ON dynamic.tax_reporting_submission(tax_period DESC);

-- Comments
COMMENT ON TABLE dynamic.tax_reporting_submission IS 'Revenue service tax filings';

GRANT SELECT, INSERT, UPDATE ON dynamic.tax_reporting_submission TO finos_app;