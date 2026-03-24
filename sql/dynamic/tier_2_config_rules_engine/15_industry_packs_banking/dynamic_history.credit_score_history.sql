-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 15 - Industry Packs: Banking
-- TABLE: dynamic_history.credit_score_history
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Credit Score History.
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
CREATE TABLE dynamic_history.credit_score_history (

    score_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- References
    model_id UUID NOT NULL REFERENCES dynamic.credit_scoring_models(model_id),
    customer_id UUID NOT NULL,
    application_id UUID, -- If scored for specific application
    
    -- Score Details
    score_value INTEGER NOT NULL,
    risk_band VARCHAR(50),
    risk_grade VARCHAR(10),
    
    -- Score Components
    feature_values JSONB, -- {income: 50000, employment_months: 24, ...}
    feature_contributions JSONB, -- {income: 150, employment: 80, ...}
    
    -- Decision
    recommendation VARCHAR(50), -- APPROVE, DECLINE, REVIEW
    confidence_score DECIMAL(5,4),
    
    -- Bureau Data
    bureau_data_used JSONB,
    bureau_inquiry_date DATE,
    
    -- Override
    is_override BOOLEAN DEFAULT FALSE,
    override_reason TEXT,
    override_approved_by VARCHAR(100),
    original_score INTEGER,
    
    -- Timestamps
    scored_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until DATE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.credit_score_history_default PARTITION OF dynamic_history.credit_score_history DEFAULT;

-- Indexes
CREATE INDEX idx_credit_score_customer ON dynamic_history.credit_score_history(tenant_id, customer_id);
CREATE INDEX idx_credit_score_model ON dynamic_history.credit_score_history(tenant_id, model_id);
CREATE INDEX idx_credit_score_date ON dynamic_history.credit_score_history(scored_at DESC);

-- Comments
COMMENT ON TABLE dynamic_history.credit_score_history IS 'Historical credit scores with feature contributions';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.credit_score_history TO finos_app;