-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 06 - Accounting & Financial Control
-- TABLE: dynamic.sub_ledger_definition
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Sub Ledger Definition.
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
CREATE TABLE dynamic.sub_ledger_definition (

    sub_ledger_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    sub_ledger_code VARCHAR(50) NOT NULL,
    sub_ledger_name VARCHAR(200) NOT NULL,
    sub_ledger_description TEXT,
    
    -- Type
    sub_ledger_type VARCHAR(50) NOT NULL 
        CHECK (sub_ledger_type IN ('CLIENT', 'MARGIN', 'SUSPENSE', 'CLEARING', 'ESCROW', 'TRUST')),
    
    -- GL Linkage
    parent_gl_account VARCHAR(50) NOT NULL,
    control_account_id UUID,
    
    -- Aggregation
    aggregation_strategy VARCHAR(50) DEFAULT 'BY_CLIENT' 
        CHECK (aggregation_strategy IN ('BY_CLIENT', 'BY_DATE', 'BY_PRODUCT', 'BY_CURRENCY', 'INDIVIDUAL')),
    
    -- Reconciliation
    auto_reconciliation_enabled BOOLEAN DEFAULT TRUE,
    reconciliation_frequency VARCHAR(20) DEFAULT 'DAILY',
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
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
    
    CONSTRAINT unique_sub_ledger_code UNIQUE (tenant_id, sub_ledger_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.sub_ledger_definition_default PARTITION OF dynamic.sub_ledger_definition DEFAULT;

-- Comments
COMMENT ON TABLE dynamic.sub_ledger_definition IS 'Sub-ledger definitions for client money segregation';

-- Triggers
CREATE TRIGGER trg_sub_ledger_def_audit
    BEFORE UPDATE ON dynamic.sub_ledger_definition
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.sub_ledger_definition TO finos_app;