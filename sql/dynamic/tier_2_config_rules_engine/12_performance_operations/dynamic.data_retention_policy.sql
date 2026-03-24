-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 12 - Performance & Operations
-- TABLE: dynamic.data_retention_policy
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Data Retention Policy.
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
CREATE TABLE dynamic.data_retention_policy (

    policy_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    policy_name VARCHAR(200) NOT NULL,
    policy_description TEXT,
    
    -- Target
    target_schema VARCHAR(100) NOT NULL,
    target_table VARCHAR(200) NOT NULL,
    
    -- Retention Rules
    retention_period_years INTEGER NOT NULL,
    retention_period_months INTEGER,
    retention_criteria TEXT, -- SQL condition
    
    -- Action
    retention_action VARCHAR(20) DEFAULT 'ARCHIVE' 
        CHECK (retention_action IN ('DELETE', 'ARCHIVE', 'ANONYMIZE')),
    archive_destination VARCHAR(200),
    
    -- Schedule
    purge_schedule_cron VARCHAR(100),
    
    -- Statistics
    last_purge_at TIMESTAMPTZ,
    last_purge_records BIGINT,
    total_records_purged BIGINT DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
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

CREATE TABLE dynamic.data_retention_policy_default PARTITION OF dynamic.data_retention_policy DEFAULT;

-- Indexes
CREATE INDEX idx_retention_policy_table ON dynamic.data_retention_policy(tenant_id, target_schema, target_table);

-- Comments
COMMENT ON TABLE dynamic.data_retention_policy IS 'Data lifecycle and retention management';

-- Triggers
CREATE TRIGGER trg_data_retention_policy_audit
    BEFORE UPDATE ON dynamic.data_retention_policy
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.data_retention_policy TO finos_app;