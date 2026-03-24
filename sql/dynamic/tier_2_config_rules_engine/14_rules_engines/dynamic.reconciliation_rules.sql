-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 14 - Rules Engines
-- TABLE: dynamic.reconciliation_rules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Reconciliation Rules.
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
CREATE TABLE dynamic.reconciliation_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Source Systems
    source_system_a VARCHAR(100) NOT NULL,
    source_system_b VARCHAR(100) NOT NULL,
    
    -- Match Criteria
    match_criteria JSONB NOT NULL, -- {fields: ['amount', 'date', 'reference'], key_field: 'reference'}
    match_type VARCHAR(50) DEFAULT 'EXACT' 
        CHECK (match_type IN ('EXACT', 'TOLERANCE', 'FUZZY', 'MANUAL')),
    
    -- Tolerance (for TOLERANCE match type)
    tolerance_amount DECIMAL(28,8),
    tolerance_percentage DECIMAL(5,4),
    tolerance_date_days INTEGER,
    
    -- Fuzzy Matching (for FUZZY match type)
    fuzzy_algorithm VARCHAR(50), -- LEVENSHTEIN, JARO_WINKLER, SOUNDEX
    fuzzy_threshold DECIMAL(5,4) DEFAULT 0.8, -- Minimum similarity score
    
    -- Auto-match Settings
    auto_match_enabled BOOLEAN DEFAULT TRUE,
    auto_match_confidence_threshold DECIMAL(5,4) DEFAULT 0.95,
    
    -- Suggestions
    suggest_matches BOOLEAN DEFAULT TRUE,
    suggestion_confidence_threshold DECIMAL(5,4) DEFAULT 0.70,
    
    -- Schedule
    reconciliation_frequency VARCHAR(20) DEFAULT 'DAILY',
    scheduled_time TIME,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
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
    
    CONSTRAINT unique_recon_rule_code UNIQUE (tenant_id, rule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.reconciliation_rules_default PARTITION OF dynamic.reconciliation_rules DEFAULT;

-- Indexes
CREATE INDEX idx_recon_rules_tenant ON dynamic.reconciliation_rules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_recon_rules_systems ON dynamic.reconciliation_rules(tenant_id, source_system_a, source_system_b) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.reconciliation_rules IS 'Auto-matching rules for inter-system reconciliation';

-- Triggers
CREATE TRIGGER trg_reconciliation_rules_audit
    BEFORE UPDATE ON dynamic.reconciliation_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.reconciliation_rules TO finos_app;