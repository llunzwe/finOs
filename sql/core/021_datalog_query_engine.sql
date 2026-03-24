-- =============================================================================
-- FINOS CORE KERNEL - DATALOG QUERY ENGINE
-- =============================================================================
-- File: core/021_datalog_query_engine.sql
-- Description: Datalog-style query functions for the datom model
--              Enables pattern matching, recursive queries, and as-of queries
-- Standards: Datalog, Prolog-style pattern matching
-- =============================================================================

-- =============================================================================
-- ADVANCED DATOMIC-STYLE QUERIES
-- =============================================================================

-- Function: Universal datom query (pattern matching)
-- Pattern: [e a v tx op] - NULL means "don't care"
CREATE OR REPLACE FUNCTION core.datom_query(
    p_tenant_id UUID,
    p_entity_id UUID DEFAULT NULL,
    p_attribute VARCHAR DEFAULT NULL,
    p_value JSONB DEFAULT NULL,
    p_as_of_tx BIGINT DEFAULT NULL,
    p_operation CHAR DEFAULT '+'
)
RETURNS TABLE (
    entity_id UUID,
    attribute VARCHAR,
    value JSONB,
    tx_id BIGINT,
    operation CHAR,
    valid_time TIMESTAMPTZ,
    event_hash VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ie.datom_entity_id,
        ie.datom_attribute,
        ie.datom_value,
        ie.event_id,
        ie.datom_operation,
        ie.datom_valid_time,
        ie.event_hash
    FROM core_crypto.immutable_events ie
    WHERE ie.tenant_id = p_tenant_id
      AND (p_entity_id IS NULL OR ie.datom_entity_id = p_entity_id)
      AND (p_attribute IS NULL OR ie.datom_attribute = p_attribute)
      AND (p_value IS NULL OR ie.datom_value @> p_value)
      AND (p_as_of_tx IS NULL OR ie.event_id <= p_as_of_tx)
      AND (p_operation IS NULL OR ie.datom_operation = p_operation)
    ORDER BY ie.event_id DESC;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.datom_query IS 'Universal Datalog-style datom query with pattern matching';

-- Function: Get database "as of" a specific transaction
-- Returns the state of all entities at that point in time
CREATE OR REPLACE FUNCTION core.datoms_as_of(
    p_tenant_id UUID,
    p_as_of_tx BIGINT
)
RETURNS TABLE (
    entity_id UUID,
    attribute VARCHAR,
    value JSONB,
    tx_id BIGINT,
    valid_time TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    WITH latest_assertions AS (
        SELECT DISTINCT ON (datom_entity_id, datom_attribute)
            datom_entity_id,
            datom_attribute,
            datom_value,
            event_id,
            datom_valid_time,
            datom_operation
        FROM core_crypto.immutable_events
        WHERE tenant_id = p_tenant_id
          AND event_id <= p_as_of_tx
          AND datom_entity_id IS NOT NULL
          AND datom_attribute IS NOT NULL
        ORDER BY datom_entity_id, datom_attribute, event_id DESC
    )
    SELECT 
        datom_entity_id,
        datom_attribute,
        datom_value,
        event_id,
        datom_valid_time
    FROM latest_assertions
    WHERE datom_operation = '+';  -- Exclude retracted facts
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.datoms_as_of IS 'Returns all datoms as of a specific transaction (point-in-time query)';

-- Function: Get database "since" a specific transaction
-- Returns all changes after a point in time
CREATE OR REPLACE FUNCTION core.datoms_since(
    p_tenant_id UUID,
    p_since_tx BIGINT
)
RETURNS TABLE (
    entity_id UUID,
    attribute VARCHAR,
    value JSONB,
    operation CHAR,
    tx_id BIGINT,
    tx_time TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ie.datom_entity_id,
        ie.datom_attribute,
        ie.datom_value,
        ie.datom_operation,
        ie.event_id,
        ie.event_time
    FROM core_crypto.immutable_events ie
    WHERE ie.tenant_id = p_tenant_id
      AND ie.event_id > p_since_tx
      AND ie.datom_entity_id IS NOT NULL
    ORDER BY ie.event_id;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.datoms_since IS 'Returns all datoms changed since a specific transaction';

-- Function: Get entity at a specific point in time
CREATE OR REPLACE FUNCTION core.entity_as_of(
    p_tenant_id UUID,
    p_entity_id UUID,
    p_as_of_tx BIGINT DEFAULT NULL
)
RETURNS TABLE (
    attribute VARCHAR,
    value JSONB,
    tx_id BIGINT,
    valid_time TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        da.attribute,
        da.value,
        da.tx_id,
        da.valid_time
    FROM core.datoms_as_of(p_tenant_id, COALESCE(p_as_of_tx, 9223372036854775807::BIGINT)) da
    WHERE da.entity_id = p_entity_id;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.entity_as_of IS 'Returns an entity state as of a specific transaction';

-- Function: Find entities by attribute pattern (VAET index simulation)
CREATE OR REPLACE FUNCTION core.find_entities_by_value(
    p_tenant_id UUID,
    p_attribute VARCHAR,
    p_value_pattern JSONB,
    p_as_of_tx BIGINT DEFAULT NULL
)
RETURNS TABLE (
    entity_id UUID,
    value JSONB,
    tx_id BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (ie.datom_entity_id)
        ie.datom_entity_id,
        ie.datom_value,
        ie.event_id
    FROM core_crypto.immutable_events ie
    WHERE ie.tenant_id = p_tenant_id
      AND ie.datom_attribute = p_attribute
      AND ie.datom_value @> p_value_pattern
      AND (p_as_of_tx IS NULL OR ie.event_id <= p_as_of_tx)
      AND ie.datom_operation = '+'
    ORDER BY ie.datom_entity_id, ie.event_id DESC;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.find_entities_by_value IS 'Finds all entities with a specific attribute value pattern';

-- =============================================================================
-- TEMPORAL QUERIES (VALID TIME)
-- =============================================================================

-- Function: Get entity history across valid time
CREATE OR REPLACE FUNCTION core.entity_valid_time_history(
    p_tenant_id UUID,
    p_entity_id UUID,
    p_attribute VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    value JSONB,
    valid_from TIMESTAMPTZ,
    valid_to TIMESTAMPTZ,
    tx_id BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH history AS (
        SELECT 
            ie.datom_value,
            ie.datom_valid_time AS valid_from,
            ie.event_id,
            LEAD(ie.datom_valid_time) OVER (PARTITION BY ie.datom_attribute ORDER BY ie.datom_valid_time) AS valid_to,
            ie.datom_operation
        FROM core_crypto.immutable_events ie
        WHERE ie.tenant_id = p_tenant_id
          AND ie.datom_entity_id = p_entity_id
          AND (p_attribute IS NULL OR ie.datom_attribute = p_attribute)
        ORDER BY ie.datom_valid_time
    )
    SELECT 
        h.datom_value,
        h.valid_from,
        COALESCE(h.valid_to, '9999-12-31 23:59:59+00'::timestamptz) AS valid_to,
        h.event_id
    FROM history h
    WHERE h.datom_operation = '+';
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.entity_valid_time_history IS 'Returns entity history across valid time periods';

-- Function: What was true at a specific valid time?
CREATE OR REPLACE FUNCTION core.entity_at_valid_time(
    p_tenant_id UUID,
    p_entity_id UUID,
    p_valid_time TIMESTAMPTZ
)
RETURNS TABLE (
    attribute VARCHAR,
    value JSONB,
    tx_id BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (ie.datom_attribute)
        ie.datom_attribute,
        ie.datom_value,
        ie.event_id
    FROM core_crypto.immutable_events ie
    WHERE ie.tenant_id = p_tenant_id
      AND ie.datom_entity_id = p_entity_id
      AND ie.datom_valid_time <= p_valid_time
      AND ie.datom_operation = '+'
    ORDER BY ie.datom_attribute, ie.datom_valid_time DESC;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.entity_at_valid_time IS 'Returns entity state at a specific valid time (business time)';

-- =============================================================================
-- GRAPH/RELATIONSHIP QUERIES
-- =============================================================================

-- Function: Find related entities through attribute relationships
CREATE OR REPLACE FUNCTION core.find_related_entities(
    p_tenant_id UUID,
    p_entity_id UUID,
    p_relationship_attribute VARCHAR DEFAULT 'related_to',
    p_depth INTEGER DEFAULT 1
)
RETURNS TABLE (
    related_entity_id UUID,
    relationship_path TEXT[],
    depth INTEGER
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE related AS (
        -- Base case: direct relationships
        SELECT 
            (ie.datom_value->>'entity_id')::UUID AS rel_id,
            ARRAY[ie.datom_attribute]::TEXT[] AS path,
            1 AS d
        FROM core_crypto.immutable_events ie
        WHERE ie.tenant_id = p_tenant_id
          AND ie.datom_entity_id = p_entity_id
          AND ie.datom_attribute = p_relationship_attribute
          AND ie.datom_operation = '+'
        
        UNION ALL
        
        -- Recursive case: follow relationships
        SELECT 
            (ie.datom_value->>'entity_id')::UUID,
            r.path || ie.datom_attribute,
            r.d + 1
        FROM related r
        JOIN core_crypto.immutable_events ie ON ie.datom_entity_id = r.rel_id
        WHERE ie.tenant_id = p_tenant_id
          AND ie.datom_attribute = p_relationship_attribute
          AND ie.datom_operation = '+'
          AND r.d < p_depth
          AND (ie.datom_value->>'entity_id')::UUID NOT IN (SELECT UNNEST(r.path))
    )
    SELECT 
        r.rel_id,
        r.path,
        r.d
    FROM related r
    WHERE r.rel_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.find_related_entities IS 'Finds entities related through graph traversal';

-- =============================================================================
-- AGGREGATION QUERIES
-- =============================================================================

-- Function: Aggregate attribute values over time
CREATE OR REPLACE FUNCTION core.aggregate_attribute_history(
    p_tenant_id UUID,
    p_attribute VARCHAR,
    p_aggregation_type VARCHAR DEFAULT 'count',  -- count, sum, avg, min, max
    p_start_tx BIGINT DEFAULT NULL,
    p_end_tx BIGINT DEFAULT NULL
)
RETURNS TABLE (
    entity_count BIGINT,
    total_value NUMERIC,
    average_value NUMERIC,
    min_value NUMERIC,
    max_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH latest_values AS (
        SELECT DISTINCT ON (ie.datom_entity_id)
            ie.datom_entity_id,
            (ie.datom_value->>'amount')::NUMERIC AS val
        FROM core_crypto.immutable_events ie
        WHERE ie.tenant_id = p_tenant_id
          AND ie.datom_attribute = p_attribute
          AND (p_start_tx IS NULL OR ie.event_id >= p_start_tx)
          AND (p_end_tx IS NULL OR ie.event_id <= p_end_tx)
          AND ie.datom_operation = '+'
          AND ie.datom_value ? 'amount'
        ORDER BY ie.datom_entity_id, ie.event_id DESC
    )
    SELECT 
        COUNT(*),
        SUM(val),
        AVG(val),
        MIN(val),
        MAX(val)
    FROM latest_values;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.aggregate_attribute_history IS 'Aggregates numeric attribute values over time';

-- =============================================================================
-- CHANGE DETECTION
-- =============================================================================

-- Function: Detect changes between two transactions
CREATE OR REPLACE FUNCTION core.detect_changes(
    p_tenant_id UUID,
    p_from_tx BIGINT,
    p_to_tx BIGINT
)
RETURNS TABLE (
    entity_id UUID,
    attribute VARCHAR,
    old_value JSONB,
    new_value JSONB,
    change_type VARCHAR  -- added, modified, retracted
) AS $$
BEGIN
    RETURN QUERY
    WITH before_state AS (
        SELECT DISTINCT ON (datom_entity_id, datom_attribute)
            datom_entity_id,
            datom_attribute,
            datom_value,
            datom_operation
        FROM core_crypto.immutable_events
        WHERE tenant_id = p_tenant_id
          AND event_id <= p_from_tx
        ORDER BY datom_entity_id, datom_attribute, event_id DESC
    ),
    after_state AS (
        SELECT DISTINCT ON (datom_entity_id, datom_attribute)
            datom_entity_id,
            datom_attribute,
            datom_value,
            datom_operation
        FROM core_crypto.immutable_events
        WHERE tenant_id = p_tenant_id
          AND event_id <= p_to_tx
        ORDER BY datom_entity_id, datom_attribute, event_id DESC
    )
    SELECT 
        COALESCE(b.datom_entity_id, a.datom_entity_id),
        COALESCE(b.datom_attribute, a.datom_attribute),
        CASE WHEN b.datom_operation = '+' THEN b.datom_value ELSE NULL END,
        CASE WHEN a.datom_operation = '+' THEN a.datom_value ELSE NULL END,
        CASE 
            WHEN b.datom_entity_id IS NULL THEN 'added'
            WHEN a.datom_entity_id IS NULL THEN 'retracted'
            WHEN b.datom_value != a.datom_value THEN 'modified'
            ELSE 'unchanged'
        END::VARCHAR
    FROM before_state b
    FULL OUTER JOIN after_state a ON 
        b.datom_entity_id = a.datom_entity_id 
        AND b.datom_attribute = a.datom_attribute
    WHERE b.datom_value IS DISTINCT FROM a.datom_value
      OR b.datom_operation IS DISTINCT FROM a.datom_operation;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.detect_changes IS 'Detects all changes between two transaction points';

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT EXECUTE ON FUNCTION core.datom_query TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.datoms_as_of TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.datoms_since TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.entity_as_of TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.find_entities_by_value TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.entity_valid_time_history TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.entity_at_valid_time TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.find_related_entities TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.aggregate_attribute_history TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.detect_changes TO finos_app, finos_readonly;

-- =============================================================================
