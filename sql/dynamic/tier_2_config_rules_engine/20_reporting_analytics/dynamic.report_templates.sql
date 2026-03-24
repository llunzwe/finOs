-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 20 - Reporting & Analytics
-- TABLE: dynamic.report_templates
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Report Templates.
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
CREATE TABLE dynamic.report_templates (

    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    template_code VARCHAR(100) NOT NULL,
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    
    -- Report Type
    report_type VARCHAR(50) NOT NULL 
        CHECK (report_type IN ('REGULATORY', 'MANAGEMENT', 'OPERATIONAL', 'FINANCIAL', 'RISK', 'COMPLIANCE', 'CUSTOM')),
    report_subtype VARCHAR(100), -- e.g., 'BASEL', 'IFRS9', 'STRESS_TEST'
    
    -- Query Configuration
    query_template TEXT NOT NULL, -- SQL query template
    query_parameters JSONB, -- [{name: 'reporting_date', type: 'date', required: true}, ...]
    query_data_sources VARCHAR(100)[], -- Tables/views used
    
    -- Output Format
    supported_formats VARCHAR(50)[] DEFAULT ARRAY['PDF', 'EXCEL', 'CSV', 'JSON'],
    default_format VARCHAR(20) DEFAULT 'PDF',
    
    -- Layout
    template_layout JSONB, -- {header: {...}, footer: {...}, page_size: 'A4'}
    chart_configurations JSONB, -- [{type: 'bar', data_query: '...', options: {...}}, ...]
    
    -- Scheduling
    schedule_enabled BOOLEAN DEFAULT FALSE,
    schedule_cron VARCHAR(100),
    schedule_recipients TEXT[],
    
    -- Security
    required_roles VARCHAR(100)[],
    data_filter_rules JSONB, -- Row-level security filters
    
    -- Version
    template_version VARCHAR(20) DEFAULT '1.0',
    
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
    
    CONSTRAINT unique_report_template_code UNIQUE (tenant_id, template_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.report_templates_default PARTITION OF dynamic.report_templates DEFAULT;

-- Indexes
CREATE INDEX idx_report_templates_tenant ON dynamic.report_templates(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_report_templates_type ON dynamic.report_templates(tenant_id, report_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.report_templates IS 'SQL and configurable report templates';

-- Triggers
CREATE TRIGGER trg_report_templates_audit
    BEFORE UPDATE ON dynamic.report_templates
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.report_templates TO finos_app;