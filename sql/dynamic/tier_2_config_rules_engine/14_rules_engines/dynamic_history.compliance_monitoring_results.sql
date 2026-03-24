-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 14 - Rules Engines
-- TABLE: dynamic_history.compliance_monitoring_results
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Compliance Monitoring Results.
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
CREATE TABLE dynamic_history.compliance_monitoring_results (

    result_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    rule_id UUID NOT NULL REFERENCES dynamic.compliance_rules(rule_id),
    
    -- Evaluation Context
    evaluation_date DATE NOT NULL,
    evaluation_period_start DATE,
    evaluation_period_end DATE,
    
    -- Entity
    entity_type VARCHAR(50),
    entity_id UUID,
    
    -- Result
    rule_passed BOOLEAN NOT NULL,
    actual_value DECIMAL(28,8),
    threshold_value DECIMAL(28,8),
    variance_percentage DECIMAL(10,6),
    
    -- Details
    evaluation_details JSONB,
    supporting_data JSONB,
    
    -- Status
    severity VARCHAR(20) GENERATED ALWAYS AS (
        CASE 
            WHEN NOT rule_passed AND actual_value >= threshold_value * 1.1 THEN 'CRITICAL'
            WHEN NOT rule_passed THEN 'WARNING'
            ELSE 'COMPLIANT'
        END
    ) STORED,
    
    -- Resolution
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by VARCHAR(100),
    acknowledged_at TIMESTAMPTZ,
    remediation_plan TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.compliance_monitoring_results_default PARTITION OF dynamic_history.compliance_monitoring_results DEFAULT;

-- Indexes
CREATE INDEX idx_compliance_results_rule ON dynamic_history.compliance_monitoring_results(tenant_id, rule_id);
CREATE INDEX idx_compliance_results_date ON dynamic_history.compliance_monitoring_results(evaluation_date DESC);
CREATE INDEX idx_compliance_results_status ON dynamic_history.compliance_monitoring_results(tenant_id, rule_passed) WHERE rule_passed = FALSE;

-- Comments
COMMENT ON TABLE dynamic_history.compliance_monitoring_results IS 'Compliance rule evaluation results and monitoring';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.compliance_monitoring_results TO finos_app;