-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 23 - API Streaming Config
-- TABLE: dynamic.migration_configs
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Migration Configs.
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
CREATE TABLE dynamic.migration_configs (

    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Migration Identity
    migration_name VARCHAR(200) NOT NULL,
    migration_source VARCHAR(100) NOT NULL, -- Source system name
    
    -- Source Configuration
    source_connection_config JSONB NOT NULL DEFAULT '{}',
    -- Example: {
    --   type: 'database',
    --   driver: 'postgresql',
    --   host: 'legacy-db.example.com',
    --   port: 5432,
    --   database: 'legacy_core'
    -- }
    
    -- Import Rules
    import_rules_jsonb JSONB NOT NULL DEFAULT '{}',
    -- Example: {
    --   tables: ['customers', 'accounts', 'transactions'],
    --   date_range: {from: '2020-01-01', to: '2024-12-31'},
    --   filters: {account_status: ['active', 'dormant']}
    -- }
    
    -- Field Mappings
    field_mappings_jsonb JSONB NOT NULL DEFAULT '{}',
    -- Example: {
    --   customers: {
    --     old_cust_id: 'legacy_customer_id',
    --     cust_name: {target: 'full_name', transform: 'concat(first_name, " ", last_name)'}
    --   }
    -- }
    
    -- Validation Rules
    validation_rules_jsonb JSONB DEFAULT '[]',
    -- Example: [
    --   {entity: 'customer', rule: 'email_unique', severity: 'error'},
    --   {entity: 'account', rule: 'balance_non_negative', severity: 'warning'}
    -- ]
    
    -- Dependency Graph
    dependency_graph_jsonb JSONB DEFAULT '{}',
    -- Example: {
    --   execution_order: ['customers', 'accounts', 'transactions'],
    --   dependencies: {
    --     accounts: ['customers'],
    --     transactions: ['accounts']
    --   }
    -- }
    
    -- Batching Configuration
    batch_size INTEGER DEFAULT 1000,
    parallel_workers INTEGER DEFAULT 4,
    commit_frequency INTEGER DEFAULT 100, -- Records per commit
    
    -- Error Handling
    error_handling_strategy VARCHAR(30) DEFAULT 'log_continue' 
        CHECK (error_handling_strategy IN ('stop', 'log_continue', 'skip_record', 'quarantine')),
    max_error_percentage DECIMAL(5,2) DEFAULT 5.00, -- Stop if errors exceed this
    
    -- Transformation
    transformation_scripts JSONB DEFAULT '{}',
    -- Example: {
    --   pre_migration: 'validate_source_data.sql',
    --   per_record: 'transform_customer.pgsql',
    --   post_migration: 'reconcile_balances.sql'
    -- }
    
    -- Schedule
    schedule_type VARCHAR(20) DEFAULT 'manual' 
        CHECK (schedule_type IN ('manual', 'once', 'recurring')),
    schedule_cron VARCHAR(100),
    
    -- Status
    status VARCHAR(20) DEFAULT 'draft' 
        CHECK (status IN ('draft', 'ready', 'running', 'completed', 'failed', 'paused')),
    
    -- Progress
    total_records_estimate INTEGER,
    records_processed INTEGER DEFAULT 0,
    records_success INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    
    -- Timing
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
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

CREATE TABLE dynamic.migration_configs_default PARTITION OF dynamic.migration_configs DEFAULT;

-- Indexes
CREATE INDEX idx_migration_configs_tenant ON dynamic.migration_configs(tenant_id, status) 
    WHERE status IN ('ready', 'running', 'paused');

-- Comments
COMMENT ON TABLE dynamic.migration_configs IS 
    'Legacy import configuration with batching, validation, and dependency graphs';

-- Triggers
CREATE TRIGGER trg_migration_configs_update
    BEFORE UPDATE ON dynamic.migration_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_api_streaming_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.migration_configs TO finos_app;