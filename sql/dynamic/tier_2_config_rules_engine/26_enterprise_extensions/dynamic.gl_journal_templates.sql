-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Enterprise Extensions
-- TABLE: dynamic.gl_journal_templates
--
-- DESCRIPTION:
--   Enterprise-grade GL journal entry templates for automated postings.
--   Defines standard journal formats for recurring transactions.
--
-- ============================================================================


CREATE TABLE dynamic.gl_journal_templates (
    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Template Identification
    template_code VARCHAR(100) NOT NULL,
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    
    -- Trigger
    trigger_event VARCHAR(100) NOT NULL, -- 'INTEREST_ACCRUAL', 'FEE_CHARGE', 'LOAN_DISBURSEMENT'
    
    -- Template Lines (JSON Array of debit/credit lines)
    template_lines JSONB NOT NULL, -- [{"account_code": "1000", "side": "DEBIT", "formula": "principal"}, ...]
    
    -- Balance Check
    auto_balance_check BOOLEAN DEFAULT TRUE,
    balancing_account_id UUID REFERENCES dynamic.gl_account_master(account_id), -- Auto-balancing account
    
    -- Approval
    requires_approval BOOLEAN DEFAULT FALSE,
    approval_workflow_id UUID REFERENCES dynamic.approval_matrix_advanced(matrix_id),
    
    -- Automation
    auto_post BOOLEAN DEFAULT FALSE,
    post_timing VARCHAR(50) DEFAULT 'IMMEDIATE' 
        CHECK (post_timing IN ('IMMEDIATE', 'END_OF_DAY', 'END_OF_MONTH')),
    
    -- Validation
    validation_rules JSONB DEFAULT '{}',
    
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
    
    CONSTRAINT unique_template_code UNIQUE (tenant_id, template_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.gl_journal_templates_default PARTITION OF dynamic.gl_journal_templates DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_gl_journal_templates_tenant ON dynamic.gl_journal_templates(tenant_id);
CREATE INDEX idx_gl_journal_templates_event ON dynamic.gl_journal_templates(tenant_id, trigger_event);
CREATE INDEX idx_gl_journal_templates_active ON dynamic.gl_journal_templates(tenant_id, is_active);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.gl_journal_templates IS 'GL journal entry templates - automated posting formats. Tier 2 - Enterprise Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.gl_journal_templates TO finos_app;
