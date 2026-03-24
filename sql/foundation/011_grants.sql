-- =============================================================================
-- FINOS CORE KERNEL - GRANTS & PERMISSIONS
-- =============================================================================
-- File: 011_grants.sql
-- Description: All GRANT statements for roles and objects
-- =============================================================================

-- SECTION 3: ROLES AND PERMISSIONS
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'finos_app') THEN
        CREATE ROLE finos_app WITH LOGIN PASSWORD 'changeme_in_production';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'finos_readonly') THEN
        CREATE ROLE finos_readonly WITH LOGIN PASSWORD 'changeme_in_production';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'finos_admin') THEN
        CREATE ROLE finos_admin WITH LOGIN PASSWORD 'changeme_in_production';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'finos_replication') THEN
        CREATE ROLE finos_replication WITH REPLICATION LOGIN PASSWORD 'changeme_in_production';
    END IF;
END
$$;

-- Grant schema usage
GRANT USAGE ON SCHEMA core TO finos_app, finos_readonly, finos_admin, finos_replication;
GRANT USAGE ON SCHEMA core_history TO finos_app, finos_readonly, finos_admin;
GRANT USAGE ON SCHEMA core_crypto TO finos_app, finos_admin, finos_replication;
GRANT USAGE ON SCHEMA core_audit TO finos_app, finos_admin;
GRANT USAGE ON SCHEMA core_reporting TO finos_app, finos_readonly, finos_admin;

-- Grant sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core TO finos_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core_history TO finos_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core_crypto TO finos_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA core_audit TO finos_app;

-- =============================================================================

-- SECTION 21: SOFT DELETE RESTORE FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION core.restore_soft_deleted(
    p_table TEXT,
    p_record_id UUID,
    p_restored_by VARCHAR(100) DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    EXECUTE format(
        'UPDATE core.%I SET is_deleted = FALSE, deleted_at = NULL, deleted_by = NULL, updated_at = NOW(), restored_by = %L, restored_at = NOW() WHERE id = %L',
        p_table, p_restored_by, p_record_id
    );
    RETURN FOUND;
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.restore_soft_deleted IS 'Restores a soft-deleted record by ID';

-- =============================================================================

-- SECTION 23: ENHANCED GRANTS FOR NEW OBJECTS
-- =============================================================================

GRANT SELECT, INSERT, UPDATE ON core.rate_limit_policies TO finos_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON core.rate_limit_counters TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.webhook_subscriptions TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.webhook_deliveries TO finos_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON core.scheduled_jobs TO finos_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON core.cache_entries TO finos_app;
GRANT SELECT, INSERT ON core_audit.algorithm_executions TO finos_app;

GRANT SELECT ON core.wal_lag_monitoring TO finos_app, finos_readonly;

GRANT EXECUTE ON FUNCTION core.refresh_materialized_view TO finos_app;
GRANT EXECUTE ON FUNCTION core.generate_secure_token TO finos_app;
GRANT EXECUTE ON FUNCTION core.calculate_emi TO finos_app;
GRANT EXECUTE ON FUNCTION core.calculate_age TO finos_app;
GRANT EXECUTE ON FUNCTION core.format_currency TO finos_app;
GRANT EXECUTE ON FUNCTION core.cleanup_expired_cache TO finos_app;
GRANT EXECUTE ON FUNCTION core.restore_soft_deleted TO finos_app;
GRANT EXECUTE ON FUNCTION core.create_tenant_partitions TO finos_admin;
GRANT EXECUTE ON FUNCTION core.disable_triggers_for_bulk_load TO finos_admin;
GRANT EXECUTE ON FUNCTION core.enable_triggers_after_bulk_load TO finos_admin;
GRANT EXECUTE ON FUNCTION core.get_tenant_data_size TO finos_app, finos_admin;
GRANT SELECT ON core.partition_health_monitor TO finos_app, finos_readonly;

-- =============================================================================

-- SECTION 24: FINAL GRANTS
-- =============================================================================

GRANT SELECT, INSERT, UPDATE ON core.pii_registry TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.regulatory_snapshot_log TO finos_app;

GRANT SELECT, INSERT ON core_audit.audit_log TO finos_app;
GRANT SELECT, INSERT ON core_audit.system_metrics TO finos_app;
GRANT SELECT, INSERT ON core_audit.error_log TO finos_app;

GRANT SELECT ON core.event_stream TO finos_app, finos_readonly;
GRANT SELECT ON core.kernel_performance TO finos_app, finos_readonly;

GRANT EXECUTE ON FUNCTION core.current_tenant_id TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.get_environment TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.generate_rls_policies TO finos_admin;
GRANT EXECUTE ON FUNCTION core.register_pii_field TO finos_app;
GRANT EXECUTE ON FUNCTION core.encrypt_data TO finos_app;
GRANT EXECUTE ON FUNCTION core.decrypt_data TO finos_app;
GRANT EXECUTE ON FUNCTION core.hash_data TO finos_app;
GRANT EXECUTE ON FUNCTION core.mask_pii TO finos_app;
GRANT EXECUTE ON FUNCTION core.mask_email TO finos_app;
GRANT EXECUTE ON FUNCTION core.mask_phone TO finos_app;
GRANT EXECUTE ON FUNCTION core.setup_partman_for_table TO finos_admin;
GRANT EXECUTE ON FUNCTION core.partition_health_check TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.health_check_full TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.as_of TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.util_uuid_v7 TO finos_app;
GRANT EXECUTE ON FUNCTION core.util_business_days_between TO finos_app;
GRANT EXECUTE ON FUNCTION core.util_validate_iban TO finos_app;
GRANT EXECUTE ON FUNCTION core.util_auto_create_partitions TO finos_admin;
GRANT EXECUTE ON FUNCTION core.setup_replication_publication TO finos_admin;
GRANT EXECUTE ON FUNCTION core.setup_event_stream_publication TO finos_admin;
