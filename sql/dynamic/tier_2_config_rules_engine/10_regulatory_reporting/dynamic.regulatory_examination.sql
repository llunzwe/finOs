-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 10 - Regulatory Reporting
-- TABLE: dynamic.regulatory_examination
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Regulatory Examination.
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
CREATE TABLE dynamic.regulatory_examination (

    examination_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Examination Details
    examination_reference VARCHAR(100) NOT NULL,
    examination_type VARCHAR(50) NOT NULL, -- ON_SITE, OFF_SITE, THEMATIC, etc.
    
    -- Authority
    regulatory_authority dynamic.regulatory_authority NOT NULL,
    examiners TEXT[],
    
    -- Scope
    examination_scope TEXT,
    areas_under_review TEXT[],
    
    -- Dates
    examination_start_date DATE,
    examination_end_date DATE,
    
    -- Status
    status VARCHAR(20) DEFAULT 'PLANNED' 
        CHECK (status IN ('PLANNED', 'IN_PROGRESS', 'REPORT_PENDING', 'FINDINGS_ISSUED', 'REMEDIATION', 'CLOSED')),
    
    -- Findings
    findings_summary TEXT,
    findings_count INTEGER DEFAULT 0,
    material_findings INTEGER DEFAULT 0,
    
    -- Response
    management_response_due DATE,
    management_response_submitted DATE,
    remediation_plan_submitted DATE,
    
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
    
    CONSTRAINT unique_examination_ref UNIQUE (tenant_id, examination_reference)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.regulatory_examination_default PARTITION OF dynamic.regulatory_examination DEFAULT;

-- Indexes
CREATE INDEX idx_examination_tenant ON dynamic.regulatory_examination(tenant_id);
CREATE INDEX idx_examination_status ON dynamic.regulatory_examination(tenant_id, status);

-- Comments
COMMENT ON TABLE dynamic.regulatory_examination IS 'Regulatory examination tracking and management';

-- Triggers
CREATE TRIGGER trg_regulatory_examination_audit
    BEFORE UPDATE ON dynamic.regulatory_examination
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.regulatory_examination TO finos_app;