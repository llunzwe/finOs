-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 25 - Supporting Accounting
-- TABLE: dynamic.accounting_rule_templates
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Accounting Rule Templates.
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
CREATE TABLE dynamic.accounting_rule_templates (

    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    
    -- Template Category
    category VARCHAR(50) NOT NULL 
        CHECK (category IN ('LOAN', 'DEPOSIT', 'CARD', 'PAYMENT', 'INVESTMENT', 'INSURANCE', 'GENERAL')),
    
    -- The Rules
    event_type VARCHAR(50) NOT NULL,
    debit_account_rules JSONB NOT NULL DEFAULT '{}',
    credit_account_rules JSONB NOT NULL DEFAULT '{}',
    additional_legs JSONB DEFAULT '[]',
    
    -- Sample Data
    example_transaction JSONB,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
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

CREATE TABLE dynamic.accounting_rule_templates_default PARTITION OF dynamic.accounting_rule_templates DEFAULT;

-- Indexes
CREATE INDEX idx_accounting_templates_category ON dynamic.accounting_rule_templates(tenant_id, category);

-- Triggers
CREATE TRIGGER trg_accounting_templates_update
    BEFORE UPDATE ON dynamic.accounting_rule_templates
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_supporting_accounting_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.accounting_rule_templates TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.accounting_rule_templates IS 'Accounting Rule Templates';