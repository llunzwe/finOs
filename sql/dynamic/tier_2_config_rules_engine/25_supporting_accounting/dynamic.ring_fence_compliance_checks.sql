-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 25 - Supporting Accounting
-- TABLE: dynamic.ring_fence_compliance_checks
-- COMPLIANCE: IFRS
--   - SOX
--   - CASS
--   - GDPR
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
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.ring_fence_compliance_checks_default PARTITION OF dynamic.ring_fence_compliance_checks DEFAULT;

-- Indexes
CREATE INDEX idx_ring_fence_checks ON dynamic.ring_fence_compliance_checks(tenant_id, active) WHERE active = TRUE;

-- Triggers
CREATE TRIGGER trg_ring_fence_checks_update
    BEFORE UPDATE ON dynamic.ring_fence_compliance_checks
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_supporting_accounting_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.ring_fence_compliance_checks TO finos_app;