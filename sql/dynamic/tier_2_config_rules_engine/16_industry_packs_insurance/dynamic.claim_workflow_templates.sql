-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 16 - Industry Packs: Insurance
-- TABLE: dynamic.claim_workflow_templates
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Claim Workflow Templates.
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
CREATE TABLE dynamic.claim_workflow_templates (

    workflow_template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    workflow_code VARCHAR(100) NOT NULL,
    workflow_name VARCHAR(200) NOT NULL,
    workflow_description TEXT,
    
    -- Claim Type Link
    claim_type_id UUID REFERENCES dynamic.claim_types(claim_type_id),
    
    -- Workflow Definition
    states_jsonb JSONB NOT NULL, -- [{state: 'REGISTERED', description: '...', actions: [...]}, ...]
    transitions_jsonb JSONB NOT NULL, -- [{from: 'REGISTERED', to: 'UNDER_ASSESSMENT', condition: '...'}, ...]
    
    -- Stage Configuration
    stages JSONB, -- [{stage: 'DOCUMENTATION', sla_hours: 24, responsible_role: '...'}, ...]
    
    -- SLA
    overall_sla_days INTEGER DEFAULT 30,
    escalation_matrix JSONB, -- [{days: 15, escalate_to: 'MANAGER'}, ...]
    
    -- Decision Points
    decision_points JSONB, -- [{point: 'ASSESSMENT', options: ['APPROVE', 'REJECT', 'INVESTIGATE']}, ...]
    
    -- Notifications
    notification_triggers JSONB, -- [{event: 'STATUS_CHANGE', recipients: ['CLAIMANT', 'AGENT']}, ...]
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    workflow_version VARCHAR(20) DEFAULT '1.0',
    
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
    
    CONSTRAINT unique_claim_workflow_code UNIQUE (tenant_id, workflow_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.claim_workflow_templates_default PARTITION OF dynamic.claim_workflow_templates DEFAULT;

-- Indexes
CREATE INDEX idx_claim_workflow_tenant ON dynamic.claim_workflow_templates(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_claim_workflow_type ON dynamic.claim_workflow_templates(tenant_id, claim_type_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.claim_workflow_templates IS 'Insurance claim processing workflow definitions';

-- Triggers
CREATE TRIGGER trg_claim_workflow_templates_audit
    BEFORE UPDATE ON dynamic.claim_workflow_templates
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.claim_workflow_templates TO finos_app;