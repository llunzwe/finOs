-- =============================================================================
-- FINOS CORE KERNEL - PARTITIONING & SCALE ENHANCEMENTS
-- =============================================================================
-- File: 004_partitioning.sql
-- Description: Partition management, sub-partitioning, and scalability utilities
-- Dependencies: pg_partman (optional)
-- =============================================================================

-- SECTION 8: PARTITIONING & SCALE ENHANCEMENTS
-- =============================================================================

-- pg_partman setup helper
CREATE OR REPLACE FUNCTION core.setup_partman_for_table(
    p_table TEXT,
    p_column TEXT,
    p_interval TEXT,
    p_retention TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_result TEXT;
BEGIN
    -- Check if pg_partman is available
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_partman') THEN
        EXECUTE format(
            'SELECT partman.create_parent(p_parent_table := %L, p_control := %L, p_type := %L, p_interval := %L)',
            p_table, p_column, 'native', p_interval
        );
        
        IF p_retention IS NOT NULL THEN
            EXECUTE format(
                'UPDATE partman.part_config SET retention = %L, retention_keep_table = false WHERE parent_table = %L',
                p_retention, p_table
            );
        END IF;
        
        v_result := format('pg_partman configured for %s', p_table);
    ELSE
        v_result := format('pg_partman not available, skipping %s', p_table);
    END IF;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN format('Error: %s', SQLERRM);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.setup_partman_for_table IS 'Sets up pg_partman for automatic partition management';

-- Partition Health Monitoring
CREATE OR REPLACE FUNCTION core.partition_health_check()
RETURNS TABLE (
    table_name TEXT,
    partition_name TEXT,
    status TEXT,
    size_bytes BIGINT,
    dead_tuples BIGINT,
    recommendation TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.nspname || '.' || c.relname::TEXT AS table_name,
        COALESCE(c2.relname, 'N/A')::TEXT AS partition_name,
        CASE 
            WHEN s.n_dead_tup > 1000 THEN 'WARNING'
            WHEN pg_relation_size(c.oid) > 1073741824 THEN 'REVIEW' -- > 1GB
            ELSE 'OK'
        END::TEXT AS status,
        pg_relation_size(c.oid)::BIGINT AS size_bytes,
        s.n_dead_tup::BIGINT AS dead_tuples,
        CASE 
            WHEN s.n_dead_tup > 10000 THEN 'Run VACUUM'
            WHEN pg_relation_size(c.oid) > 5368709120 THEN 'Consider splitting partition' -- > 5GB
            ELSE 'No action needed'
        END::TEXT AS recommendation
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    LEFT JOIN pg_stat_user_tables s ON s.relid = c.oid
    LEFT JOIN pg_inherits i ON i.inhrelid = c.oid
    LEFT JOIN pg_class c2 ON c2.oid = i.inhparent
    WHERE n.nspname IN ('core', 'core_history', 'core_crypto', 'core_audit')
      AND c.relkind IN ('r', 'p')
    ORDER BY pg_relation_size(c.oid) DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.partition_health_check IS 'Monitors partition health including dead tuples and size';

-- =============================================================================

-- SECTION 22: SCALABILITY UTILITIES
-- =============================================================================

-- Function to create partitions for ALL partitioned tables for a tenant
CREATE OR REPLACE FUNCTION core.create_tenant_partitions(p_tenant_id UUID)
RETURNS TABLE (table_name TEXT, partition_name TEXT, status TEXT) AS $$
DECLARE
    v_partition_suffix TEXT;
    v_table RECORD;
    v_partition_exists BOOLEAN;
BEGIN
    v_partition_suffix := REPLACE(p_tenant_id::text, '-', '_');
    
    FOR v_table IN 
        SELECT c.relname as tbl_name
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'core'
          AND c.relkind = 'p'
          AND EXISTS (
              SELECT 1 FROM pg_attribute a
              WHERE a.attrelid = c.oid AND a.attname = 'tenant_id'
          )
        ORDER BY c.relname
    LOOP
        table_name := v_table.tbl_name;
        partition_name := format('%s_%s', v_table.tbl_name, v_partition_suffix);
        
        SELECT EXISTS (
            SELECT 1 FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'core' AND c.relname = partition_name
        ) INTO v_partition_exists;
        
        IF v_partition_exists THEN
            status := 'EXISTS';
        ELSE
            BEGIN
                EXECUTE format(
                    'CREATE TABLE IF NOT EXISTS core.%I PARTITION OF core.%I FOR VALUES IN (%L)',
                    partition_name, v_table.tbl_name, p_tenant_id
                );
                status := 'CREATED';
            EXCEPTION WHEN OTHERS THEN
                status := format('ERROR: %s', SQLERRM);
            END;
        END IF;
        
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.create_tenant_partitions IS 'Creates tenant-specific partitions for ALL partitioned tables';

-- Function to disable triggers for bulk loads
CREATE OR REPLACE FUNCTION core.disable_triggers_for_bulk_load(p_table TEXT)
RETURNS TEXT AS $$
BEGIN
    EXECUTE format('ALTER TABLE core.%I DISABLE TRIGGER ALL', p_table);
    RETURN format('Triggers disabled for core.%s', p_table);
EXCEPTION WHEN OTHERS THEN
    RETURN format('Error: %s', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- Function to re-enable triggers after bulk load
CREATE OR REPLACE FUNCTION core.enable_triggers_after_bulk_load(p_table TEXT)
RETURNS TEXT AS $$
BEGIN
    EXECUTE format('ALTER TABLE core.%I ENABLE TRIGGER ALL', p_table);
    RETURN format('Triggers enabled for core.%s', p_table);
EXCEPTION WHEN OTHERS THEN
    RETURN format('Error: %s', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- Partition health monitoring view
CREATE OR REPLACE VIEW core.partition_health_monitor AS
SELECT 
    n.nspname AS schema_name,
    parent.relname AS parent_table,
    c.relname AS partition_name,
    pg_table_size(c.oid) AS size_bytes,
    pg_indexes_size(c.oid) AS index_size_bytes,
    pg_total_relation_size(c.oid) AS total_size_bytes,
    COALESCE(pg_stat_user_tables.n_live_tup, 0) AS live_tuples,
    COALESCE(pg_stat_user_tables.n_dead_tup, 0) AS dead_tuples,
    pg_stat_user_tables.last_vacuum,
    pg_stat_user_tables.last_autovacuum,
    CASE 
        WHEN COALESCE(pg_stat_user_tables.n_dead_tup, 0) > GREATEST(COALESCE(pg_stat_user_tables.n_live_tup, 0), 1000) * 0.1 THEN 'NEEDS_VACUUM'
        WHEN pg_table_size(c.oid) > 10737418240 THEN 'LARGE_PARTITION'
        ELSE 'HEALTHY'
    END AS health_status
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_inherits i ON i.inhrelid = c.oid
JOIN pg_class parent ON parent.oid = i.inhparent
LEFT JOIN pg_stat_user_tables ON pg_stat_user_tables.relid = c.oid
WHERE n.nspname = 'core'
  AND c.relkind = 'r'
ORDER BY pg_total_relation_size(c.oid) DESC;

COMMENT ON VIEW core.partition_health_monitor IS 'Monitors partition sizes, bloat, and health status';

-- Function to get tenant data size summary
CREATE OR REPLACE FUNCTION core.get_tenant_data_size(p_tenant_id UUID)
RETURNS TABLE (
    table_name TEXT,
    partition_count INTEGER,
    total_size_bytes BIGINT,
    total_rows BIGINT
) AS $$
DECLARE
    v_tenant_suffix TEXT;
BEGIN
    v_tenant_suffix := REPLACE(p_tenant_id::text, '-', '_');
    
    RETURN QUERY
    SELECT 
        parent.relname::TEXT,
        COUNT(*)::INTEGER as partition_count,
        SUM(pg_total_relation_size(c.oid))::BIGINT as total_size_bytes,
        SUM(COALESCE(pg_stat_user_tables.n_live_tup, 0))::BIGINT as total_rows
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_inherits i ON i.inhrelid = c.oid
    JOIN pg_class parent ON parent.oid = i.inhparent
    LEFT JOIN pg_stat_user_tables ON pg_stat_user_tables.relid = c.oid
    WHERE n.nspname = 'core'
      AND c.relname LIKE '%' || v_tenant_suffix
      AND c.relkind = 'r'
    GROUP BY parent.relname
    ORDER BY SUM(pg_total_relation_size(c.oid)) DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.get_tenant_data_size IS 'Returns data size summary for all partitions of a tenant';

-- =============================================================================
-- SECTION 23: CITUS HORIZONTAL SHARDING (Trillion-Row Scale)
-- =============================================================================

-- Function: Setup Citus distribution for a table
CREATE OR REPLACE FUNCTION core.setup_citus_distribution(
    p_schema TEXT,
    p_table TEXT,
    p_distribution_column TEXT DEFAULT 'tenant_id',
    p_distribution_type TEXT DEFAULT 'hash'
)
RETURNS TEXT AS $$
DECLARE
    v_full_table_name TEXT;
    v_result TEXT;
BEGIN
    v_full_table_name := format('%I.%I', p_schema, p_table);
    
    -- Check if Citus is available
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'citus') THEN
        RETURN 'Citus extension not available - table remains non-distributed';
    END IF;
    
    -- Check if already distributed
    IF EXISTS (SELECT 1 FROM pg_dist_partition WHERE logicalrelid = v_full_table_name::regclass) THEN
        RETURN format('Table %s is already distributed', v_full_table_name);
    END IF;
    
    -- Create distributed table
    EXECUTE format('SELECT create_distributed_table(%L, %L)', v_full_table_name, p_distribution_column);
    
    v_result := format('Distributed %s by %s', v_full_table_name, p_distribution_column);
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN format('Error distributing %s: %s', v_full_table_name, SQLERRM);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.setup_citus_distribution IS 'Sets up Citus horizontal sharding for a table by tenant_id';

-- Function: Get Citus cluster statistics
CREATE OR REPLACE FUNCTION core.citus_cluster_stats()
RETURNS TABLE (
    table_name TEXT,
    distribution_column TEXT,
    shard_count INTEGER,
    shard_placement_policy TEXT,
    total_size_bytes BIGINT,
    total_rows BIGINT
) AS $$
BEGIN
    -- Check if Citus is available
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'citus') THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        p.logicalrelid::TEXT,
        p.partkey::TEXT,
        (SELECT COUNT(*)::INTEGER FROM pg_dist_shard WHERE logicalrelid = p.logicalrelid),
        'shard_placement_policy'::TEXT,
        0::BIGINT,
        0::BIGINT
    FROM pg_dist_partition p;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.citus_cluster_stats IS 'Returns Citus distributed table statistics';

-- Function: Rebalance shards across workers
CREATE OR REPLACE FUNCTION core.rebalance_citus_shards()
RETURNS TEXT AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'citus') THEN
        RETURN 'Citus not available';
    END IF;
    
    EXECUTE 'SELECT rebalance_table_shards()';
    RETURN 'Shard rebalancing initiated';
EXCEPTION WHEN OTHERS THEN
    RETURN format('Rebalancing error: %s', SQLERRM);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.rebalance_citus_shards IS 'Rebalances Citus shards across worker nodes';

-- =============================================================================
