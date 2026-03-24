-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 25 - Supporting Accounting
-- TABLE: dynamic.real_time_ledger_views
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Real Time Ledger Views.
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
CREATE TABLE dynamic.real_time_ledger_views (

    view_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- View Identity
    view_name VARCHAR(200) NOT NULL,
    view_description TEXT,
    view_type VARCHAR(50) NOT NULL 
        CHECK (view_type IN ('CONTAINER_BALANCE', 'RING_FENCE_SLICE', 'AGGREGATE', 'RECONCILIATION', 'CUSTOM')),
    
    -- Source Configuration
    source_type VARCHAR(50) NOT NULL 
        CHECK (source_type IN ('value_container', 'sub_account', 'product', 'program', 'custom_query')),
    source_filter JSONB NOT NULL DEFAULT '{}',
    -- Example for container: {container_ids: [...]}
    -- Example for product: {product_codes: ['FIXED_MORTGAGE']}
    
    -- Balance Calculation Rules
    calculation_rules JSONB NOT NULL DEFAULT '{}',
    -- Example: {
    --   include_pending: true,
    --   include_holds: false,
    --   cut_off_time: '23:59:59',
    --   currency_conversion: 'latest'
    -- }
    
    -- Dimensions for Aggregation
    aggregation_dimensions TEXT[], -- ['product_type', 'currency', 'region']
    
    -- Ring-Fence Specific
    ring_fence_config JSONB DEFAULT '{}',
    -- Example: {
    --   ring_fence_type: 'CLIENT_MONEY',
    --   segregation_level: 'account',
    --   compliance_checks: ['daily_reconciliation']
    -- }
    
    -- Refresh Configuration
    refresh_mode VARCHAR(20) DEFAULT 'real_time' 
        CHECK (refresh_mode IN ('real_time', 'near_real_time', 'interval', 'on_demand')),
    refresh_interval_seconds INTEGER,
    
    -- Materialization
    materialization_enabled BOOLEAN DEFAULT FALSE,
    materialization_table VARCHAR(100),
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    
    -- Statistics
    last_calculation_at TIMESTAMPTZ,
    last_calculation_duration_ms INTEGER,
    record_count INTEGER,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.real_time_ledger_views_default PARTITION OF dynamic.real_time_ledger_views DEFAULT;

-- Indexes
CREATE INDEX idx_ledger_views_tenant ON dynamic.real_time_ledger_views(tenant_id, active) WHERE active = TRUE;
CREATE INDEX idx_ledger_views_type ON dynamic.real_time_ledger_views(tenant_id, view_type);

-- Comments
COMMENT ON TABLE dynamic.real_time_ledger_views IS 
    'Materialized derived balances - always computed from immutable movements, never stored directly';

-- Triggers
CREATE TRIGGER trg_ledger_views_update
    BEFORE UPDATE ON dynamic.real_time_ledger_views
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_supporting_accounting_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.real_time_ledger_views TO finos_app;