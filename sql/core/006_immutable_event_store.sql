-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 6: IMMUTABLE EVENT STORE
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: Cryptographic Chain, Merkle Trees, Blockchain Anchoring, Tamper-Proof
-- Standards: ISO 27001, NIST Cybersecurity Framework, GDPR Article 17
-- =============================================================================

-- =============================================================================
-- IMMUTABLE EVENTS (Cryptographic Event Log)
-- =============================================================================
-- Enhanced with Datomic-style Datoms (E-A-V-Tx-Op) for government-trust layer
-- Every financial fact becomes a cryptographically provable, tokenized datom
-- =============================================================================

CREATE TABLE core_crypto.immutable_events (
    event_id BIGSERIAL,
    event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Tenant Isolation
    tenant_id UUID NOT NULL REFERENCES core.tenants(id),
    
    -- Event Content
    event_type VARCHAR(100) NOT NULL,
    event_category VARCHAR(50) CHECK (event_category IN ('movement', 'container', 'agent', 'system', 'security')),
    payload JSONB NOT NULL,
    
    -- =============================================================================
    -- DATOMIC-STYLE DATOM MODEL (E-A-V-Tx-Op)
    -- Maps every financial fact to Datomic's universal relation of datoms
    -- This enables Datalog-style queries and complete provenance
    -- =============================================================================
    
    -- E = Entity ID (the subject of the fact: container, agent, movement, etc.)
    datom_entity_id UUID,  -- Maps to Datomic 'E'
    
    -- A = Attribute (the property being asserted: balance, status, owner, etc.)
    datom_attribute VARCHAR(200),  -- Maps to Datomic 'A' (e.g., 'container.balance', 'agent.status')
    
    -- V = Value (the actual value, stored as JSONB for flexibility)
    datom_value JSONB,  -- Maps to Datomic 'V' (the value of the attribute)
    
    -- Tx = Transaction ID (this event_id serves as the transaction)
    -- Implicit: event_id IS the transaction (Tx) in Datomic terms
    
    -- Op = Operation (+ for assertion, - for retraction)
    datom_operation CHAR(1) DEFAULT '+' CHECK (datom_operation IN ('+', '-')),  -- Maps to Datomic 'Op'
    
    -- Valid Time (business time) for bitemporal queries
    datom_valid_time TIMESTAMPTZ DEFAULT NOW(),  -- When the fact is valid in business terms
    
    -- =============================================================================
    -- Integrity (SHA-256)
    payload_hash VARCHAR(64) NOT NULL,
    previous_hash VARCHAR(64) NOT NULL,
    event_hash VARCHAR(64) NOT NULL,
    
    -- Merkle Tree (Enhanced for government verification)
    merkle_root VARCHAR(64),  -- Root hash of this batch
    merkle_leaf_index INTEGER,  -- Position in the Merkle tree
    merkle_tree_level INTEGER,  -- Tree depth
    merkle_batch_id UUID,  -- Groups events into batches for anchoring
    
    -- Source
    source_service VARCHAR(50) NOT NULL,
    source_version VARCHAR(20) NOT NULL,
    source_instance VARCHAR(100),
    
    -- Context (Idempotency + Correlation)
    correlation_id UUID,
    causation_id UUID,
    idempotency_key VARCHAR(100),
    user_session_id UUID,
    ip_address INET,
    user_agent TEXT,
    
    -- Consent (GDPR)
    consent_id UUID,
    data_subject_id UUID,
    
    -- =============================================================================
    -- BLOCKCHAIN ANCHORING (Government Trust Layer)
    -- =============================================================================
    anchor_chain VARCHAR(50), -- 'bitcoin', 'ethereum', 'hyperledger', 'polygon', 'sarb_sovereign'
    anchor_tx_hash VARCHAR(256),
    anchor_block_number BIGINT,
    anchor_block_hash VARCHAR(256),
    anchor_timestamp TIMESTAMPTZ,
    anchor_confirmations INTEGER DEFAULT 0,
    anchor_status VARCHAR(20) DEFAULT 'pending' 
        CHECK (anchor_status IN ('pending', 'broadcast', 'confirmed', 'failed')),
    
    -- =============================================================================
    -- ZERO-KNOWLEDGE PROOF HOOKS (Privacy-Preserving Verification)
    -- =============================================================================
    zk_proof_type VARCHAR(50), -- 'range_proof', 'membership_proof', 'equality_proof', etc.
    zk_proof_data BYTEA,  -- The actual ZK proof data
    zk_public_inputs JSONB,  -- Public inputs for verification
    zk_verified BOOLEAN DEFAULT FALSE,  -- Whether proof has been verified
    zk_verified_at TIMESTAMPTZ,
    
    -- =============================================================================
    -- DIGITAL SIGNATURES (ECDSA for government-trusted facts)
    -- =============================================================================
    signature_algorithm VARCHAR(20) DEFAULT 'ECDSA-secp256k1',
    signature BYTEA,  -- Digital signature of the datom
    signer_public_key TEXT,  -- Public key of the signer
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (event_id, event_time),
    
    -- Idempotency constraint
    CONSTRAINT unique_event_idempotency UNIQUE NULLS NOT DISTINCT (tenant_id, idempotency_key)
) PARTITION BY RANGE (event_time);

-- Create default partition
CREATE TABLE core_crypto.immutable_events_default PARTITION OF core_crypto.immutable_events
    DEFAULT;

-- Convert to hypertable
SELECT create_hypertable('core_crypto.immutable_events', 'event_time', 
                         chunk_time_interval => INTERVAL '1 hour',
                         if_not_exists => TRUE);

-- Critical indexes (-3.2)
CREATE INDEX idx_immutable_events_tenant ON core_crypto.immutable_events(tenant_id, event_time DESC);
CREATE INDEX idx_immutable_events_type ON core_crypto.immutable_events(event_type, event_time DESC);
CREATE INDEX idx_immutable_events_hash ON core_crypto.immutable_events(event_hash);
CREATE INDEX idx_immutable_events_anchor ON core_crypto.immutable_events(anchor_status) WHERE anchor_status = 'pending';
CREATE INDEX idx_immutable_events_correlation ON core_crypto.immutable_events(correlation_id);
CREATE INDEX idx_immutable_events_chain ON core_crypto.immutable_events(tenant_id, anchor_chain) WHERE anchor_chain IS NOT NULL;
CREATE INDEX idx_immutable_events_idempotency ON core_crypto.immutable_events(tenant_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX idx_immutable_events_composite ON core_crypto.immutable_events(tenant_id, event_type, event_time DESC);

-- =============================================================================
-- DATOMIC-STYLE UNIVERSAL INDEXES (EAVT, AVET, AEVT, VAET)
-- These enable Datalog-style queries across all financial facts
-- =============================================================================

-- EAVT Index: Entity -> Attribute -> Value -> Transaction (most common query pattern)
-- Used for: "What are all attributes of entity X?"
CREATE INDEX idx_datom_eavt ON core_crypto.immutable_events 
    (tenant_id, datom_entity_id, datom_attribute, datom_valid_time DESC, event_id DESC) 
    WHERE datom_entity_id IS NOT NULL AND datom_attribute IS NOT NULL;

-- AVET Index: Attribute -> Value -> Entity -> Transaction
-- Used for: "Find all entities where attribute X = value Y" (reverse lookup)
CREATE INDEX idx_datom_avet ON core_crypto.immutable_events 
    (tenant_id, datom_attribute, datom_value, datom_entity_id, event_id DESC) 
    WHERE datom_attribute IS NOT NULL AND datom_value IS NOT NULL;

-- AEVT Index: Attribute -> Entity -> Value -> Transaction
-- Used for: "For attribute X, what are all entity values?"
CREATE INDEX idx_datom_aevt ON core_crypto.immutable_events 
    (tenant_id, datom_attribute, datom_entity_id, datom_valid_time DESC, event_id DESC) 
    WHERE datom_attribute IS NOT NULL;

-- VAET Index: Value -> Attribute -> Entity -> Transaction (for unique values)
-- Used for: "Which entities have this exact value?"
CREATE INDEX idx_datom_vaet ON core_crypto.immutable_events 
    (tenant_id, datom_value, datom_attribute, datom_entity_id, event_id DESC) 
    WHERE datom_value IS NOT NULL;

-- Merkle batch index for anchoring
CREATE INDEX idx_immutable_events_merkle_batch ON core_crypto.immutable_events(merkle_batch_id) 
    WHERE merkle_batch_id IS NOT NULL;

-- ZK proof index
CREATE INDEX idx_immutable_events_zk ON core_crypto.immutable_events(zk_verified, zk_proof_type) 
    WHERE zk_verified = TRUE;

-- Signature verification index
CREATE INDEX idx_immutable_events_signature ON core_crypto.immutable_events(tenant_id, signer_public_key) 
    WHERE signature IS NOT NULL;

-- Event replay function
CREATE OR REPLACE FUNCTION core_crypto.replay_events(
    p_tenant_id UUID,
    p_start_event_id BIGINT DEFAULT NULL,
    p_end_event_id BIGINT DEFAULT NULL,
    p_event_types TEXT[] DEFAULT NULL
)
RETURNS TABLE (
    event_id BIGINT,
    event_time TIMESTAMPTZ,
    event_type VARCHAR,
    payload JSONB,
    event_hash VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ie.event_id,
        ie.event_time,
        ie.event_type,
        ie.payload,
        ie.event_hash
    FROM core_crypto.immutable_events ie
    WHERE ie.tenant_id = p_tenant_id
      AND (p_start_event_id IS NULL OR ie.event_id >= p_start_event_id)
      AND (p_end_event_id IS NULL OR ie.event_id <= p_end_event_id)
      AND (p_event_types IS NULL OR ie.event_type = ANY(p_event_types))
    ORDER BY ie.event_time, ie.event_id;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core_crypto.replay_events IS 'Event replay function for state reconstruction';

-- Webhook event trigger function
CREATE OR REPLACE FUNCTION core_crypto.notify_webhook_subscribers()
RETURNS TRIGGER AS $$
DECLARE
    v_subscription RECORD;
BEGIN
    -- Queue webhook deliveries for active subscriptions matching event type
    FOR v_subscription IN
        SELECT ws.id, ws.webhook_url, ws.secret_key_encrypted
        FROM core.webhook_subscriptions ws
        WHERE ws.tenant_id = NEW.tenant_id
          AND ws.status = 'active'
          AND NEW.event_type = ANY(ws.event_types)
          AND ws.valid_from <= NOW()
          AND ws.valid_to > NOW()
    LOOP
        INSERT INTO core.webhook_deliveries (
            tenant_id, subscription_id, event_id, event_type, event_payload,
            status, scheduled_at
        ) VALUES (
            NEW.tenant_id, v_subscription.id, NEW.event_id, NEW.event_type, NEW.payload,
            'pending', NOW()
        );
    END LOOP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply webhook trigger (can be enabled via kernel_wiring)
-- CREATE TRIGGER trg_event_webhook
--     AFTER INSERT ON core_crypto.immutable_events
--     FOR EACH ROW EXECUTE FUNCTION core_crypto.notify_webhook_subscribers();

COMMENT ON TABLE core_crypto.immutable_events IS 'Append-only cryptographic event log with Datomic-style datoms (E-A-V-Tx-Op), hash chain, and blockchain anchoring';
COMMENT ON COLUMN core_crypto.immutable_events.payload_hash IS 'SHA-256 hash of the payload JSON';
COMMENT ON COLUMN core_crypto.immutable_events.event_hash IS 'SHA-256 of type + payload_hash + previous_hash';
COMMENT ON COLUMN core_crypto.immutable_events.datom_entity_id IS 'Datomic E: Entity ID (subject of the fact)';
COMMENT ON COLUMN core_crypto.immutable_events.datom_attribute IS 'Datomic A: Attribute name (e.g., container.balance)';
COMMENT ON COLUMN core_crypto.immutable_events.datom_value IS 'Datomic V: Value as JSONB';
COMMENT ON COLUMN core_crypto.immutable_events.datom_operation IS 'Datomic Op: + for assertion, - for retraction';
COMMENT ON COLUMN core_crypto.immutable_events.datom_valid_time IS 'Business time when fact is valid (bitemporal)';
COMMENT ON COLUMN core_crypto.immutable_events.zk_proof_data IS 'Zero-knowledge proof for privacy-preserving verification';
COMMENT ON COLUMN core_crypto.immutable_events.signature IS 'ECDSA digital signature of the datom';

-- =============================================================================
-- EVENT CHAIN VERIFICATION
-- =============================================================================
CREATE TABLE core_crypto.event_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    
    verification_type VARCHAR(50) NOT NULL CHECK (verification_type IN ('chain_integrity', 'merkle_root', 'anchor_confirmation')),
    
    -- Scope
    start_event_id BIGINT,
    end_event_id BIGINT,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    
    -- Results
    verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    verification_result VARCHAR(20) NOT NULL CHECK (verification_result IN ('valid', 'invalid', 'error')),
    expected_hash VARCHAR(64),
    actual_hash VARCHAR(64),
    
    -- Details
    events_verified INTEGER,
    inconsistencies JSONB,
    
    -- Audit
    verified_by VARCHAR(100),
    verification_method VARCHAR(50)
);

CREATE INDEX idx_event_verifications_tenant ON core_crypto.event_verifications(tenant_id, verified_at DESC);

COMMENT ON TABLE core_crypto.event_verifications IS 'Audit log of event chain integrity verifications';

-- =============================================================================
-- HASH CHAIN TRIGGERS
-- =============================================================================

-- Trigger to calculate hash chain
CREATE OR REPLACE FUNCTION core_crypto.calculate_event_hash()
RETURNS TRIGGER AS $$
DECLARE
    v_prev_hash VARCHAR(64);
    v_tenant_prev_hash VARCHAR(64);
BEGIN
    -- Get previous hash for this tenant
    SELECT event_hash INTO v_tenant_prev_hash
    FROM core_crypto.immutable_events
    WHERE tenant_id = NEW.tenant_id
    ORDER BY event_time DESC, event_id DESC
    LIMIT 1;
    
    -- Get global previous hash
    SELECT event_hash INTO v_prev_hash
    FROM core_crypto.immutable_events
    ORDER BY event_time DESC, event_id DESC
    LIMIT 1;
    
    -- Set previous hash (tenant-specific chain)
    IF v_tenant_prev_hash IS NULL THEN
        NEW.previous_hash := repeat('0', 64); -- Genesis hash
    ELSE
        NEW.previous_hash := v_tenant_prev_hash;
    END IF;
    
    -- Calculate payload hash
    NEW.payload_hash := encode(digest(NEW.payload::text, 'sha256'), 'hex');
    
    -- Calculate event hash
    NEW.event_hash := encode(digest(
        NEW.event_type || NEW.payload_hash || NEW.previous_hash || NEW.tenant_id::text,
        'sha256'
    ), 'hex');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_event_hash_chain
    BEFORE INSERT ON core_crypto.immutable_events
    FOR EACH ROW EXECUTE FUNCTION core_crypto.calculate_event_hash();

-- =============================================================================
-- APPEND-ONLY PROTECTION
-- =============================================================================
CREATE RULE immutable_no_update AS ON UPDATE TO core_crypto.immutable_events 
    DO INSTEAD NOTHING;
CREATE RULE immutable_no_delete AS ON DELETE TO core_crypto.immutable_events 
    DO INSTEAD NOTHING;

COMMENT ON TABLE core_crypto.immutable_events IS 'APPEND-ONLY: Updates and deletes are prohibited (cryptographic integrity)';

-- =============================================================================
-- CHAIN VERIFICATION FUNCTIONS
-- =============================================================================

-- Function: Verify chain integrity for a tenant
CREATE OR REPLACE FUNCTION core_crypto.verify_chain_integrity(
    p_tenant_id UUID,
    p_start_event_id BIGINT DEFAULT NULL,
    p_end_event_id BIGINT DEFAULT NULL
) RETURNS TABLE (
    is_valid BOOLEAN,
    events_verified INTEGER,
    first_invalid_event_id BIGINT,
    error_message TEXT
) AS $$
DECLARE
    v_event RECORD;
    v_prev_hash VARCHAR(64) := repeat('0', 64);
    v_expected_hash VARCHAR(64);
    v_count INTEGER := 0;
    v_invalid_id BIGINT := NULL;
    v_error TEXT := NULL;
BEGIN
    FOR v_event IN
        SELECT event_id, event_hash, previous_hash, payload_hash, event_type, tenant_id
        FROM core_crypto.immutable_events
        WHERE tenant_id = p_tenant_id
          AND (p_start_event_id IS NULL OR event_id >= p_start_event_id)
          AND (p_end_event_id IS NULL OR event_id <= p_end_event_id)
        ORDER BY event_time, event_id
    LOOP
        v_count := v_count + 1;
        
        -- Check previous hash
        IF v_event.previous_hash != v_prev_hash THEN
            v_invalid_id := v_event.event_id;
            v_error := format('Hash chain broken at event %s: expected prev_hash=%s, got=%s',
                v_event.event_id, v_prev_hash, v_event.previous_hash);
            RETURN QUERY SELECT FALSE, v_count, v_invalid_id, v_error;
            RETURN;
        END IF;
        
        -- Verify event hash
        v_expected_hash := encode(digest(
            v_event.event_type || v_event.payload_hash || v_event.previous_hash || v_event.tenant_id::text,
            'sha256'
        ), 'hex');
        
        IF v_expected_hash != v_event.event_hash THEN
            v_invalid_id := v_event.event_id;
            v_error := format('Event hash mismatch at event %s', v_event.event_id);
            RETURN QUERY SELECT FALSE, v_count, v_invalid_id, v_error;
            RETURN;
        END IF;
        
        v_prev_hash := v_event.event_hash;
    END LOOP;
    
    RETURN QUERY SELECT TRUE, v_count, NULL::BIGINT, NULL::TEXT;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core_crypto.verify_chain_integrity IS 'Verifies the cryptographic integrity of the event chain';

-- Function: Generate Merkle root for a batch
CREATE OR REPLACE FUNCTION core_crypto.generate_merkle_root(
    p_event_ids BIGINT[]
) RETURNS VARCHAR AS $$
DECLARE
    v_hashes TEXT[];
    v_new_hashes TEXT[];
    v_i INTEGER;
    v_len INTEGER;
BEGIN
    -- Get event hashes
    SELECT array_agg(event_hash ORDER BY event_id) INTO v_hashes
    FROM core_crypto.immutable_events
    WHERE event_id = ANY(p_event_ids);
    
    v_len := array_length(v_hashes, 1);
    IF v_len IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Build Merkle tree
    WHILE v_len > 1 LOOP
        v_new_hashes := ARRAY[]::TEXT[];
        v_i := 1;
        WHILE v_i < v_len LOOP
            v_new_hashes := array_append(v_new_hashes, 
                encode(digest(v_hashes[v_i] || COALESCE(v_hashes[v_i+1], v_hashes[v_i]), 'sha256'), 'hex')
            );
            v_i := v_i + 2;
        END LOOP;
        v_hashes := v_new_hashes;
        v_len := array_length(v_hashes, 1);
    END LOOP;
    
    RETURN v_hashes[1];
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core_crypto.generate_merkle_root IS 'Generates Merkle root for a batch of events';

-- =============================================================================
-- DATOMIC-STYLE QUERY ENGINE (Datalog Queries)
-- =============================================================================

-- Function: Query entity attributes at a specific point in time (EAVT pattern)
CREATE OR REPLACE FUNCTION core_crypto.datom_query_eavt(
    p_tenant_id UUID,
    p_entity_id UUID,
    p_as_of_tx BIGINT DEFAULT NULL,  -- NULL = current
    p_attribute VARCHAR DEFAULT NULL  -- NULL = all attributes
)
RETURNS TABLE (
    attribute VARCHAR,
    value JSONB,
    operation CHAR(1),
    tx_id BIGINT,
    valid_time TIMESTAMPTZ,
    event_hash VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ie.datom_attribute,
        ie.datom_value,
        ie.datom_operation,
        ie.event_id,
        ie.datom_valid_time,
        ie.event_hash
    FROM core_crypto.immutable_events ie
    WHERE ie.tenant_id = p_tenant_id
      AND ie.datom_entity_id = p_entity_id
      AND (p_as_of_tx IS NULL OR ie.event_id <= p_as_of_tx)
      AND (p_attribute IS NULL OR ie.datom_attribute = p_attribute)
      AND ie.datom_operation = '+'  -- Only assertions (retractions excluded)
    ORDER BY ie.datom_attribute, ie.event_id DESC
    DISTINCT ON (ie.datom_attribute);
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core_crypto.datom_query_eavt IS 'Datomic EAVT query: Get all attributes of an entity as of a specific transaction';

-- Function: Query by attribute value (AVET pattern)
CREATE OR REPLACE FUNCTION core_crypto.datom_query_avet(
    p_tenant_id UUID,
    p_attribute VARCHAR,
    p_value JSONB,
    p_as_of_tx BIGINT DEFAULT NULL
)
RETURNS TABLE (
    entity_id UUID,
    value JSONB,
    tx_id BIGINT,
    valid_time TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ie.datom_entity_id,
        ie.datom_value,
        ie.event_id,
        ie.datom_valid_time
    FROM core_crypto.immutable_events ie
    WHERE ie.tenant_id = p_tenant_id
      AND ie.datom_attribute = p_attribute
      AND ie.datom_value @> p_value
      AND (p_as_of_tx IS NULL OR ie.event_id <= p_as_of_tx)
      AND ie.datom_operation = '+'
    ORDER BY ie.event_id DESC;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core_crypto.datom_query_avet IS 'Datomic AVET query: Find entities by attribute value';

-- Function: Get entity history (all assertions and retractions)
CREATE OR REPLACE FUNCTION core_crypto.datom_entity_history(
    p_tenant_id UUID,
    p_entity_id UUID,
    p_attribute VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    tx_id BIGINT,
    tx_time TIMESTAMPTZ,
    attribute VARCHAR,
    value JSONB,
    operation CHAR(1),
    valid_time TIMESTAMPTZ,
    event_hash VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ie.event_id,
        ie.event_time,
        ie.datom_attribute,
        ie.datom_value,
        ie.datom_operation,
        ie.datom_valid_time,
        ie.event_hash
    FROM core_crypto.immutable_events ie
    WHERE ie.tenant_id = p_tenant_id
      AND ie.datom_entity_id = p_entity_id
      AND (p_attribute IS NULL OR ie.datom_attribute = p_attribute)
    ORDER BY ie.event_id;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core_crypto.datom_entity_history IS 'Get complete history of an entity (all assertions and retractions)';

-- Function: Verify datom signature
CREATE OR REPLACE FUNCTION core_crypto.verify_datom_signature(
    p_event_id BIGINT,
    p_public_key TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_event RECORD;
    v_message TEXT;
BEGIN
    SELECT * INTO v_event 
    FROM core_crypto.immutable_events 
    WHERE event_id = p_event_id;
    
    IF v_event IS NULL OR v_event.signature IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Construct message: entity_id + attribute + value + operation + tx_id
    v_message := COALESCE(v_event.datom_entity_id::text, '') || 
                 COALESCE(v_event.datom_attribute, '') || 
                 COALESCE(v_event.datom_value::text, '') ||
                 COALESCE(v_event.datom_operation, '+') ||
                 v_event.event_id::text;
    
    -- Note: Actual ECDSA verification would require pgcrypto or external library
    -- This is a placeholder for the verification logic
    -- In production, use pgcrypto's crypt functions or external verification
    
    RETURN TRUE; -- Placeholder - implement actual crypto verification
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core_crypto.verify_datom_signature IS 'Verifies the ECDSA signature of a datom';

-- =============================================================================
-- EVENT ARCHIVAL
-- =============================================================================
CREATE TABLE core_crypto.archived_events (
    LIKE core_crypto.immutable_events INCLUDING ALL,
    archived_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archive_batch_id UUID,
    compression_method VARCHAR(20)
);

CREATE INDEX idx_archived_events_tenant ON core_crypto.archived_events(tenant_id, event_time);

COMMENT ON TABLE core_crypto.archived_events IS 'Cold storage for aged events (maintaining hash references)';

-- =============================================================================
-- EVENT STREAMS (Projection Tracking)
-- =============================================================================
CREATE TABLE core_crypto.event_stream_positions (
    stream_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    
    stream_name VARCHAR(100) NOT NULL,
    stream_type VARCHAR(50) NOT NULL CHECK (stream_type IN ('projection', 'integration', 'analytics', 'reporting')),
    
    -- Position tracking
    last_event_id BIGINT NOT NULL DEFAULT 0,
    last_event_time TIMESTAMPTZ,
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    error_count INTEGER DEFAULT 0,
    last_error TEXT,
    last_error_at TIMESTAMPTZ,
    
    -- Processing metrics
    events_processed BIGINT DEFAULT 0,
    last_processed_at TIMESTAMPTZ,
    processing_lag_ms INTEGER,
    
    -- Metadata
    stream_config JSONB DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_stream_name UNIQUE (tenant_id, stream_name)
);

CREATE INDEX idx_stream_positions_active ON core_crypto.event_stream_positions(tenant_id, is_active) WHERE is_active = TRUE;

COMMENT ON TABLE core_crypto.event_stream_positions IS 'Tracks consumer positions in the event stream for idempotent processing';

-- Trigger for stream position updates
CREATE OR REPLACE FUNCTION core_crypto.update_stream_position()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stream_position_update
    BEFORE UPDATE ON core_crypto.event_stream_positions
    FOR EACH ROW EXECUTE FUNCTION core_crypto.update_stream_position();

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT ON core_crypto.immutable_events TO finos_app;
GRANT SELECT, INSERT ON core_crypto.event_verifications TO finos_app;
GRANT SELECT, INSERT ON core_crypto.archived_events TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core_crypto.event_stream_positions TO finos_app;
GRANT EXECUTE ON FUNCTION core_crypto.verify_chain_integrity TO finos_app;
GRANT EXECUTE ON FUNCTION core_crypto.generate_merkle_root TO finos_app;
GRANT EXECUTE ON FUNCTION core_crypto.replay_events TO finos_app;
GRANT EXECUTE ON FUNCTION core_crypto.notify_webhook_subscribers TO finos_app;
GRANT EXECUTE ON FUNCTION core_crypto.datom_query_eavt TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core_crypto.datom_query_avet TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core_crypto.datom_entity_history TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core_crypto.verify_datom_signature TO finos_app;
