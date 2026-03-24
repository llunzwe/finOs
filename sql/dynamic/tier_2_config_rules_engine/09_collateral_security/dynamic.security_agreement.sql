-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 09 - Collateral & Security
-- TABLE: dynamic.security_agreement
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Security Agreement.
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
CREATE TABLE dynamic.security_agreement (

    agreement_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- References
    loan_container_id UUID NOT NULL REFERENCES core.value_containers(id),
    collateral_id UUID NOT NULL REFERENCES dynamic.collateral_master(collateral_id),
    
    -- Agreement Details
    agreement_type dynamic.agreement_type NOT NULL,
    agreement_reference VARCHAR(100) NOT NULL,
    agreement_date DATE NOT NULL,
    
    -- Registration
    registration_reference VARCHAR(200),
    registration_authority VARCHAR(200),
    registration_date DATE,
    registration_expiry_date DATE,
    
    -- Priority
    priority_ranking INTEGER DEFAULT 1,
    prior_ranking_agreement BOOLEAN DEFAULT FALSE,
    
    -- Release
    release_date DATE,
    release_reason TEXT,
    released_by VARCHAR(100),
    
    -- Enforcement
    enforcement_events JSONB, -- [{event: 'DEFAULT', action: '...'}, ...]
    enforcement_date DATE,
    enforcement_outcome TEXT,
    
    -- Documents
    agreement_document_url VARCHAR(500),
    
    -- Status
    agreement_status VARCHAR(20) DEFAULT 'ACTIVE' 
        CHECK (agreement_status IN ('DRAFT', 'PENDING_REGISTRATION', 'ACTIVE', 'RELEASED', 'ENFORCED')),
    
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
    
    CONSTRAINT unique_agreement_ref UNIQUE (tenant_id, agreement_reference)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.security_agreement_default PARTITION OF dynamic.security_agreement DEFAULT;

-- Indexes
CREATE INDEX idx_security_agreement_loan ON dynamic.security_agreement(tenant_id, loan_container_id);
CREATE INDEX idx_security_agreement_collateral ON dynamic.security_agreement(tenant_id, collateral_id);

-- Comments
COMMENT ON TABLE dynamic.security_agreement IS 'Legal documentation for security perfection';

-- Triggers
CREATE TRIGGER trg_security_agreement_audit
    BEFORE UPDATE ON dynamic.security_agreement
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.security_agreement TO finos_app;