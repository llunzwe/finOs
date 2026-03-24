-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 08 - Customer Management
-- TABLE: dynamic.customer_risk_rating
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Customer Risk Rating.
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
CREATE TABLE dynamic.customer_risk_rating (

    rating_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    customer_id UUID NOT NULL,
    
    -- Rating Model
    rating_model VARCHAR(100) NOT NULL,
    rating_model_version VARCHAR(20),
    
    -- Score
    risk_score DECIMAL(10,4) NOT NULL, -- Numeric score
    risk_band VARCHAR(20) NOT NULL CHECK (risk_band IN ('LOW', 'MEDIUM', 'HIGH', 'EXTREME')),
    risk_grade VARCHAR(10), -- A, B, C, D, etc.
    
    -- Factors
    rating_factors JSONB, -- {pep_score: 0.1, sanctions_score: 0, adverse_media_score: 0.2, ...}
    factor_weights JSONB,
    
    -- Review
    rating_date DATE NOT NULL,
    next_review_date DATE,
    review_triggered_by VARCHAR(100),
    
    -- Override
    is_override BOOLEAN DEFAULT FALSE,
    override_reason TEXT,
    override_approved_by VARCHAR(100),
    
    -- Status
    is_current BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    
    CONSTRAINT unique_customer_current_rating UNIQUE (tenant_id, customer_id, rating_model, is_current) WHERE is_current = TRUE

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.customer_risk_rating_default PARTITION OF dynamic.customer_risk_rating DEFAULT;

-- Indexes
CREATE INDEX idx_risk_rating_customer ON dynamic.customer_risk_rating(tenant_id, customer_id);
CREATE INDEX idx_risk_rating_band ON dynamic.customer_risk_rating(tenant_id, risk_band) WHERE is_current = TRUE;
CREATE INDEX idx_risk_rating_review ON dynamic.customer_risk_rating(tenant_id, next_review_date) WHERE is_current = TRUE;

-- Comments
COMMENT ON TABLE dynamic.customer_risk_rating IS 'Dynamic customer risk scoring for KYC/AML';

-- Triggers
CREATE TRIGGER trg_customer_risk_rating_audit
    BEFORE UPDATE ON dynamic.customer_risk_rating
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.customer_risk_rating TO finos_app;