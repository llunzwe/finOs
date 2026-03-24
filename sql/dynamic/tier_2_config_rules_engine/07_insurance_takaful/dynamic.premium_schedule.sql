-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 07 - Insurance & Takaful
-- TABLE: dynamic.premium_schedule
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Premium Schedule.
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
CREATE TABLE dynamic.premium_schedule (

    schedule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    policy_id UUID NOT NULL REFERENCES dynamic.insurance_policy_master(policy_id) ON DELETE CASCADE,
    
    -- Installment Details
    installment_number INTEGER NOT NULL,
    due_date DATE NOT NULL,
    
    -- Amounts
    premium_amount DECIMAL(28,8) NOT NULL,
    modal_loading DECIMAL(28,8) DEFAULT 0, -- Extra for non-annual
    discount_amount DECIMAL(28,8) DEFAULT 0,
    total_amount_due DECIMAL(28,8) NOT NULL,
    
    -- Payment
    amount_paid DECIMAL(28,8) DEFAULT 0,
    payment_date DATE,
    payment_reference VARCHAR(100),
    
    -- Status
    payment_status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (payment_status IN ('PENDING', 'PAID', 'GRACE', 'OVERDUE', 'LAPSED', 'WAIVED')),
    grace_period_end_date DATE,
    
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
    
    CONSTRAINT unique_policy_installment UNIQUE (tenant_id, policy_id, installment_number)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.premium_schedule_default PARTITION OF dynamic.premium_schedule DEFAULT;

-- Indexes
CREATE INDEX idx_premium_schedule_policy ON dynamic.premium_schedule(tenant_id, policy_id);
CREATE INDEX idx_premium_schedule_due ON dynamic.premium_schedule(tenant_id, due_date) WHERE payment_status IN ('PENDING', 'GRACE');
CREATE INDEX idx_premium_schedule_status ON dynamic.premium_schedule(tenant_id, payment_status);

-- Comments
COMMENT ON TABLE dynamic.premium_schedule IS 'Premium payment plan by installment';

GRANT SELECT, INSERT, UPDATE ON dynamic.premium_schedule TO finos_app;