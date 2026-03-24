-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Enterprise Extensions
-- TABLE: dynamic.regulatory_change_log
--
-- DESCRIPTION:
--   Enterprise-grade regulatory change tracking and compliance log.
--   Tracks regulation updates, impact assessment, implementation status.
--
-- ============================================================================


CREATE TABLE dynamic.regulatory_change_log (
    change_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Regulation Details
    regulation_reference VARCHAR(200) NOT NULL, -- e.g., "SARB Directive 2024/01"
    regulation_name VARCHAR(500) NOT NULL,
    issuing_authority VARCHAR(100) NOT NULL, -- 'SARB', 'RBZ', 'FSCA', 'Basel Committee'
    
    -- Change Classification
    regulation_type VARCHAR(100), -- 'PRUDENTIAL', 'CONDUCT', 'AML', 'DATA_PROTECTION'
    change_type VARCHAR(50) NOT NULL 
        CHECK (change_type IN ('NEW', 'AMENDMENT', 'REPEAL', 'GUIDANCE')),
    priority VARCHAR(20) DEFAULT 'MEDIUM' 
        CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    
    -- Dates
    issue_date DATE NOT NULL,
    effective_date DATE NOT NULL,
    compliance_deadline DATE,
    
    -- Impact Assessment
    affected_products VARCHAR(100)[],
    affected_processes VARCHAR(100)[],
    estimated_implementation_cost DECIMAL(28,8),
    impact_description TEXT,
    
    -- Implementation Tracking
    implementation_status VARCHAR(50) DEFAULT 'PENDING_ASSESSMENT' 
        CHECK (implementation_status IN ('PENDING_ASSESSMENT', 'UNDER_REVIEW', 'IMPLEMENTATION_PLANNED', 'IN_IMPLEMENTATION', 'IMPLEMENTED', 'DEFERRED')),
    assigned_department VARCHAR(100),
    assigned_owner VARCHAR(100),
    
    -- Actions
    required_actions JSONB DEFAULT '[]',
    system_changes_required BOOLEAN DEFAULT FALSE,
    policy_changes_required BOOLEAN DEFAULT FALSE,
    training_required BOOLEAN DEFAULT FALSE,
    
    -- Documentation
    regulation_document_url TEXT,
    internal_assessment_document TEXT,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.regulatory_change_log_default PARTITION OF dynamic.regulatory_change_log DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_regulatory_change_tenant ON dynamic.regulatory_change_log(tenant_id);
CREATE INDEX idx_regulatory_change_authority ON dynamic.regulatory_change_log(tenant_id, issuing_authority);
CREATE INDEX idx_regulatory_change_status ON dynamic.regulatory_change_log(tenant_id, implementation_status);
CREATE INDEX idx_regulatory_change_deadline ON dynamic.regulatory_change_log(tenant_id, compliance_deadline);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.regulatory_change_log IS 'Regulatory change tracking - compliance monitoring, impact assessment. Tier 2 - Enterprise Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.regulatory_change_log TO finos_app;
