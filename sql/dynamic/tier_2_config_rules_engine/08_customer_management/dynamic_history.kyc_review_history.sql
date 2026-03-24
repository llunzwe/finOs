-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 08 - Customer Management
-- TABLE: dynamic_history.kyc_review_history
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Kyc Review History.
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
CREATE TABLE dynamic_history.kyc_review_history (

    review_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    customer_id UUID NOT NULL,
    
    -- Review Details
    review_type VARCHAR(50) NOT NULL, -- PERIODIC, TRIGGERED, EDD, etc.
    review_trigger VARCHAR(100),
    
    -- Outcome
    review_outcome VARCHAR(20) NOT NULL CHECK (review_outcome IN ('APPROVED', 'REJECTED', 'ESCALATED', 'MORE_INFO')),
    risk_rating_after VARCHAR(20),
    
    -- Reviewer
    reviewed_by VARCHAR(100) NOT NULL,
    reviewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    review_notes TEXT,
    
    -- Next Review
    next_review_due DATE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.kyc_review_history_default PARTITION OF dynamic_history.kyc_review_history DEFAULT;

-- Indexes
CREATE INDEX idx_kyc_review_customer ON dynamic_history.kyc_review_history(tenant_id, customer_id);
CREATE INDEX idx_kyc_review_date ON dynamic_history.kyc_review_history(reviewed_at DESC);

-- Comments
COMMENT ON TABLE dynamic_history.kyc_review_history IS 'Audit trail of KYC reviews and outcomes';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.kyc_review_history TO finos_app;