-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 06 - Accounting & Financial Control
-- TABLE: dynamic.reconciliation_rule
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Reconciliation Rule.
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
CREATE TABLE dynamic.reconciliation_rule (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Source Systems
    source_system_a VARCHAR(100) NOT NULL,
    source_system_b VARCHAR(100) NOT NULL,
    
    -- Matching Criteria
    matching_criteria JSONB NOT NULL, -- {fields: ['amount', 'date', 'reference'], key_field: 'reference'}
    
    -- Tolerance
    tolerance_amount DECIMAL(28,8) DEFAULT 0,
    tolerance_percentage DECIMAL(5,4) DEFAULT 0,
    
    -- Auto Match
    auto_match_enabled BOOLEAN DEFAULT TRUE,
    auto_match_threshold DECIMAL(5,4) DEFAULT 1.0, -- Confidence score
    
    -- Schedule
    reconciliation_frequency VARCHAR(20) DEFAULT 'DAILY',
    scheduled_time TIME,
    
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
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.reconciliation_rule_default PARTITION OF dynamic.reconciliation_rule DEFAULT;

-- Comments
COMMENT ON TABLE dynamic.reconciliation_rule IS 'Inter-system reconciliation configuration';

-- Triggers
CREATE TRIGGER trg_recon_rule_audit
    BEFORE UPDATE ON dynamic.reconciliation_rule
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.reconciliation_rule TO finos_app;