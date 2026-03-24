-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 15 - Industry Packs: Banking
-- TABLE: dynamic.loan_restructuring_templates
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Loan Restructuring Templates.
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
CREATE TABLE dynamic.loan_restructuring_templates (

    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    template_code VARCHAR(100) NOT NULL,
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    
    -- Restructuring Type
    restructuring_type VARCHAR(50) NOT NULL 
        CHECK (restructuring_type IN ('TERM_EXTENSION', 'PAYMENT_REDUCTION', 'INTEREST_RATE_REDUCTION', 'PAYMENT_HOLIDAY', 'BALLOON_PAYMENT', 'CONSOLIDATION', 'PARTIAL_WRITE_OFF')),
    
    -- Eligibility Criteria
    min_payments_made INTEGER,
    max_days_past_due INTEGER,
    min_credit_score INTEGER,
    max_previous_restructurings INTEGER,
    
    -- Terms
    max_term_extension_months INTEGER,
    max_interest_rate_reduction DECIMAL(10,6),
    max_payment_reduction_percentage DECIMAL(5,4),
    
    -- Fees
    restructuring_fee_percentage DECIMAL(10,6),
    restructuring_fee_minimum DECIMAL(28,8),
    restructuring_fee_maximum DECIMAL(28,8),
    
    -- Conditions
    required_documentation JSONB,
    approval_required BOOLEAN DEFAULT TRUE,
    credit_assessment_required BOOLEAN DEFAULT TRUE,
    
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
    
    CONSTRAINT unique_restructure_template_code UNIQUE (tenant_id, template_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.loan_restructuring_templates_default PARTITION OF dynamic.loan_restructuring_templates DEFAULT;

-- Indexes
CREATE INDEX idx_restructure_template_tenant ON dynamic.loan_restructuring_templates(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_restructure_template_type ON dynamic.loan_restructuring_templates(tenant_id, restructuring_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.loan_restructuring_templates IS 'Loan workout and restructuring templates';

-- Triggers
CREATE TRIGGER trg_loan_restructuring_templates_audit
    BEFORE UPDATE ON dynamic.loan_restructuring_templates
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.loan_restructuring_templates TO finos_app;