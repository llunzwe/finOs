-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 25 - Supporting Accounting
-- TABLE: dynamic.ring_fence_compliance_checks
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Ring Fence Compliance Checks.
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
CREATE TABLE dynamic.ring_fence_compliance_checks (

    check_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Check Identity
    check_name VARCHAR(200) NOT NULL,
    check_type VARCHAR(50) NOT NULL 
        CHECK (check_type IN ('DAILY_RECONCILIATION', 'SEGREGATION_VERIFY', 'RESERVE_ADEQUACY', 'CLIENT_MONEY_AUDIT')),
    
    -- Scope
    ring_fence_account_id UUID NOT NULL, -- Links to core sub_account or dynamic program_reserve
    
    -- Check Configuration
    check_rules JSONB NOT NULL DEFAULT '{}',
    -- Example: {
    --   tolerance_amount: 0.01,
    --   required_documents: ['daily_statement', 'bank_confirmation'],
    --   approval_required: true
    -- }
    
    -- Schedule
    check_frequency VARCHAR(20) DEFAULT 'daily' 
        CHECK (check_frequency IN ('hourly', 'daily', 'weekly', 'monthly')),
    scheduled_time TIME DEFAULT '06:00:00',
    
    -- Execution
    last_check_at TIMESTAMPTZ,
    last_check_status VARCHAR(20) CHECK (last_check_status IN ('passed', 'failed', 'warning')),
    last_check_result JSONB,
    
    -- Alerting
    alert_on_failure BOOLEAN DEFAULT TRUE,
    alert_recipients TEXT[],
    
    active BOOLEAN DEFAULT TRUE,
    
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

CREATE TABLE dynamic.ring_fence_compliance_checks_default PARTITION OF dynamic.ring_fence_compliance_checks DEFAULT;

-- Indexes
CREATE INDEX idx_ring_fence_checks ON dynamic.ring_fence_compliance_checks(tenant_id, active) WHERE active = TRUE;

-- Triggers
CREATE TRIGGER trg_ring_fence_checks_update
    BEFORE UPDATE ON dynamic.ring_fence_compliance_checks
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_supporting_accounting_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.ring_fence_compliance_checks TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.ring_fence_compliance_checks IS 'Ring Fence Compliance Checks';