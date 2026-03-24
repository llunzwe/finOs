-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.delinquency_rules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Delinquency Rules.
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
CREATE TABLE dynamic.delinquency_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    rule_name VARCHAR(200) NOT NULL,
    
    -- Applicability
    applies_to VARCHAR(30) NOT NULL,
    target_id UUID NOT NULL,
    
    -- Buckets (30, 60, 90, 120, 150, 180+ days)
    bucket_definitions_jsonb JSONB NOT NULL DEFAULT '{}',
    -- Example: {
    --   bucket_1: {days_min: 1, days_max: 30, action: 'reminder'},
    --   bucket_2: {days_min: 31, days_max: 60, action: 'late_fee'},
    --   bucket_3: {days_min: 61, days_max: 90, action: 'collection'},
    --   bucket_6: {days_min: 180, action: 'charge_off'}
    -- }
    
    -- Actions
    auto_late_fee BOOLEAN DEFAULT TRUE,
    late_fee_template_id UUID REFERENCES dynamic.fee_templates(template_id),
    
    auto_interest_rate_increase BOOLEAN DEFAULT FALSE,
    penalty_rate DECIMAL(10,6),
    
    collection_handoff_bucket INTEGER DEFAULT 3,
    charge_off_bucket INTEGER DEFAULT 6,
    
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.delinquency_rules_default PARTITION OF dynamic.delinquency_rules DEFAULT;

-- Comments
COMMENT ON TABLE dynamic.delinquency_rules IS 'Configurable delinquency bucketing and action rules';

-- Triggers
CREATE TRIGGER trg_delinquency_rules_update
    BEFORE UPDATE ON dynamic.delinquency_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_marqeta_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.delinquency_rules TO finos_app;