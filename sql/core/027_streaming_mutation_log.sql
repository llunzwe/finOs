-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 27: STREAMING & MUTATION LOG
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: Native Real-Time Event Streaming, Kafka-Compatible, 4D Bitemporal Replay
-- Standards: Vault Streaming API, Marqeta Webhooks, Migration API
-- Version: 1.1 (March 2026)
-- =============================================================================

-- =============================================================================
-- STREAMING & MUTATION LOG (Primitive 22 in v1.1 Documentation)
-- =============================================================================
-- Native real-time event streaming + migration surface
-- Every ledger change is instantly streamed (Kafka-compatible)
-- Supports Vault Streaming API + Marqeta Webhooks + Migration API
-- Full 4D bitemporal replay possible

-- Mutation Types Enum
CREATE TYPE core.mutation_type AS ENUM (
    'POSTING',          -- Financial posting/mutation
    'STATUS',           -- Status change
    'BALANCE',          -- Balance update
    'CUSTOMER',         -- Customer/agent mutation
    'CONTRACT',         -- Contract deployment/update
    'CONFIG',           -- Configuration change
    'AUTH',             -- Authorization event
    'SETTLEMENT',       -- Settlement finality
    'RECONCILIATION',   -- Reconciliation event
    'RISK',             -- Risk event
    'COMPLIANCE',       -- Compliance event
    'MIGRATION'         -- Data migration event
);

COMMENT ON TYPE core.mutation_type IS 'Types of mutations that can be streamed';

-- =============================================================================
-- STREAMING MUTATION LOG (Primary Table)
-- =============================================================================

CREATE TABLE core.streaming_mutation_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Event Identification
    mutation_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY,
    mutation_type core.mutation_type NOT NULL,
    
    -- Source Reference
    source_table VARCHAR(100) NOT NULL, -- Origin table
    source_record_id UUID NOT NULL,     -- Primary key of source record
    source_operation VARCHAR(10) NOT NULL 
        CHECK (source_operation IN ('INSERT', 'UPDATE', 'DELETE')),
    
    -- Payload
    payload_jsonb JSONB NOT NULL,        -- Full event payload
    payload_hash VARCHAR(64) NOT NULL,   -- SHA-256 hash of payload for integrity
    
    -- Kafka-Compatible Headers
    kafka_topic VARCHAR(200),            -- Target Kafka topic
    kafka_partition INTEGER,             -- Partition assignment
    kafka_offset BIGINT,                 -- Offset in topic (if published)
    
    -- Subscriber Management
    streaming_subscriber_ids UUID[],     -- Which subscribers received this
    pending_subscribers UUID[],          -- Subscribers yet to acknowledge
    delivery_attempts INTEGER DEFAULT 0,
    
    -- Delivery Status
    delivery_status VARCHAR(20) DEFAULT 'pending' 
        CHECK (delivery_status IN ('pending', 'delivering', 'delivered', 'failed', 'retrying')),
    last_delivery_attempt_at TIMESTAMPTZ,
    delivery_error TEXT,
    
    -- Webhook Integration (Marqeta-style)
    webhook_url TEXT,                    -- Callback URL
    webhook_method VARCHAR(10) DEFAULT 'POST',
    webhook_headers JSONB DEFAULT '{}',
    webhook_response_code INTEGER,
    webhook_response_body TEXT,
    webhook_delivered_at TIMESTAMPTZ,
    
    -- 4D Bitemporal (Full Replay Support)
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Event Time (for ordering)
    event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Transaction Link
    transaction_id BIGINT REFERENCES core.transactions(tx_id),
    
    -- Correlation & Causation
    correlation_id UUID,
    causation_id UUID,
    
    -- Audit & Immutability
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    product_contract_hash UUID, -- Links to contract that generated this
    
    -- Soft Delete
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    -- Authorisation Decision JSONB (for AUTH mutations)
    authorisation_decision_jsonb JSONB DEFAULT '{}',
    
    -- Constraints
    CONSTRAINT unique_mutation_id_per_tenant UNIQUE (tenant_id, mutation_id),
    CONSTRAINT chk_mutation_valid_dates CHECK (valid_from < valid_to)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE core.streaming_mutation_log_default PARTITION OF core.streaming_mutation_log DEFAULT;

-- Convert to TimescaleDB hypertable for time-series optimization
SELECT create_hypertable('core.streaming_mutation_log', 'event_time', 
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists => TRUE);

-- Critical Indexes for high-throughput streaming
CREATE INDEX idx_mutation_log_tenant ON core.streaming_mutation_log(tenant_id, event_time DESC) 
    WHERE is_deleted = FALSE;
CREATE INDEX idx_mutation_log_type ON core.streaming_mutation_log(tenant_id, mutation_type, event_time DESC);
CREATE INDEX idx_mutation_log_status ON core.streaming_mutation_log(delivery_status) 
    WHERE delivery_status IN ('pending', 'retrying');
CREATE INDEX idx_mutation_log_source ON core.streaming_mutation_log(source_table, source_record_id);
CREATE INDEX idx_mutation_log_correlation ON core.streaming_mutation_log(correlation_id) 
    WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_mutation_log_transaction ON core.streaming_mutation_log(transaction_id) 
    WHERE transaction_id IS NOT NULL;
CREATE INDEX idx_mutation_log_temporal ON core.streaming_mutation_log(valid_from, valid_to) 
    WHERE valid_to > NOW();
CREATE INDEX idx_mutation_log_payload ON core.streaming_mutation_log USING GIN(payload_jsonb);
CREATE INDEX idx_mutation_log_subscribers ON core.streaming_mutation_log USING GIN(streaming_subscriber_ids);
CREATE INDEX idx_mutation_log_pending ON core.streaming_mutation_log USING GIN(pending_subscribers);

COMMENT ON TABLE core.streaming_mutation_log IS 
    'Native real-time event streaming with Kafka compatibility and 4D bitemporal replay';
COMMENT ON COLUMN core.streaming_mutation_log.payload_hash IS 
    'SHA-256 hash of payload for end-to-end integrity verification';
COMMENT ON COLUMN core.streaming_mutation_log.streaming_subscriber_ids IS 
    'Array of subscriber IDs that have successfully received this mutation';

-- =============================================================================
-- STREAMING SUBSCRIBERS REGISTRY
-- =============================================================================
-- Registered subscribers for event streaming

CREATE TABLE core.streaming_subscribers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Subscriber Identity
    subscriber_name VARCHAR(100) NOT NULL,
    subscriber_type VARCHAR(30) NOT NULL 
        CHECK (subscriber_type IN ('KAFKA', 'WEBHOOK', 'WEBSOCKET', 'SQS', 'PUBSUB', 'INTERNAL')),
    
    -- Subscription Configuration
    subscription_pattern JSONB NOT NULL DEFAULT '{}', -- {mutation_types: [], tables: [], filters: {}}
    
    -- Delivery Configuration
    delivery_mode VARCHAR(20) DEFAULT 'push' 
        CHECK (delivery_mode IN ('push', 'pull', 'hybrid')),
    max_delivery_attempts INTEGER DEFAULT 3,
    delivery_timeout_seconds INTEGER DEFAULT 30,
    retry_backoff_ms INTEGER DEFAULT 1000,
    
    -- Kafka-specific
    kafka_topic VARCHAR(200),
    kafka_bootstrap_servers TEXT[],
    kafka_client_id VARCHAR(100),
    kafka_compression VARCHAR(10) DEFAULT 'snappy',
    
    -- Webhook-specific
    webhook_url TEXT,
    webhook_secret TEXT, -- For HMAC signature
    webhook_headers JSONB DEFAULT '{}',
    
    -- Cursor Management (for replay)
    last_processed_mutation_id BIGINT DEFAULT 0,
    last_processed_at TIMESTAMPTZ,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' 
        CHECK (status IN ('active', 'paused', 'error', 'disabled')),
    error_count INTEGER DEFAULT 0,
    last_error_at TIMESTAMPTZ,
    last_error_message TEXT,
    
    -- Circuit Breaker
    circuit_breaker_enabled BOOLEAN DEFAULT TRUE,
    circuit_breaker_threshold INTEGER DEFAULT 5,
    circuit_breaker_reset_seconds INTEGER DEFAULT 60,
    circuit_breaker_opened_at TIMESTAMPTZ,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    
    CONSTRAINT unique_subscriber_name_per_tenant UNIQUE (tenant_id, subscriber_name)
) PARTITION BY LIST (tenant_id);

CREATE TABLE core.streaming_subscribers_default PARTITION OF core.streaming_subscribers DEFAULT;

CREATE INDEX idx_subscribers_tenant ON core.streaming_subscribers(tenant_id, status) WHERE status = 'active';
CREATE INDEX idx_subscribers_type ON core.streaming_subscribers(tenant_id, subscriber_type);

COMMENT ON TABLE core.streaming_subscribers IS 'Registered event streaming subscribers';

-- =============================================================================
-- STREAMING DEAD LETTER QUEUE
-- =============================================================================
-- Failed mutations for manual inspection and replay

CREATE TABLE core.streaming_dead_letter (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    original_mutation_id UUID NOT NULL REFERENCES core.streaming_mutation_log(id),
    
    -- Failure Details
    failure_reason TEXT NOT NULL,
    failure_category VARCHAR(50) 
        CHECK (failure_category IN ('TIMEOUT', 'HTTP_ERROR', 'SERIALIZATION', 'VALIDATION', 'SYSTEM')),
    
    -- Retry Information
    retry_count INTEGER DEFAULT 0,
    next_retry_at TIMESTAMPTZ,
    
    -- Resolution
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMPTZ,
    resolved_by VARCHAR(100),
    resolution_notes TEXT,
    
    -- Replay
    replayed BOOLEAN DEFAULT FALSE,
    replayed_mutation_id UUID, -- New mutation ID if replayed
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY LIST (tenant_id);

CREATE TABLE core.streaming_dead_letter_default PARTITION OF core.streaming_dead_letter DEFAULT;

CREATE INDEX idx_dead_letter_tenant ON core.streaming_dead_letter(tenant_id, resolved) WHERE resolved = FALSE;
CREATE INDEX idx_dead_letter_mutation ON core.streaming_dead_letter(original_mutation_id);

COMMENT ON TABLE core.streaming_dead_letter IS 'Failed streaming mutations for manual resolution';

-- =============================================================================
-- MIGRATION API SURFACE
-- =============================================================================
-- Tracks data migration operations with full audit

CREATE TABLE core.migration_operations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Migration Identity
    migration_id VARCHAR(100) NOT NULL,
    migration_name VARCHAR(200) NOT NULL,
    migration_type VARCHAR(50) NOT NULL 
        CHECK (migration_type IN ('IMPORT', 'EXPORT', 'TRANSFORM', 'VALIDATE', 'REPLAY')),
    
    -- Source/Target
    source_system VARCHAR(100),
    source_format VARCHAR(50), -- CSV, JSON, XML, PARQUET, etc.
    target_system VARCHAR(100),
    
    -- Configuration
    mapping_rules_jsonb JSONB DEFAULT '{}', -- Field mappings
    transformation_script TEXT, -- SQL or other transformation
    validation_rules_jsonb JSONB DEFAULT '[]',
    
    -- Progress
    status VARCHAR(20) DEFAULT 'pending' 
        CHECK (status IN ('pending', 'running', 'paused', 'completed', 'failed', 'partial')),
    total_records INTEGER,
    processed_records INTEGER DEFAULT 0,
    success_records INTEGER DEFAULT 0,
    error_records INTEGER DEFAULT 0,
    
    -- Timing
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    estimated_completion_at TIMESTAMPTZ,
    
    -- Performance
    records_per_second DECIMAL(10,2),
    avg_processing_time_ms DECIMAL(10,2),
    
    -- Error Details
    error_log JSONB DEFAULT '[]',
    last_error_at TIMESTAMPTZ,
    last_error_message TEXT,
    
    -- 4D Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    
    CONSTRAINT unique_migration_id_per_tenant UNIQUE (tenant_id, migration_id)
) PARTITION BY LIST (tenant_id);

CREATE TABLE core.migration_operations_default PARTITION OF core.migration_operations DEFAULT;

CREATE INDEX idx_migration_tenant ON core.streaming_mutation_log(tenant_id, status) 
    WHERE status IN ('pending', 'running', 'paused');

COMMENT ON TABLE core.migration_operations IS 'Data migration operations with full audit trail';

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Function: Publish mutation event (main entry point)
CREATE OR REPLACE FUNCTION core.publish_mutation(
    p_tenant_id UUID,
    p_mutation_type core.mutation_type,
    p_source_table VARCHAR(100),
    p_source_record_id UUID,
    p_source_operation VARCHAR(10),
    p_payload_jsonb JSONB,
    p_correlation_id UUID DEFAULT NULL,
    p_transaction_id BIGINT DEFAULT NULL,
    p_webhook_url TEXT DEFAULT NULL,
    p_kafka_topic VARCHAR(200) DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_mutation_id UUID;
    v_payload_hash VARCHAR(64);
    v_immutable_hash VARCHAR(64);
BEGIN
    -- Calculate payload hash
    v_payload_hash := encode(digest(p_payload_jsonb::text, 'sha256'), 'hex');
    
    -- Calculate immutable hash
    v_immutable_hash := encode(digest(
        p_tenant_id::text || p_mutation_type::text || p_source_table || 
        p_source_record_id::text || p_source_operation || v_payload_hash || NOW()::text,
        'sha256'
    ), 'hex');
    
    INSERT INTO core.streaming_mutation_log (
        tenant_id,
        mutation_type,
        source_table,
        source_record_id,
        source_operation,
        payload_jsonb,
        payload_hash,
        kafka_topic,
        webhook_url,
        transaction_id,
        correlation_id,
        delivery_status,
        immutable_hash
    ) VALUES (
        p_tenant_id,
        p_mutation_type,
        p_source_table,
        p_source_record_id,
        p_source_operation,
        p_payload_jsonb,
        v_payload_hash,
        p_kafka_topic,
        p_webhook_url,
        p_transaction_id,
        COALESCE(p_correlation_id, gen_random_uuid()),
        'pending',
        v_immutable_hash
    )
    RETURNING id INTO v_mutation_id;
    
    -- Trigger async delivery (in production, this would queue to background worker)
    PERFORM pg_notify('finos_mutation', jsonb_build_object(
        'mutation_id', v_mutation_id,
        'tenant_id', p_tenant_id,
        'type', p_mutation_type
    )::text);
    
    RETURN v_mutation_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.publish_mutation IS 
    'Publishes a mutation event to the streaming log for distribution';

-- Function: Register new streaming subscriber
CREATE OR REPLACE FUNCTION core.register_subscriber(
    p_tenant_id UUID,
    p_subscriber_name VARCHAR(100),
    p_subscriber_type VARCHAR(30),
    p_subscription_pattern JSONB,
    p_delivery_config JSONB DEFAULT '{}',
    p_created_by VARCHAR(100) DEFAULT 'system'
)
RETURNS UUID AS $$
DECLARE
    v_subscriber_id UUID;
    v_kafka_topic VARCHAR(200);
    v_webhook_url TEXT;
BEGIN
    -- Extract config
    v_kafka_topic := p_delivery_config->>'kafka_topic';
    v_webhook_url := p_delivery_config->>'webhook_url';
    
    INSERT INTO core.streaming_subscribers (
        tenant_id,
        subscriber_name,
        subscriber_type,
        subscription_pattern,
        kafka_topic,
        webhook_url,
        webhook_secret,
        webhook_headers,
        max_delivery_attempts,
        delivery_timeout_seconds,
        created_by
    ) VALUES (
        p_tenant_id,
        p_subscriber_name,
        p_subscriber_type,
        p_subscription_pattern,
        v_kafka_topic,
        v_webhook_url,
        encode(gen_random_bytes(32), 'base64'), -- Generate secret
        p_delivery_config->'webhook_headers',
        COALESCE((p_delivery_config->>'max_retries')::INTEGER, 3),
        COALESCE((p_delivery_config->>'timeout_seconds')::INTEGER, 30),
        p_created_by
    )
    RETURNING id INTO v_subscriber_id;
    
    RETURN v_subscriber_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.register_subscriber IS 
    'Registers a new subscriber for event streaming';

-- Function: Acknowledge mutation delivery
CREATE OR REPLACE FUNCTION core.ack_mutation_delivery(
    p_mutation_id UUID,
    p_subscriber_id UUID,
    p_delivery_success BOOLEAN,
    p_error_message TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_delivery_success THEN
        -- Mark subscriber as received
        UPDATE core.streaming_mutation_log
        SET 
            streaming_subscriber_ids = array_append_unique(streaming_subscriber_ids, p_subscriber_id),
            pending_subscribers = array_remove(pending_subscribers, p_subscriber_id),
            delivery_status = CASE 
                WHEN pending_subscribers = ARRAY[p_subscriber_id] OR pending_subscribers IS NULL 
                THEN 'delivered' 
                ELSE delivery_status 
            END
        WHERE id = p_mutation_id;
        
        RETURN TRUE;
    ELSE
        -- Record failed attempt
        UPDATE core.streaming_mutation_log
        SET 
            delivery_attempts = delivery_attempts + 1,
            last_delivery_attempt_at = NOW(),
            delivery_error = p_error_message,
            delivery_status = CASE 
                WHEN delivery_attempts >= 2 THEN 'failed' 
                ELSE 'retrying' 
            END
        WHERE id = p_mutation_id;
        
        -- Move to dead letter if max retries exceeded
        IF EXISTS (
            SELECT 1 FROM core.streaming_mutation_log 
            WHERE id = p_mutation_id AND delivery_attempts >= 2
        ) THEN
            INSERT INTO core.streaming_dead_letter (
                tenant_id, original_mutation_id, failure_reason, failure_category
            )
            SELECT tenant_id, p_mutation_id, p_error_message, 'HTTP_ERROR'
            FROM core.streaming_mutation_log
            WHERE id = p_mutation_id
            ON CONFLICT DO NOTHING;
        END IF;
        
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.ack_mutation_delivery IS 
    'Acknowledges successful or failed delivery of a mutation to a subscriber';

-- Function: Replay mutations (4D bitemporal replay)
CREATE OR REPLACE FUNCTION core.replay_mutations(
    p_tenant_id UUID,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ,
    p_mutation_types core.mutation_type[] DEFAULT NULL,
    p_subscriber_id UUID DEFAULT NULL,
    p_replay_to_kafka BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    mutation_id BIGINT,
    mutation_type core.mutation_type,
    event_time TIMESTAMPTZ,
    payload_jsonb JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sml.mutation_id,
        sml.mutation_type,
        sml.event_time,
        sml.payload_jsonb
    FROM core.streaming_mutation_log sml
    WHERE sml.tenant_id = p_tenant_id
      AND sml.event_time BETWEEN p_start_time AND p_end_time
      AND sml.is_deleted = FALSE
      AND (p_mutation_types IS NULL OR sml.mutation_type = ANY(p_mutation_types))
      AND (p_subscriber_id IS NULL OR NOT (p_subscriber_id = ANY(sml.streaming_subscriber_ids)))
    ORDER BY sml.event_time, sml.mutation_id;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.replay_mutations IS 
    'Replays mutations from a time range with optional filtering - 4D bitemporal replay';

-- Function: Create migration operation
CREATE OR REPLACE FUNCTION core.create_migration(
    p_tenant_id UUID,
    p_migration_id VARCHAR(100),
    p_migration_name VARCHAR(200),
    p_migration_type VARCHAR(50),
    p_source_system VARCHAR(100),
    p_mapping_rules JSONB DEFAULT '{}',
    p_created_by VARCHAR(100) DEFAULT 'system'
)
RETURNS UUID AS $$
DECLARE
    v_migration_uuid UUID;
BEGIN
    INSERT INTO core.migration_operations (
        tenant_id,
        migration_id,
        migration_name,
        migration_type,
        source_system,
        mapping_rules_jsonb,
        status,
        created_by
    ) VALUES (
        p_tenant_id,
        p_migration_id,
        p_migration_name,
        p_migration_type,
        p_source_system,
        p_mapping_rules,
        'pending',
        p_created_by
    )
    RETURNING id INTO v_migration_uuid;
    
    RETURN v_migration_uuid;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Auto-publish mutations on value_movements
CREATE OR REPLACE FUNCTION core.auto_publish_movement_mutation()
RETURNS TRIGGER AS $$
DECLARE
    v_payload JSONB;
    v_mutation_type core.mutation_type;
BEGIN
    -- Determine mutation type
    v_mutation_type := CASE NEW.type
        WHEN 'SETTLEMENT' THEN 'SETTLEMENT'::core.mutation_type
        ELSE 'POSTING'::core.mutation_type
    END;
    
    -- Build payload
    v_payload := jsonb_build_object(
        'movement_id', NEW.id,
        'type', NEW.type,
        'status', NEW.status,
        'amount', NEW.total_debits,
        'currency', NEW.entry_currency,
        'reference', NEW.reference,
        'timestamp', NEW.created_at
    );
    
    -- Publish mutation (async via notify)
    PERFORM core.publish_mutation(
        NEW.tenant_id,
        v_mutation_type,
        'value_movements',
        NEW.id,
        CASE WHEN TG_OP = 'INSERT' THEN 'INSERT' ELSE 'UPDATE' END,
        v_payload,
        NEW.correlation_id,
        NULL
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: Trigger is created but not enabled by default to avoid performance impact
-- Uncomment to enable:
-- CREATE TRIGGER trg_publish_movement_mutation
--     AFTER INSERT OR UPDATE ON core.value_movements
--     FOR EACH ROW EXECUTE FUNCTION core.auto_publish_movement_mutation();

-- Trigger: Calculate hash on insert
CREATE OR REPLACE FUNCTION core.calc_mutation_hash()
RETURNS TRIGGER AS $$
BEGIN
    NEW.immutable_hash := encode(digest(
        NEW.id::text || NEW.mutation_id::text || NEW.mutation_type::text || 
        NEW.source_table || NEW.source_record_id::text || NEW.payload_hash,
        'sha256'
    ), 'hex');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_mutation_hash
    BEFORE INSERT ON core.streaming_mutation_log
    FOR EACH ROW EXECUTE FUNCTION core.calc_mutation_hash();

-- =============================================================================
-- VIEWS
-- =============================================================================

-- View: Pending mutations for delivery
CREATE OR REPLACE VIEW core.v_pending_mutations AS
SELECT 
    sml.*,
    ss.subscriber_name,
    ss.subscriber_type,
    ss.webhook_url,
    ss.kafka_topic
FROM core.streaming_mutation_log sml
CROSS JOIN LATERAL (
    SELECT * FROM core.streaming_subscribers ss
    WHERE ss.tenant_id = sml.tenant_id
      AND ss.status = 'active'
      AND (
          sml.pending_subscribers IS NULL 
          OR ss.id = ANY(sml.pending_subscribers)
      )
      AND (
          ss.subscription_pattern->'mutation_types' IS NULL
          OR sml.mutation_type::text = ANY(ARRAY(SELECT jsonb_array_elements_text(ss.subscription_pattern->'mutation_types')))
      )
) ss
WHERE sml.delivery_status IN ('pending', 'retrying')
  AND sml.is_deleted = FALSE;

COMMENT ON VIEW core.v_pending_mutations IS 
    'View of mutations pending delivery with subscriber details';

-- View: Streaming statistics
CREATE OR REPLACE VIEW core.v_streaming_statistics AS
SELECT 
    tenant_id,
    DATE_TRUNC('hour', event_time) AS hour,
    mutation_type,
    delivery_status,
    COUNT(*) AS mutation_count,
    AVG(EXTRACT(EPOCH FROM (last_delivery_attempt_at - created_at))) * 1000 AS avg_delivery_time_ms
FROM core.streaming_mutation_log
WHERE event_time > NOW() - INTERVAL '24 hours'
  AND is_deleted = FALSE
GROUP BY tenant_id, DATE_TRUNC('hour', event_time), mutation_type, delivery_status;

COMMENT ON VIEW core.v_streaming_statistics IS 
    'Hourly streaming statistics for monitoring';

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.streaming_mutation_log TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.streaming_subscribers TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.streaming_dead_letter TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.migration_operations TO finos_app;

GRANT SELECT ON core.v_pending_mutations TO finos_app;
GRANT SELECT ON core.v_streaming_statistics TO finos_app, finos_readonly;

GRANT EXECUTE ON FUNCTION core.publish_mutation TO finos_app;
GRANT EXECUTE ON FUNCTION core.register_subscriber TO finos_app;
GRANT EXECUTE ON FUNCTION core.ack_mutation_delivery TO finos_app;
GRANT EXECUTE ON FUNCTION core.replay_mutations TO finos_app;
GRANT EXECUTE ON FUNCTION core.create_migration TO finos_app;
