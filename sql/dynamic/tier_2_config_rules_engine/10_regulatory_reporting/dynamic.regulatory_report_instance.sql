-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 10 - Regulatory Reporting
-- TABLE: dynamic.regulatory_report_instance
-- COMPLIANCE: XBRL
--   - Basel III/IV
--   - FATF
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic.regulatory_report_instance (

    instance_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    report_id UUID NOT NULL REFERENCES dynamic.regulatory_report_catalog(report_id),
    
    -- Reporting Period
    reporting_period_start DATE NOT NULL,
    reporting_period_end DATE NOT NULL,
    
    -- Status
    status VARCHAR(20) DEFAULT 'DRAFT' 
        CHECK (status IN ('DRAFT', 'VALIDATING', 'VALIDATED', 'SUBMITTED', 'ACCEPTED', 'REJECTED', 'CORRECTED')),
    
    -- Generation
    generated_at TIMESTAMPTZ,
    generated_by VARCHAR(100),
    generation_query_time_ms INTEGER,
    
    -- Validation
    validation_passed BOOLEAN,
    validation_errors JSONB,
    validation_warnings JSONB,
    
    -- Submission
    submitted_at TIMESTAMPTZ,
    submitted_by VARCHAR(100),
    submission_reference VARCHAR(200),
    acknowledgment_reference VARCHAR(200),
    
    -- Storage
    report_data JSONB,
    report_file_url VARCHAR(500),
    xbrl_file_url VARCHAR(500),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_report_period UNIQUE (tenant_id, report_id, reporting_period_start, reporting_period_end)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.regulatory_report_instance_default PARTITION OF dynamic.regulatory_report_instance DEFAULT;

-- Indexes
CREATE INDEX idx_report_instance_report ON dynamic.regulatory_report_instance(tenant_id, report_id);
CREATE INDEX idx_report_instance_period ON dynamic.regulatory_report_instance(reporting_period_start DESC);
CREATE INDEX idx_report_instance_status ON dynamic.regulatory_report_instance(tenant_id, status);

-- Comments
COMMENT ON TABLE dynamic.regulatory_report_instance IS 'Generated regulatory report instances';

GRANT SELECT, INSERT, UPDATE ON dynamic.regulatory_report_instance TO finos_app;