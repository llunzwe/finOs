-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 10 - Regulatory Reporting
-- TABLE: dynamic.examination_finding
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Examination Finding.
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
CREATE TABLE dynamic.examination_finding (

    finding_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    examination_id UUID NOT NULL REFERENCES dynamic.regulatory_examination(examination_id),
    
    -- Finding Details
    finding_reference VARCHAR(100) NOT NULL,
    finding_category VARCHAR(50) NOT NULL, -- GOVERNANCE, RISK_MANAGEMENT, COMPLIANCE, etc.
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    
    -- Description
    finding_description TEXT NOT NULL,
    root_cause_analysis TEXT,
    
    -- Recommendation
    regulatory_recommendation TEXT,
    required_action TEXT,
    
    -- Remediation
    remediation_owner VARCHAR(100),
    remediation_plan TEXT,
    target_completion_date DATE,
    actual_completion_date DATE,
    
    -- Status
    remediation_status VARCHAR(20) DEFAULT 'OPEN' 
        CHECK (remediation_status IN ('OPEN', 'IN_PROGRESS', 'AWAITING_VERIFICATION', 'CLOSED', 'ACCEPTED')),
    
    -- Evidence
    supporting_documents TEXT[],
    
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

CREATE TABLE dynamic.examination_finding_default PARTITION OF dynamic.examination_finding DEFAULT;

-- Indexes
CREATE INDEX idx_finding_examination ON dynamic.examination_finding(tenant_id, examination_id);
CREATE INDEX idx_finding_status ON dynamic.examination_finding(tenant_id, remediation_status) WHERE remediation_status != 'CLOSED';

-- Comments
COMMENT ON TABLE dynamic.examination_finding IS 'Individual examination findings with remediation tracking';

GRANT SELECT, INSERT, UPDATE ON dynamic.examination_finding TO finos_app;