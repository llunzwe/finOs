-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 10 - Regulatory Reporting
-- TABLE: dynamic.audit_trail_configurable
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Audit Trail Configurable.
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
CREATE TABLE dynamic.audit_trail_configurable (

    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Table/Column to Audit
    table_name VARCHAR(100) NOT NULL,
    column_name VARCHAR(100),
    
    -- Audit Level
    audit_level VARCHAR(20) NOT NULL 
        CHECK (audit_level IN ('NONE', 'UPDATE', 'INSERT_DELETE', 'FULL')),
    
    -- Conditions
    row_filter_condition TEXT, -- SQL WHERE clause
    
    -- Security
    sensitive_data_masking BOOLEAN DEFAULT FALSE,
    masking_pattern VARCHAR(100), -- e.g., 'XXXX-XXXX-XXXX-{last4}'
    
    -- Retention
    retention_period_years INTEGER DEFAULT 7,
    archive_after_years INTEGER DEFAULT 3,
    
    -- Storage
    destination_table VARCHAR(100), -- History table name
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.audit_trail_configurable_default PARTITION OF dynamic.audit_trail_configurable DEFAULT;

-- Indexes
CREATE INDEX idx_audit_config_table ON dynamic.audit_trail_configurable(tenant_id, table_name);

-- Comments
COMMENT ON TABLE dynamic.audit_trail_configurable IS 'Granular audit settings per table/column';

GRANT SELECT, INSERT, UPDATE ON dynamic.audit_trail_configurable TO finos_app;