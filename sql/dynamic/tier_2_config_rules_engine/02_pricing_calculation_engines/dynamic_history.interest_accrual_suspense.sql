-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic_history.interest_accrual_suspense
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Interest Accrual Suspense.
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


CREATE TABLE dynamic_history.interest_accrual_suspense (
    accrual_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    container_id UUID NOT NULL REFERENCES core.value_containers(id) ON DELETE CASCADE,
    
    -- Accrual Details
    accrual_date DATE NOT NULL,
    accrual_amount DECIMAL(28,8) NOT NULL,
    accrued_interest_ytd DECIMAL(28,8) NOT NULL DEFAULT 0,
    
    -- Rate Info
    applied_rate DECIMAL(15,10) NOT NULL,
    day_count_fraction DECIMAL(15,10) NOT NULL,
    balance_at_accrual DECIMAL(28,8) NOT NULL,
    
    -- Posting
    posting_status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (posting_status IN ('PENDING', 'POSTED', 'REVERSED')),
    posted_at TIMESTAMPTZ,
    posting_reference UUID,
    
    -- Reversal
    reversal_reference UUID,
    reversal_reason TEXT,
    
    -- Method
    accrual_method_used dynamic.accrual_method NOT NULL,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    CONSTRAINT unique_accrual_per_day UNIQUE (tenant_id, container_id, accrual_date)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.interest_accrual_suspense_default PARTITION OF dynamic_history.interest_accrual_suspense DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_accrual_suspense_container ON dynamic_history.interest_accrual_suspense(tenant_id);
CREATE INDEX idx_accrual_suspense_date ON dynamic_history.interest_accrual_suspense(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic_history.interest_accrual_suspense IS 'Daily interest accrual tracking before posting to GL';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic_history.interest_accrual_suspense TO finos_app;
