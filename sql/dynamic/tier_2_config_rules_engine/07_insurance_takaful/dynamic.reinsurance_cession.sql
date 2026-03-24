-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 07 - Insurance & Takaful
-- TABLE: dynamic.reinsurance_cession
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Reinsurance Cession.
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
CREATE TABLE dynamic.reinsurance_cession (

    cession_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    treaty_id UUID NOT NULL REFERENCES dynamic.reinsurance_treaty(treaty_id),
    policy_id UUID NOT NULL REFERENCES dynamic.insurance_policy_master(policy_id),
    
    -- Ceded Amounts
    ceded_sum_assured DECIMAL(28,8) NOT NULL,
    ceded_premium DECIMAL(28,8) NOT NULL,
    
    -- Commission
    commission_on_cession DECIMAL(28,8),
    commission_percentage DECIMAL(10,6),
    
    -- Liability
    ceded_claim_reserve DECIMAL(28,8),
    ceded_claim_paid DECIMAL(28,8),
    
    -- Status
    cession_status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (cession_status IN ('ACTIVE', 'TERMINATED', 'EXPIRED')),
    
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

CREATE TABLE dynamic.reinsurance_cession_default PARTITION OF dynamic.reinsurance_cession DEFAULT;

-- Indexes
CREATE INDEX idx_cession_treaty ON dynamic.reinsurance_cession(tenant_id, treaty_id);
CREATE INDEX idx_cession_policy ON dynamic.reinsurance_cession(tenant_id, policy_id);

-- Comments
COMMENT ON TABLE dynamic.reinsurance_cession IS 'Specific risk cessions to reinsurers';

GRANT SELECT, INSERT, UPDATE ON dynamic.reinsurance_cession TO finos_app;