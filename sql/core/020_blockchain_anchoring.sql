-- =============================================================================
-- FINOS CORE KERNEL - BLOCKCHAIN ANCHORING & MERKLE TREE SERVICE
-- =============================================================================
-- File: core/020_blockchain_anchoring.sql
-- Description: Government-trust layer via Merkle roots anchored to blockchain
--              Enables sovereign verification without trusting FinOS operators
-- Standards: ISO 27001, NIST Cybersecurity Framework, Government Auditing
-- =============================================================================

-- =============================================================================
-- MERKLE BATCHES (Groups of events hashed together for anchoring)
-- =============================================================================
CREATE TABLE core.merkle_batches (
    batch_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Batch Scope
    batch_number BIGINT NOT NULL,  -- Sequential batch number per tenant
    start_event_id BIGINT NOT NULL,
    end_event_id BIGINT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    event_count INTEGER NOT NULL,
    
    -- Merkle Tree Data
    merkle_root VARCHAR(64) NOT NULL,  -- The root hash
    merkle_tree JSONB,  -- Complete tree structure for verification
    leaf_hashes TEXT[],  -- Array of all leaf hashes
    
    -- Previous Batch Link (forms chain of batches)
    previous_batch_id UUID REFERENCES core.merkle_batches(batch_id),
    previous_batch_hash VARCHAR(64),  -- Hash of previous batch for chain
    
    -- Status
    status VARCHAR(20) DEFAULT 'open' 
        CHECK (status IN ('open', 'sealed', 'anchored', 'confirmed', 'failed')),
    sealed_at TIMESTAMPTZ,
    sealed_by VARCHAR(100),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_batch_number UNIQUE (tenant_id, batch_number)
);

-- Indexes for Merkle batches
CREATE INDEX idx_merkle_batches_tenant ON core.merkle_batches(tenant_id, batch_number DESC);
CREATE INDEX idx_merkle_batches_status ON core.merkle_batches(status) WHERE status IN ('sealed', 'anchored');
CREATE INDEX idx_merkle_batches_root ON core.merkle_batches(merkle_root);

COMMENT ON TABLE core.merkle_batches IS 'Batches of events grouped for Merkle tree generation and blockchain anchoring';
COMMENT ON COLUMN core.merkle_batches.merkle_root IS 'Root hash of the Merkle tree - anchored to blockchain for government verification';

-- =============================================================================
-- BLOCKCHAIN ANCHORS (On-chain commitments for government trust)
-- =============================================================================
CREATE TABLE core.blockchain_anchors (
    anchor_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Link to Merkle Batch
    batch_id UUID NOT NULL REFERENCES core.merkle_batches(batch_id),
    merkle_root VARCHAR(64) NOT NULL,
    
    -- Blockchain Target
    chain_type VARCHAR(50) NOT NULL 
        CHECK (chain_type IN ('ethereum', 'polygon', 'hyperledger', 'bitcoin', 'sarb_sovereign', 'zim_sovereign', 'permissioned')),
    chain_id VARCHAR(50),  -- Network ID (e.g., '1' for Ethereum mainnet, '137' for Polygon)
    chain_name VARCHAR(100),  -- Human-readable name
    
    -- On-Chain Transaction Details
    contract_address VARCHAR(256),  -- Smart contract address
    tx_hash VARCHAR(256) NOT NULL,
    tx_block_number BIGINT,
    tx_block_hash VARCHAR(256),
    tx_timestamp TIMESTAMPTZ,
    tx_gas_used BIGINT,
    tx_gas_price BIGINT,
    tx_cost_wei NUMERIC,
    
    -- Anchor Data
    anchor_nonce BIGINT,  -- Nonce used in the anchor transaction
    anchor_data BYTEA,  -- Raw data anchored
    
    -- Confirmations
    confirmation_count INTEGER DEFAULT 0,
    required_confirmations INTEGER DEFAULT 12,  -- Ethereum standard
    confirmed_at TIMESTAMPTZ,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending' 
        CHECK (status IN ('pending', 'broadcast', 'mined', 'confirmed', 'finalized', 'failed')),
    
    -- Verification
    verified_at TIMESTAMPTZ,
    verified_by VARCHAR(100),
    verification_method VARCHAR(50),  -- 'rpc', 'oracle', 'light_client'
    
    -- Error Handling
    retry_count INTEGER DEFAULT 0,
    last_error TEXT,
    last_error_at TIMESTAMPTZ,
    
    -- Metadata
    anchor_metadata JSONB DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Critical indexes for blockchain anchors
CREATE INDEX idx_blockchain_anchors_tenant ON core.blockchain_anchors(tenant_id, created_at DESC);
CREATE INDEX idx_blockchain_anchors_batch ON core.blockchain_anchors(batch_id);
CREATE INDEX idx_blockchain_anchors_root ON core.blockchain_anchors(merkle_root);
CREATE INDEX idx_blockchain_anchors_tx ON core.blockchain_anchors(tx_hash);
CREATE INDEX idx_blockchain_anchors_status ON core.blockchain_anchors(status) WHERE status IN ('pending', 'broadcast');
CREATE INDEX idx_blockchain_anchors_chain ON core.blockchain_anchors(chain_type, chain_id);

COMMENT ON TABLE core.blockchain_anchors IS 'Blockchain anchoring of Merkle roots for government-trusted verification';
COMMENT ON COLUMN core.blockchain_anchors.merkle_root IS 'Merkle root anchored on-chain - regulators can verify independently';
COMMENT ON COLUMN core.blockchain_anchors.tx_hash IS 'Blockchain transaction hash for public verification';

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION core.update_anchor_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_blockchain_anchors_update
    BEFORE UPDATE ON core.blockchain_anchors
    FOR EACH ROW EXECUTE FUNCTION core.update_anchor_timestamp();

-- =============================================================================
-- SOVEREIGN CHAIN CONFIGURATION (Government-specific chains)
-- =============================================================================
CREATE TABLE core.sovereign_chain_configs (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Chain Identification
    chain_type VARCHAR(50) NOT NULL 
        CHECK (chain_type IN ('sarb_sovereign', 'zim_sovereign', 'sadc_regional', 'brics_bridge')),
    chain_name VARCHAR(100) NOT NULL,
    
    -- Connection Details
    rpc_endpoint VARCHAR(500),
    ws_endpoint VARCHAR(500),
    chain_id VARCHAR(50),
    
    -- Smart Contract
    anchor_contract_address VARCHAR(256),
    anchor_contract_abi JSONB,
    
    -- Authentication
    auth_type VARCHAR(20) DEFAULT 'private_key' 
        CHECK (auth_type IN ('private_key', 'kms', 'hsm', 'oauth')),
    credentials_encrypted BYTEA,  -- Encrypted credentials
    
    -- Anchor Settings
    anchor_frequency_minutes INTEGER DEFAULT 60,  -- How often to anchor
    min_batch_size INTEGER DEFAULT 100,  -- Minimum events before anchoring
    max_batch_size INTEGER DEFAULT 10000,  -- Maximum events per batch
    
    -- Gas/Cost Settings
    max_gas_price_gwei NUMERIC DEFAULT 100,
    priority_fee_gwei NUMERIC DEFAULT 2,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    last_anchor_at TIMESTAMPTZ,
    last_anchor_tx_hash VARCHAR(256),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    CONSTRAINT unique_chain_config UNIQUE (tenant_id, chain_type)
);

CREATE INDEX idx_sovereign_chain_configs_tenant ON core.sovereign_chain_configs(tenant_id, is_active) WHERE is_active = TRUE;

COMMENT ON TABLE core.sovereign_chain_configs IS 'Configuration for government-operated blockchain anchoring (SARB, RBZ, etc.)';

-- =============================================================================
-- MERKLE TREE FUNCTIONS
-- =============================================================================

-- Function: Create a new Merkle batch from pending events
CREATE OR REPLACE FUNCTION core.create_merkle_batch(
    p_tenant_id UUID,
    p_max_events INTEGER DEFAULT 1000
)
RETURNS UUID AS $$
DECLARE
    v_batch_id UUID;
    v_batch_number BIGINT;
    v_start_event_id BIGINT;
    v_end_event_id BIGINT;
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_event_count INTEGER;
    v_leaf_hashes TEXT[];
    v_merkle_root VARCHAR(64);
    v_previous_batch_id UUID;
    v_previous_hash VARCHAR(64);
BEGIN
    -- Get previous batch info for chaining
    SELECT batch_id, merkle_root INTO v_previous_batch_id, v_previous_hash
    FROM core.merkle_batches
    WHERE tenant_id = p_tenant_id
    ORDER BY batch_number DESC
    LIMIT 1;
    
    -- Get next batch number
    SELECT COALESCE(MAX(batch_number), 0) + 1 INTO v_batch_number
    FROM core.merkle_batches
    WHERE tenant_id = p_tenant_id;
    
    -- Get unbatched events
    SELECT 
        MIN(event_id),
        MAX(event_id),
        MIN(event_time),
        MAX(event_time),
        COUNT(*),
        array_agg(event_hash ORDER BY event_id)
    INTO 
        v_start_event_id,
        v_end_event_id,
        v_start_time,
        v_end_time,
        v_event_count,
        v_leaf_hashes
    FROM core_crypto.immutable_events
    WHERE tenant_id = p_tenant_id
      AND merkle_batch_id IS NULL;
    
    -- Check if we have events
    IF v_event_count IS NULL OR v_event_count = 0 THEN
        RETURN NULL;  -- No events to batch
    END IF;
    
    -- Generate Merkle root
    v_merkle_root := core_crypto.generate_merkle_root(v_leaf_hashes);
    
    -- Create batch
    INSERT INTO core.merkle_batches (
        tenant_id,
        batch_number,
        start_event_id,
        end_event_id,
        start_time,
        end_time,
        event_count,
        merkle_root,
        leaf_hashes,
        previous_batch_id,
        previous_batch_hash,
        status,
        sealed_at,
        sealed_by
    ) VALUES (
        p_tenant_id,
        v_batch_number,
        v_start_event_id,
        v_end_event_id,
        v_start_time,
        v_end_time,
        v_event_count,
        v_merkle_root,
        v_leaf_hashes,
        v_previous_batch_id,
        v_previous_hash,
        'sealed',
        NOW(),
        current_setting('app.current_user', TRUE)
    )
    RETURNING batch_id INTO v_batch_id;
    
    -- Update events with batch reference
    UPDATE core_crypto.immutable_events
    SET merkle_batch_id = v_batch_id
    WHERE tenant_id = p_tenant_id
      AND event_id BETWEEN v_start_event_id AND v_end_event_id
      AND merkle_batch_id IS NULL;
    
    RETURN v_batch_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.create_merkle_batch IS 'Creates a new Merkle batch from unbatched events';

-- Function: Verify a Merkle batch
CREATE OR REPLACE FUNCTION core.verify_merkle_batch(
    p_batch_id UUID
)
RETURNS TABLE (
    is_valid BOOLEAN,
    computed_root VARCHAR(64),
    stored_root VARCHAR(64),
    events_verified INTEGER
) AS $$
DECLARE
    v_batch RECORD;
    v_computed_root VARCHAR(64);
BEGIN
    SELECT * INTO v_batch FROM core.merkle_batches WHERE batch_id = p_batch_id;
    
    IF v_batch IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::VARCHAR, NULL::VARCHAR, 0;
        RETURN;
    END IF;
    
    -- Recompute Merkle root
    v_computed_root := core_crypto.generate_merkle_root(v_batch.leaf_hashes);
    
    RETURN QUERY SELECT 
        v_computed_root = v_batch.merkle_root,
        v_computed_root,
        v_batch.merkle_root,
        v_batch.event_count;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.verify_merkle_batch IS 'Verifies the integrity of a Merkle batch by recomputing the root';

-- =============================================================================
-- BLOCKCHAIN ANCHORING FUNCTIONS
-- =============================================================================

-- Function: Create blockchain anchor record
CREATE OR REPLACE FUNCTION core.create_blockchain_anchor(
    p_tenant_id UUID,
    p_batch_id UUID,
    p_chain_type VARCHAR,
    p_chain_id VARCHAR DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_anchor_id UUID;
    v_batch RECORD;
BEGIN
    SELECT * INTO v_batch FROM core.merkle_batches WHERE batch_id = p_batch_id;
    
    IF v_batch IS NULL OR v_batch.status != 'sealed' THEN
        RAISE EXCEPTION 'Batch not found or not sealed';
    END IF;
    
    INSERT INTO core.blockchain_anchors (
        tenant_id,
        batch_id,
        merkle_root,
        chain_type,
        chain_id,
        status,
        required_confirmations,
        created_at
    ) VALUES (
        p_tenant_id,
        p_batch_id,
        v_batch.merkle_root,
        p_chain_type,
        COALESCE(p_chain_id, '1'),
        'pending',
        CASE p_chain_type 
            WHEN 'ethereum' THEN 12
            WHEN 'polygon' THEN 20
            ELSE 1
        END,
        NOW()
    )
    RETURNING anchor_id INTO v_anchor_id;
    
    -- Update batch status
    UPDATE core.merkle_batches
    SET status = 'anchored'
    WHERE batch_id = p_batch_id;
    
    RETURN v_anchor_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.create_blockchain_anchor IS 'Creates a blockchain anchor record for a Merkle batch';

-- Function: Verify anchor on-chain (to be called by oracle/verifier)
CREATE OR REPLACE FUNCTION core.confirm_blockchain_anchor(
    p_anchor_id UUID,
    p_tx_hash VARCHAR,
    p_block_number BIGINT,
    p_block_hash VARCHAR,
    p_confirmation_count INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
    v_anchor RECORD;
BEGIN
    SELECT * INTO v_anchor FROM core.blockchain_anchors WHERE anchor_id = p_anchor_id;
    
    IF v_anchor IS NULL THEN
        RETURN FALSE;
    END IF;
    
    UPDATE core.blockchain_anchors
    SET 
        tx_hash = p_tx_hash,
        tx_block_number = p_block_number,
        tx_block_hash = p_block_hash,
        confirmation_count = p_confirmation_count,
        status = CASE 
            WHEN p_confirmation_count >= required_confirmations THEN 'confirmed'
            ELSE 'mined'
        END,
        confirmed_at = CASE 
            WHEN p_confirmation_count >= required_confirmations THEN NOW()
            ELSE confirmed_at
        END,
        verified_at = NOW(),
        verified_by = current_setting('app.current_user', TRUE)
    WHERE anchor_id = p_anchor_id;
    
    -- Update batch status if confirmed
    IF p_confirmation_count >= v_anchor.required_confirmations THEN
        UPDATE core.merkle_batches
        SET status = 'confirmed'
        WHERE batch_id = v_anchor.batch_id;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.confirm_blockchain_anchor IS 'Confirms a blockchain anchor after on-chain verification';

-- =============================================================================
-- GOVERNMENT VERIFICATION INTERFACE
-- =============================================================================

-- Function: Get verification proof for a specific event
CREATE OR REPLACE FUNCTION core.get_event_verification_proof(
    p_event_id BIGINT
)
RETURNS TABLE (
    event_hash VARCHAR,
    merkle_root VARCHAR,
    tx_hash VARCHAR,
    chain_type VARCHAR,
    proof_path TEXT[],
    batch_id UUID,
    anchor_status VARCHAR
) AS $$
DECLARE
    v_event RECORD;
    v_batch RECORD;
    v_anchor RECORD;
BEGIN
    SELECT * INTO v_event 
    FROM core_crypto.immutable_events 
    WHERE event_id = p_event_id;
    
    IF v_event IS NULL THEN
        RETURN;
    END IF;
    
    SELECT * INTO v_batch 
    FROM core.merkle_batches 
    WHERE batch_id = v_event.merkle_batch_id;
    
    IF v_batch IS NULL THEN
        RETURN QUERY SELECT 
            v_event.event_hash,
            NULL::VARCHAR,
            NULL::VARCHAR,
            NULL::VARCHAR,
            NULL::TEXT[],
            NULL::UUID,
            'unbatched'::VARCHAR;
        RETURN;
    END IF;
    
    SELECT * INTO v_anchor 
    FROM core.blockchain_anchors 
    WHERE batch_id = v_batch.batch_id
    ORDER BY created_at DESC
    LIMIT 1;
    
    RETURN QUERY SELECT 
        v_event.event_hash,
        v_batch.merkle_root,
        v_anchor.tx_hash,
        v_anchor.chain_type,
        v_batch.leaf_hashes,  -- Full proof path
        v_batch.batch_id,
        COALESCE(v_anchor.status, 'unanchored')::VARCHAR;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.get_event_verification_proof IS 'Returns verification proof for an event including Merkle path and blockchain anchor';

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.merkle_batches TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.blockchain_anchors TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.sovereign_chain_configs TO finos_admin;
GRANT EXECUTE ON FUNCTION core.create_merkle_batch TO finos_app;
GRANT EXECUTE ON FUNCTION core.verify_merkle_batch TO finos_app, finos_readonly;
GRANT EXECUTE ON FUNCTION core.create_blockchain_anchor TO finos_app;
GRANT EXECUTE ON FUNCTION core.confirm_blockchain_anchor TO finos_admin;
GRANT EXECUTE ON FUNCTION core.get_event_verification_proof TO finos_app, finos_readonly;

-- =============================================================================
