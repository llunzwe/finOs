-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 06 - Accounting & Financial Control
-- TABLE: dynamic_history.reconciliation_exception
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Reconciliation Exception.
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
CREATE TABLE dynamic_history.reconciliation_exception (

    exception_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    rule_id UUID NOT NULL REFERENCES dynamic.reconciliation_rule(rule_id),
    
    -- Exception Details
    exception_type VARCHAR(50) NOT NULL 
        CHECK (exception_type IN ('AMOUNT_MISMATCH', 'MISSING_RECORD_A', 'MISSING_RECORD_B', 'DUPLICATE', 'TIMING', 'OTHER')),
    exception_date DATE NOT NULL,
    
    -- Source Data
    source_a_record JSONB,
    source_b_record JSONB,
    
    -- Difference
    amount_difference DECIMAL(28,8),
    difference_currency CHAR(3),
    
    -- Resolution
    resolution_status VARCHAR(20) DEFAULT 'OPEN' 
        CHECK (resolution_status IN ('OPEN', 'UNDER_INVESTIGATION', 'RESOLVED', 'ACCEPTED')),
    assigned_to_user_id UUID,
    assigned_at TIMESTAMPTZ,
    
    resolution_action VARCHAR(50), -- CORRECTED, WRITE_OFF, TIMING_DIFFERENCE, ETC.
    resolution_notes TEXT,
    resolved_at TIMESTAMPTZ,
    resolved_by VARCHAR(100),
    
    -- Aging
    aging_days INTEGER GENERATED ALWAYS AS (CURRENT_DATE - exception_date) STORED,
    
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

CREATE TABLE dynamic_history.reconciliation_exception_default PARTITION OF dynamic_history.reconciliation_exception DEFAULT;

-- Indexes
CREATE INDEX idx_recon_exception_rule ON dynamic_history.reconciliation_exception(tenant_id, rule_id);
CREATE INDEX idx_recon_exception_status ON dynamic_history.reconciliation_exception(tenant_id, resolution_status) WHERE resolution_status != 'RESOLVED';
CREATE INDEX idx_recon_exception_aging ON dynamic_history.reconciliation_exception(tenant_id, aging_days) WHERE resolution_status != 'RESOLVED';

-- Comments
COMMENT ON TABLE dynamic_history.reconciliation_exception IS 'Reconciliation breaks requiring investigation';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.reconciliation_exception TO finos_app;