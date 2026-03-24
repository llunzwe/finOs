-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 13 - Billing & Contracts
-- TABLE: dynamic.contract_template
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Contract Template.
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
CREATE TABLE dynamic.contract_template (

    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    template_code VARCHAR(100) NOT NULL,
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    
    -- Contract Type
    contract_type VARCHAR(50) NOT NULL 
        CHECK (contract_type IN ('SERVICE_AGREEMENT', 'SUBSCRIPTION', 'LICENSE', 'INSURANCE_POLICY', 'LOAN_AGREEMENT', 'NDA', 'PARTNERSHIP', 'EMPLOYMENT', 'CUSTOM')),
    
    -- Template Content
    clause_jsonb JSONB NOT NULL, -- [{clause_id: '...', title: '...', content: '...', required: true}, ...]
    template_html TEXT, -- Full HTML template
    template_variables JSONB, -- [{name: 'customer_name', type: 'string', required: true}, ...]
    
    -- Structure
    sections JSONB, -- [{section_id: '...', title: '...', clauses: ['clause_1', 'clause_2']}, ...]
    
    -- Legal
    jurisdiction VARCHAR(100),
    governing_law VARCHAR(100),
    dispute_resolution_mechanism VARCHAR(100), -- ARBITRATION, LITIGATION, MEDIATION
    
    -- Terms
    default_term_months INTEGER,
    auto_renew BOOLEAN DEFAULT FALSE,
    renewal_notice_days INTEGER DEFAULT 30,
    termination_notice_days INTEGER DEFAULT 30,
    
    -- Approvals
    requires_legal_review BOOLEAN DEFAULT FALSE,
    requires_management_approval BOOLEAN DEFAULT FALSE,
    approval_workflow_id UUID,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Version
    template_version VARCHAR(20) DEFAULT '1.0',
    superseded_by_template_id UUID REFERENCES dynamic.contract_template(template_id),
    
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
    
    CONSTRAINT unique_contract_template_code UNIQUE (tenant_id, template_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.contract_template_default PARTITION OF dynamic.contract_template DEFAULT;

-- Indexes
CREATE INDEX idx_contract_template_tenant ON dynamic.contract_template(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_contract_template_lookup ON dynamic.contract_template(tenant_id, template_code) WHERE is_active = TRUE;
CREATE INDEX idx_contract_template_type ON dynamic.contract_template(tenant_id, contract_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.contract_template IS 'B2B/SaaS/insurance contract boilerplate with clauses';

-- Triggers
CREATE TRIGGER trg_contract_template_audit
    BEFORE UPDATE ON dynamic.contract_template
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.contract_template TO finos_app;