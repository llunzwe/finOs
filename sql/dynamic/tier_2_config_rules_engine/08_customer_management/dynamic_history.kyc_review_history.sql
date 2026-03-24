-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 08 - Customer Management
-- TABLE: dynamic_history.kyc_review_history
-- COMPLIANCE: FATF
--   - GDPR/POPIA
--   - KYC
--   - CDD
--   - AML/CFT
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

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.kyc_review_history_default PARTITION OF dynamic_history.kyc_review_history DEFAULT;

-- Indexes
CREATE INDEX idx_kyc_review_customer ON dynamic_history.kyc_review_history(tenant_id, customer_id);
CREATE INDEX idx_kyc_review_date ON dynamic_history.kyc_review_history(reviewed_at DESC);

-- Comments
COMMENT ON TABLE dynamic_history.kyc_review_history IS 'Audit trail of KYC reviews and outcomes';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.kyc_review_history TO finos_app;