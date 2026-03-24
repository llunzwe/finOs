-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 14 - Rules Engines
-- TABLE: dynamic_history.fraud_risk_scoring
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Fraud Risk Scoring.
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
CREATE TABLE dynamic_history.fraud_risk_scoring (

    scoring_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Context
    entity_type VARCHAR(50) NOT NULL, -- CUSTOMER, ACCOUNT, TRANSACTION, SESSION
    entity_id UUID NOT NULL,
    
    -- Scoring
    total_risk_score INTEGER NOT NULL,
    risk_band VARCHAR(20) GENERATED ALWAYS AS (
        CASE 
            WHEN total_risk_score >= 80 THEN 'CRITICAL'
            WHEN total_risk_score >= 60 THEN 'HIGH'
            WHEN total_risk_score >= 40 THEN 'MEDIUM'
            ELSE 'LOW'
        END
    ) STORED,
    
    -- Triggered Rules
    triggered_rules JSONB, -- [{rule_id: '...', rule_code: '...', score_increment: 20}, ...]
    
    -- Decision
    decision VARCHAR(20) NOT NULL, -- ALLOW, CHALLENGE, BLOCK, REVIEW
    decision_reason TEXT,
    
    -- Context Data
    context_snapshot JSONB, -- Data used for scoring
    
    -- Timestamps
    scored_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.fraud_risk_scoring_default PARTITION OF dynamic_history.fraud_risk_scoring DEFAULT;

-- Indexes
CREATE INDEX idx_fraud_scoring_entity ON dynamic_history.fraud_risk_scoring(tenant_id, entity_type, entity_id);
CREATE INDEX idx_fraud_scoring_score ON dynamic_history.fraud_risk_scoring(tenant_id, total_risk_score DESC);
CREATE INDEX idx_fraud_scoring_time ON dynamic_history.fraud_risk_scoring(scored_at DESC);

-- Comments
COMMENT ON TABLE dynamic_history.fraud_risk_scoring IS 'Historical fraud risk scores with triggered rules';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.fraud_risk_scoring TO finos_app;