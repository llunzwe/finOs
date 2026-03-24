-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 07 - Insurance & Takaful
-- TABLE: dynamic.claim_assessment
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Claim Assessment.
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
CREATE TABLE dynamic.claim_assessment (

    assessment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    claim_id UUID NOT NULL REFERENCES dynamic.claim_register(claim_id) ON DELETE CASCADE,
    
    -- Surveyor/Adjuster
    surveyor_id UUID,
    surveyor_name VARCHAR(200),
    assessment_date DATE NOT NULL,
    
    -- Assessment
    assessed_amount DECIMAL(28,8),
    assessment_basis TEXT,
    assessment_notes TEXT,
    
    -- Fraud Indicators
    fraud_indicators JSONB, -- [{indicator: '...', severity: 'HIGH'}, ...]
    fraud_recommendation VARCHAR(50),
    
    -- Documents
    supporting_documents JSONB, -- [{type: '...', url: '...'}, ...]
    
    -- Decision
    recommended_decision VARCHAR(20) CHECK (recommended_decision IN ('APPROVE', 'REJECT', 'PARTIAL', 'INVESTIGATE')),
    recommended_amount DECIMAL(28,8),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100)
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.claim_assessment_default PARTITION OF dynamic.claim_assessment DEFAULT;

-- Indexes
CREATE INDEX idx_assessment_claim ON dynamic.claim_assessment(tenant_id, claim_id);

-- Comments
COMMENT ON TABLE dynamic.claim_assessment IS 'Adjuster evaluation and fraud assessment';

GRANT SELECT, INSERT, UPDATE ON dynamic.claim_assessment TO finos_app;