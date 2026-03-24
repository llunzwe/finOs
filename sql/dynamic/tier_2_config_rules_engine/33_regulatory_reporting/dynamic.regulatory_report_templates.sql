-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 33 - Regulatory Reporting Engine
-- TABLE: dynamic.regulatory_report_templates
--
-- DESCRIPTION:
--   Enterprise-grade regulatory reporting template configuration.
--   XBRL, COREP, FINREP, SARB returns, RBZ returns templates.
--   Supports automated generation, validation, and submission tracking.
--
-- COMPLIANCE: Basel III/IV, IFRS, SARB, RBZ, EBA Guidelines
-- ============================================================================


CREATE TABLE dynamic.regulatory_report_templates (
    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Template Identification
    template_code VARCHAR(100) NOT NULL,
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    
    -- Regulatory Authority
    regulatory_authority VARCHAR(50) NOT NULL 
        CHECK (regulatory_authority IN ('SARB', 'RBZ', 'FSCA', 'PRUDENTIAL', 'EBA', 'FED', 'FCA', 'CENTRAL_BANK')),
    report_type VARCHAR(100) NOT NULL, -- 'COREP', 'FINREP', 'LIQUIDITY', 'LEVERAGE', 'LARGE_EXPOSURES'
    report_subtype VARCHAR(100), -- e.g., 'LEVERAGE_RATIO', 'LCR', 'NSFR'
    
    -- XBRL/Format Configuration
    reporting_standard VARCHAR(50) DEFAULT 'XBRL' 
        CHECK (reporting_standard IN ('XBRL', 'CSV', 'XML', 'JSON', 'FIXED_WIDTH')),
    xbrl_taxonomy_version VARCHAR(50), -- e.g., "DPM 3.0"
    xbrl_namespace VARCHAR(200),
    xbrl_schema_location TEXT,
    
    -- Reporting Frequency
    reporting_frequency VARCHAR(20) NOT NULL 
        CHECK (reporting_frequency IN ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'BI_ANNUAL', 'ANNUAL', 'AD_HOC')),
    reporting_due_day INTEGER, -- Day of month/quarter when report is due
    reporting_cutoff_time TIME DEFAULT '23:59:59',
    
    -- Data Source Configuration
    data_source_queries JSONB NOT NULL, -- SQL queries or API endpoints
    aggregation_rules JSONB DEFAULT '{}', -- How to aggregate data
    validation_rules JSONB DEFAULT '[]', -- Data quality checks
    
    -- Template Structure
    template_structure JSONB NOT NULL, -- Field definitions, mappings
    calculation_formulas JSONB DEFAULT '{}', -- Derived fields
    
    -- Submission Configuration
    submission_method VARCHAR(50) DEFAULT 'API' 
        CHECK (submission_method IN ('API', 'PORTAL_UPLOAD', 'EMAIL', 'SECURE_FTP')),
    submission_endpoint TEXT,
    authentication_config JSONB, -- Credentials/config for submission
    
    -- Sign-off Requirements
    requires_cfo_signoff BOOLEAN DEFAULT TRUE,
    requires_ceo_signoff BOOLEAN DEFAULT FALSE,
    requires_board_approval BOOLEAN DEFAULT FALSE,
    minimum_signatories INTEGER DEFAULT 1,
    
    -- Status
    template_status VARCHAR(20) DEFAULT 'DRAFT' 
        CHECK (template_status IN ('DRAFT', 'ACTIVE', 'DEPRECATED', 'SUPERSEDED')),
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    superseded_by_template_id UUID REFERENCES dynamic.regulatory_report_templates(template_id),
    
    -- Version Control
    template_version VARCHAR(20) DEFAULT '1.0.0',
    regulatory_version_effective_date DATE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_template_code_version UNIQUE (tenant_id, template_code, template_version)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.regulatory_report_templates_default PARTITION OF dynamic.regulatory_report_templates DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_report_template_tenant ON dynamic.regulatory_report_templates(tenant_id);
CREATE INDEX idx_report_template_authority ON dynamic.regulatory_report_templates(tenant_id, regulatory_authority);
CREATE INDEX idx_report_template_type ON dynamic.regulatory_report_templates(tenant_id, report_type);
CREATE INDEX idx_report_template_status ON dynamic.regulatory_report_templates(tenant_id, template_status);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.regulatory_report_templates IS 'Regulatory reporting templates - XBRL, COREP, FINREP, SARB/RBZ returns. Tier 2 - Regulatory Reporting Engine.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.regulatory_report_templates TO finos_app;
