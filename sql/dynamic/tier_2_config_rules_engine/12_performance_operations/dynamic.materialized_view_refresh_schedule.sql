-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 12 - Performance Operations
-- TABLE: dynamic.materialized_view_refresh_schedule
-- COMPLIANCE: ITIL
--   - ISO 20000
--   - ISO 27001
--   - BCBS 239
-- ============================================================================


CREATE TABLE dynamic.materialized_view_refresh_schedule (

    schedule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- View Details
    view_name VARCHAR(200) NOT NULL,
    view_schema VARCHAR(100) DEFAULT 'dynamic',
    view_description TEXT,
    
    -- Refresh Strategy
    refresh_strategy VARCHAR(20) DEFAULT 'INCREMENTAL' 
        CHECK (refresh_strategy IN ('FULL', 'INCREMENTAL', 'CONCURRENT')),
    refresh_cron VARCHAR(100) NOT NULL, -- Cron expression
    refresh_timezone VARCHAR(50) DEFAULT 'UTC',
    
    -- Conditions
    refresh_condition TEXT, -- SQL condition to check before refresh
    
    -- Dependencies
    depends_on_views TEXT[],
    depends_on_tables TEXT[],
    
    -- Performance
    parallel_workers INTEGER,
    statement_timeout_seconds INTEGER DEFAULT 3600,
    
    -- Notifications
    notify_on_failure BOOLEAN DEFAULT TRUE,
    notification_emails TEXT[],
    
    -- Statistics
    last_refresh_time TIMESTAMPTZ,
    last_refresh_duration_seconds INTEGER,
    last_refresh_row_count BIGINT,
    last_refresh_status VARCHAR(20),
    last_refresh_error TEXT,
    
    -- History
    total_refreshes INTEGER DEFAULT 0,
    failed_refreshes INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    paused BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_view_schedule UNIQUE (tenant_id, view_schema, view_name)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.materialized_view_refresh_schedule_default PARTITION OF dynamic.materialized_view_refresh_schedule DEFAULT;

-- Indexes
CREATE INDEX idx_mv_schedule_active ON dynamic.materialized_view_refresh_schedule(tenant_id) WHERE is_active = TRUE AND paused = FALSE;

-- Comments
COMMENT ON TABLE dynamic.materialized_view_refresh_schedule IS 'Denormalized reporting table refresh schedules';

-- Triggers
CREATE TRIGGER trg_mv_refresh_schedule_audit
    BEFORE UPDATE ON dynamic.materialized_view_refresh_schedule
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.materialized_view_refresh_schedule TO finos_app;