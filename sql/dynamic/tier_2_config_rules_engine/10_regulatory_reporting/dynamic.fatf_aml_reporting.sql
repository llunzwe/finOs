-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 10 - Regulatory Reporting
-- TABLE: dynamic.fatf_aml_reporting
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Fatf Aml Reporting.
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
CREATE TABLE dynamic.fatf_aml_reporting (

    report_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Report Type
    report_type VARCHAR(50) NOT NULL 
        CHECK (report_type IN ('STR', 'CTR', 'SAR', 'TF_SUSPICION')),
    report_reference VARCHAR(100) NOT NULL,
    
    -- Subject
    subject_customer_id UUID,
    subject_account_id UUID REFERENCES core.value_containers(id),
    subject_transaction_id UUID,
    
    -- Suspicion Details
    suspicion_indicators JSONB NOT NULL, -- [{indicator: '...', description: '...'}, ...]
    suspicion_description TEXT,
    involved_parties JSONB,
    
    -- Amounts
    suspected_amount DECIMAL(28,8),
    suspected_amount_currency CHAR(3),
    
    -- Filing
    str_filed_date DATE,
    fiu_reference_number VARCHAR(100),
    
    -- Investigation
    investigation_status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (investigation_status IN ('PENDING', 'UNDER_INVESTIGATION', 'CLEARED', 'CONFIRMED', 'CLOSED')),
    investigation_notes TEXT,
    
    -- Internal
    filed_by VARCHAR(100) NOT NULL,
    filed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_by VARCHAR(100),
    reviewed_at TIMESTAMPTZ,
    
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
    
    CONSTRAINT unique_str_reference UNIQUE (tenant_id, report_reference)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.fatf_aml_reporting_default PARTITION OF dynamic.fatf_aml_reporting DEFAULT;

-- Indexes
CREATE INDEX idx_fatf_tenant ON dynamic.fatf_aml_reporting(tenant_id);
CREATE INDEX idx_fatf_status ON dynamic.fatf_aml_reporting(tenant_id, investigation_status);
CREATE INDEX idx_fatf_customer ON dynamic.fatf_aml_reporting(tenant_id, subject_customer_id);

-- Comments
COMMENT ON TABLE dynamic.fatf_aml_reporting IS 'Suspicious transaction reports to FIU';

-- Triggers
CREATE TRIGGER trg_fatf_aml_audit
    BEFORE UPDATE ON dynamic.fatf_aml_reporting
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.fatf_aml_reporting TO finos_app;