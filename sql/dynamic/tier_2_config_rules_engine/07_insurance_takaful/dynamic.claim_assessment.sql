-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 07 - Insurance Takaful
-- TABLE: dynamic.claim_assessment
-- COMPLIANCE: IFRS 17
--   - Solvency II
--   - AAOIFI
--   - IAIS
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

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.claim_assessment_default PARTITION OF dynamic.claim_assessment DEFAULT;

-- Indexes
CREATE INDEX idx_assessment_claim ON dynamic.claim_assessment(tenant_id, claim_id);

-- Comments
COMMENT ON TABLE dynamic.claim_assessment IS 'Adjuster evaluation and fraud assessment';

GRANT SELECT, INSERT, UPDATE ON dynamic.claim_assessment TO finos_app;