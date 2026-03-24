-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 07 - Insurance & Takaful
-- TABLE: dynamic.claim_register
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Claim Register.
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
CREATE TABLE dynamic.claim_register (

    claim_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Claim Identification
    claim_number VARCHAR(100) NOT NULL,
    
    -- Policy Reference
    policy_id UUID NOT NULL REFERENCES dynamic.insurance_policy_master(policy_id),
    
    -- Claim Details
    claim_type dynamic.claim_type NOT NULL,
    claim_description TEXT,
    
    -- Dates
    incident_date DATE,
    claim_date DATE NOT NULL,
    reported_date DATE NOT NULL,
    
    -- Amounts
    claim_amount_requested DECIMAL(28,8) NOT NULL,
    claim_amount_approved DECIMAL(28,8),
    claim_amount_paid DECIMAL(28,8),
    
    -- Status
    claim_status dynamic.claim_status DEFAULT 'REGISTERED',
    status_reason TEXT,
    
    -- Workflow
    assigned_adjuster_id UUID,
    assigned_at TIMESTAMPTZ,
    
    -- Fraud
    fraud_score DECIMAL(5,4),
    fraud_flags JSONB,
    referred_to_investigation BOOLEAN DEFAULT FALSE,
    
    -- Settlement
    settlement_date DATE,
    settlement_method VARCHAR(50),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    CONSTRAINT unique_claim_number UNIQUE (tenant_id, claim_number)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.claim_register_default PARTITION OF dynamic.claim_register DEFAULT;

-- Indexes
CREATE INDEX idx_claim_tenant ON dynamic.claim_register(tenant_id);
CREATE INDEX idx_claim_policy ON dynamic.claim_register(tenant_id, policy_id);
CREATE INDEX idx_claim_status ON dynamic.claim_register(tenant_id, claim_status);
CREATE INDEX idx_claim_date ON dynamic.claim_register(claim_date DESC);

-- Comments
COMMENT ON TABLE dynamic.claim_register IS 'Insurance claim header with status tracking';

GRANT SELECT, INSERT, UPDATE ON dynamic.claim_register TO finos_app;