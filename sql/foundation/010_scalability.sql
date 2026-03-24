-- =============================================================================
-- FINOS CORE KERNEL - SCALABILITY & MONITORING
-- =============================================================================
-- File: 010_scalability.sql
-- Description: RLS foundation, data integrity, replication, performance monitoring
-- Standards: ISO 27001, SOC2
-- =============================================================================

-- SECTION 5: ROW LEVEL SECURITY (RLS) FOUNDATION
-- =============================================================================

-- Helper function to get current tenant from session
CREATE OR REPLACE FUNCTION core.current_tenant_id()
RETURNS UUID AS $$
BEGIN
    RETURN COALESCE(
        current_setting('app.current_tenant', TRUE)::UUID,
        '00000000-0000-0000-0000-000000000000'::UUID
    );
EXCEPTION WHEN OTHERS THEN
    RETURN '00000000-0000-0000-0000-000000000000'::UUID;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION core.current_tenant_id IS 'Returns the current tenant ID from session context';

-- Automatic RLS Policy Generator
CREATE OR REPLACE FUNCTION core.generate_rls_policies(
    p_schema TEXT DEFAULT 'core',
    p_role TEXT DEFAULT 'finos_app'
)
RETURNS TABLE (table_name TEXT, status TEXT) AS $$
DECLARE
    tbl RECORD;
    policy_name TEXT;
    has_rls BOOLEAN;
    has_tenant_id BOOLEAN;
BEGIN
    FOR tbl IN 
        SELECT t.tablename 
        FROM pg_tables t
        WHERE t.schemaname = p_schema
          AND t.tablename NOT IN ('pii_registry', 'regulatory_snapshot_log', 'entity_sequences')
        ORDER BY t.tablename
    LOOP
        table_name := tbl.tablename;
        policy_name := format('%s_tenant_isolation', tbl.tablename);
        
        -- Check if table has tenant_id column
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = p_schema
              AND table_name = tbl.tablename
              AND column_name = 'tenant_id'
        ) INTO has_tenant_id;
        
        IF NOT has_tenant_id THEN
            status := 'Skipped: No tenant_id column';
            RETURN NEXT;
            CONTINUE;
        END IF;
        
        -- Check if table already has RLS enabled
        SELECT c.relrowsecurity INTO has_rls
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = p_schema AND c.relname = tbl.tablename;
        
        BEGIN
            IF NOT has_rls THEN
                -- Enable RLS on the table
                EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY;', p_schema, tbl.tablename);
                
                -- Create tenant isolation policy
                EXECUTE format(
                    'CREATE POLICY %I ON %I.%I 
                     FOR ALL TO %I
                     USING (tenant_id = core.current_tenant_id());',
                    policy_name, p_schema, tbl.tablename, p_role
                );
                
                status := 'RLS enabled and policy created';
            ELSE
                status := 'RLS already enabled';
            END IF;
        EXCEPTION WHEN OTHERS THEN
            status := format('Error: %s', SQLERRM);
        END;
        
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION core.generate_rls_policies IS 'Auto-generates RLS policies for all tables in schema';

-- =============================================================================

-- SECTION 9: DATA INTEGRITY & CONSTRAINTS
-- =============================================================================

-- -4.3: Currency Consistency Enforcement
CREATE OR REPLACE FUNCTION core.enforce_currency_consistency()
RETURNS TRIGGER AS $$
BEGIN
    -- Check for amount fields that require currency
    IF (NEW.amount IS NOT NULL AND NEW.amount != 0) OR 
       (NEW.balance IS NOT NULL AND NEW.balance != 0) OR
       (NEW.debit_amount IS NOT NULL AND NEW.debit_amount != 0) OR
       (NEW.credit_amount IS NOT NULL AND NEW.credit_amount != 0) THEN
        
        IF NEW.currency IS NULL THEN
            RAISE EXCEPTION 'Currency required for non-zero amounts in table %', TG_TABLE_NAME
                USING ERRCODE = 'integrity_constraint_violation';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.enforce_currency_consistency IS 'Validates that non-zero amounts have associated currency';

-- Hard-Delete Prevention
CREATE OR REPLACE FUNCTION core.prevent_hard_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Hard deletes are prohibited. Use soft delete (is_deleted flag) instead.'
        USING ERRCODE = 'prohibited_sql_statement_attempted',
              HINT = 'Set is_deleted = true instead of DELETE';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.prevent_truncate()
RETURNS EVENT_TRIGGER AS $$
BEGIN
    IF TG_TAG = 'TRUNCATE' THEN
        RAISE EXCEPTION 'TRUNCATE operations are prohibited. Use soft delete or archival instead.'
            USING ERRCODE = 'prohibited_sql_statement_attempted';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Apply truncate protection at the end of wiring
COMMENT ON FUNCTION core.prevent_hard_delete IS 'Prevents hard DELETE operations on protected tables';

-- =============================================================================

-- SECTION 10: REPORTING & OBSERVABILITY
-- =============================================================================

-- System metrics table (TimescaleDB hypertable)
CREATE TABLE core_audit.system_metrics (
    time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(28,8),
    metric_unit VARCHAR(20),
    labels JSONB,
    tenant_id UUID
);

SELECT create_hypertable('core_audit.system_metrics', 'time', 
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists => TRUE);

CREATE INDEX idx_system_metrics_name ON core_audit.system_metrics(metric_name, time DESC);

-- Function to record metric
CREATE OR REPLACE FUNCTION core.record_metric(
    p_name VARCHAR,
    p_value DECIMAL,
    p_unit VARCHAR DEFAULT NULL,
    p_labels JSONB DEFAULT '{}',
    p_tenant_id UUID DEFAULT NULL
) RETURNS void AS $$
BEGIN
    INSERT INTO core_audit.system_metrics (metric_name, metric_value, metric_unit, labels, tenant_id)
    VALUES (p_name, p_value, p_unit, p_labels, COALESCE(p_tenant_id, core.current_tenant_id()));
END;
$$ LANGUAGE plpgsql;

-- Error log table
CREATE TABLE core_audit.error_log (
    id BIGSERIAL PRIMARY KEY,
    time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    error_code VARCHAR(50),
    error_message TEXT,
    error_detail TEXT,
    error_hint TEXT,
    context JSONB,
    tenant_id UUID,
    user_id VARCHAR(100),
    transaction_id BIGINT,
    stack_trace TEXT,
    correlation_id UUID
);

CREATE INDEX idx_error_log_time ON core_audit.error_log(time DESC);
CREATE INDEX idx_error_log_code ON core_audit.error_log(error_code);
CREATE INDEX idx_error_log_correlation ON core_audit.error_log(correlation_id) WHERE correlation_id IS NOT NULL;

-- Function to log errors
CREATE OR REPLACE FUNCTION core.log_error(
    p_code VARCHAR,
    p_message TEXT,
    p_detail TEXT DEFAULT NULL,
    p_context JSONB DEFAULT '{}',
    p_correlation_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO core_audit.error_log (
        error_code, error_message, error_detail, context, correlation_id,
        tenant_id, user_id, transaction_id
    ) VALUES (
        p_code, p_message, p_detail, p_context, COALESCE(p_correlation_id, core.current_tenant_id()),
        core.current_tenant_id(),
        current_setting('app.current_user', TRUE),
        txid_current()
    )
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Health Check Full
CREATE OR REPLACE FUNCTION core.health_check_full()
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_table_count INTEGER;
    v_rls_count INTEGER;
    v_index_count INTEGER;
    v_partition_health JSONB;
    v_timescale_status JSONB;
BEGIN
    -- Count tables in core schema
    SELECT COUNT(*) INTO v_table_count
    FROM pg_tables WHERE schemaname = 'core';
    
    -- Count tables with RLS enabled
    SELECT COUNT(*) INTO v_rls_count
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'core' AND c.relrowsecurity = true;
    
    -- Count indexes
    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes WHERE schemaname IN ('core', 'core_history', 'core_crypto', 'core_audit');
    
    -- TimescaleDB status
    SELECT jsonb_build_object(
        'extension_installed', EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb'),
        'hypertable_count', (SELECT COUNT(*) FROM timescaledb_information.hypertables),
        'compression_enabled', EXISTS (SELECT 1 FROM timescaledb_information.compression_settings LIMIT 1)
    ) INTO v_timescale_status;
    
    -- Build comprehensive result
    v_result := jsonb_build_object(
        'timestamp', NOW(),
        'environment', core.get_environment(),
        'tables', jsonb_build_object(
            'total_core_tables', v_table_count,
            'rls_enabled', v_rls_count,
            'rls_coverage_pct', CASE WHEN v_table_count > 0 THEN (v_rls_count::DECIMAL / v_table_count * 100)::INTEGER ELSE 0 END
        ),
        'indexes', jsonb_build_object(
            'total_indexes', v_index_count
        ),
        'timescaledb', v_timescale_status,
        'partition_health', (SELECT jsonb_agg(row_to_json(ph)) FROM core.partition_health_check() ph LIMIT 10),
        'status', CASE 
            WHEN v_rls_count < v_table_count * 0.8 THEN 'WARNING'
            WHEN v_timescale_status->>'extension_installed' = 'false' THEN 'WARNING'
            ELSE 'HEALTHY'
        END
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.health_check_full IS 'Comprehensive health check covering tables, RLS, indexes, and TimescaleDB';

-- =============================================================================

-- SECTION 11: REPLICATION & EVENT STREAMING
-- =============================================================================

-- Create publication for logical replication (run after tables exist)
-- This will be finalized in 019_kernel_wiring.sql
CREATE OR REPLACE FUNCTION core.setup_replication_publication()
RETURNS TEXT AS $$
DECLARE
    v_tables TEXT[];
    v_table TEXT;
BEGIN
    -- Drop existing if present
    DROP PUBLICATION IF EXISTS finos_core_kernel;
    
    -- Create new publication
    CREATE PUBLICATION finos_core_kernel;
    
    -- Add core tables dynamically
    FOR v_table IN 
        SELECT tablename FROM pg_tables 
        WHERE schemaname = 'core' 
          AND tablename NOT LIKE '%_default'
          AND tablename NOT LIKE 'entity_sequences%'
    LOOP
        EXECUTE format('ALTER PUBLICATION finos_core_kernel ADD TABLE core.%I', v_table);
    END LOOP;
    
    -- Add crypto tables
    FOR v_table IN 
        SELECT tablename FROM pg_tables 
        WHERE schemaname = 'core_crypto'
    LOOP
        EXECUTE format('ALTER PUBLICATION finos_core_kernel ADD TABLE core_crypto.%I', v_table);
    END LOOP;
    
    RETURN 'Replication publication finos_core_kernel created with all core tables';
EXCEPTION WHEN OTHERS THEN
    RETURN format('Error: %s', SQLERRM);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.setup_replication_publication IS 'Sets up logical replication publication for core tables';

-- Vault Pattern: Real-time Event Streaming View
CREATE OR REPLACE VIEW core.event_stream AS
SELECT 
    event_id,
    event_time,
    tenant_id,
    event_type,
    event_category,
    payload,
    payload_hash,
    previous_hash,
    event_hash,
    correlation_id,
    causation_id,
    source_service,
    source_version,
    anchor_chain,
    anchor_status
FROM core_crypto.immutable_events
WHERE tenant_id = core.current_tenant_id()
ORDER BY event_time DESC, event_id DESC;

COMMENT ON VIEW core.event_stream IS 'Vault Pattern: Real-time event stream for external consumers and analytics';

-- Event streaming publication (separate for high-volume events)
CREATE OR REPLACE FUNCTION core.setup_event_stream_publication()
RETURNS TEXT AS $$
BEGIN
    DROP PUBLICATION IF EXISTS finos_event_stream;
    CREATE PUBLICATION finos_event_stream FOR TABLE core_crypto.immutable_events;
    RETURN 'Event stream publication finos_event_stream created';
EXCEPTION WHEN OTHERS THEN
    RETURN format('Error: %s', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =============================================================================

-- SECTION 14: PERFORMANCE MONITORING
-- =============================================================================

-- Core Performance Benchmark Views
CREATE OR REPLACE VIEW core.kernel_performance AS
SELECT 
    queryid,
    LEFT(query, 100) AS query_preview,
    calls,
    ROUND(total_exec_time::NUMERIC, 3) AS total_time_ms,
    ROUND(mean_exec_time::NUMERIC, 4) AS mean_time_ms,
    ROUND(stddev_exec_time::NUMERIC, 4) AS stddev_time_ms,
    rows,
    ROUND((100 * total_exec_time / NULLIF((SELECT SUM(total_exec_time) FROM pg_stat_statements), 0))::NUMERIC, 2) AS pct_time
FROM pg_stat_statements
WHERE query LIKE '%core.%' 
   OR query LIKE '%core_history.%'
   OR query LIKE '%core_crypto.%'
ORDER BY total_exec_time DESC;

COMMENT ON VIEW core.kernel_performance IS 'Vault Pattern: Performance metrics for kernel queries';

-- WAL Lag Monitoring View
CREATE OR REPLACE VIEW core.wal_lag_monitoring AS
SELECT 
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replication_lag_bytes,
    pg_wal_lsn_diff(sent_lsn, flush_lsn) AS flush_lag_bytes,
    reply_time
FROM pg_stat_replication
ORDER BY pg_wal_lsn_diff(sent_lsn, replay_lsn) DESC;

COMMENT ON VIEW core.wal_lag_monitoring IS 'Real-time WAL lag monitoring for replication health';

-- Materialized View Refresh Function with Concurrent Support
CREATE OR REPLACE FUNCTION core.refresh_materialized_view(
    p_view_name TEXT,
    p_concurrent BOOLEAN DEFAULT TRUE
)
RETURNS TEXT AS $$
BEGIN
    IF p_concurrent THEN
        EXECUTE format('REFRESH MATERIALIZED VIEW CONCURRENTLY %I', p_view_name);
    ELSE
        EXECUTE format('REFRESH MATERIALIZED VIEW %I', p_view_name);
    END IF;
    RETURN format('Refreshed %s', p_view_name);
EXCEPTION WHEN OTHERS THEN
    RETURN format('Error refreshing %s: %s', p_view_name, SQLERRM);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.refresh_materialized_view IS 'Refreshes materialized view with optional concurrent mode';

-- =============================================================================
