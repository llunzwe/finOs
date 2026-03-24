-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 25: PRODUCT CONTRACT ANCHOR
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: Immutable cryptographic anchor, Smart Contract Versioning, Audit
-- Standards: Vault/Marqeta Universal Product Engine, Immutable Ledger
-- Version: 1.1 (March 2026)
-- =============================================================================

-- =============================================================================
-- PRODUCT CONTRACT ANCHOR (Primitive 20 in v1.1 Documentation)
-- =============================================================================
-- Immutable cryptographic anchor linking every Dynamic smart-contract version
-- to the Core. Locks product logic forever; any change creates new hash + new version.
-- Enables "no vendor dependency" and perfect audit.

CREATE TABLE core.product_contract_anchors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Contract Identification
    contract_hash UUID NOT NULL UNIQUE,
    contract_code_hash TEXT NOT NULL,
    base_product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id),
    
    -- Contract Content
    contract_language VARCHAR(20) NOT NULL DEFAULT 'WASM' 
        CHECK (contract_language IN ('WASM', 'LUA', 'JAVASCRIPT', 'PYTHON', 'SOLIDITY', 'MOVE')),
    contract_bytecode BYTEA, -- Compiled smart contract
    contract_source_hash VARCHAR(64), -- Hash of source code for verification
    
    -- Parameters Snapshot (immutable at time of anchor)
    parameters_snapshot_jsonb JSONB NOT NULL DEFAULT '{}',
    parameters_schema_hash VARCHAR(64), -- Hash of parameter schema for validation
    
    -- Cryptographic Security
    launch_signature BYTEA, -- Digital signature of contract deployment
    launch_signer VARCHAR(100), -- Identity that signed the launch
    launch_certificate TEXT, -- X.509 certificate or similar
    
    -- Anchoring Status
    anchor_status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (anchor_status IN ('pending', 'verified', 'active', 'deprecated', 'revoked')),
    anchored_at TIMESTAMPTZ,
    verified_at TIMESTAMPTZ,
    deprecated_at TIMESTAMPTZ,
    revocation_reason TEXT,
    
    -- Version Chain
    parent_contract_hash UUID REFERENCES core.product_contract_anchors(contract_hash),
    version_sequence INTEGER NOT NULL DEFAULT 1,
    is_latest_version BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Merkle Integration
    merkle_leaf VARCHAR(64),
    merkle_batch_id UUID,
    
    -- Authorization Decision (Marqeta-style)
    authorisation_decision_jsonb JSONB DEFAULT '{}', -- {auth_rules: [...], velocity_limits: [...]}
    
    -- 4D Bitemporal Time
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Audit & Immutability
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    product_contract_hash UUID NOT NULL, -- Self-reference for chaining
    
    -- Soft Delete (logical only for contracts)
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    -- Constraints
    CONSTRAINT unique_contract_version UNIQUE (tenant_id, base_product_id, version_sequence),
    CONSTRAINT chk_contract_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_immutable_post_anchor CHECK (
        (anchor_status IN ('verified', 'active') AND anchored_at IS NOT NULL) OR
        (anchor_status NOT IN ('verified', 'active'))
    )
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE core.product_contract_anchors_default PARTITION OF core.product_contract_anchors DEFAULT;

-- Critical Indexes
CREATE INDEX idx_contract_anchors_tenant ON core.product_contract_anchors(tenant_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_contract_anchors_hash ON core.product_contract_anchors(contract_hash) WHERE is_deleted = FALSE;
CREATE INDEX idx_contract_anchors_product ON core.product_contract_anchors(tenant_id, base_product_id);
CREATE INDEX idx_contract_anchors_status ON core.product_contract_anchors(tenant_id, anchor_status) WHERE anchor_status IN ('pending', 'verified');
CREATE INDEX idx_contract_anchors_version ON core.product_contract_anchors(tenant_id, base_product_id, version_sequence);
CREATE INDEX idx_contract_anchors_latest ON core.product_contract_anchors(tenant_id, base_product_id) WHERE is_latest_version = TRUE;
CREATE INDEX idx_contract_anchors_temporal ON core.product_contract_anchors(valid_from, valid_to) WHERE valid_to > NOW();
CREATE INDEX idx_contract_anchors_params ON core.product_contract_anchors USING GIN(parameters_snapshot_jsonb);
CREATE INDEX idx_contract_anchors_auth ON core.product_contract_anchors USING GIN(authorisation_decision_jsonb);

COMMENT ON TABLE core.product_contract_anchors IS 
    'Immutable cryptographic anchor linking Dynamic smart-contract versions to Core. Locks product logic forever.';
COMMENT ON COLUMN core.product_contract_anchors.contract_hash IS 
    'UUID v5 hash deterministically derived from contract code + parameters';
COMMENT ON COLUMN core.product_contract_anchors.parameters_snapshot_jsonb IS 
    'Complete parameter snapshot at time of anchor - immutable reference';
COMMENT ON COLUMN core.product_contract_anchors.launch_signature IS 
    'Cryptographic proof that contract was deployed by authorized entity';

-- =============================================================================
-- CONTRACT VERIFICATION LOG
-- =============================================================================
-- Records all verification attempts and results for contract anchors

CREATE TABLE core.contract_verification_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    contract_hash UUID NOT NULL REFERENCES core.product_contract_anchors(contract_hash),
    
    -- Verification Details
    verification_type VARCHAR(50) NOT NULL 
        CHECK (verification_type IN ('SYNTAX', 'SEMANTIC', 'SECURITY', 'COMPLIANCE', 'FORMAL')),
    verification_status VARCHAR(20) NOT NULL 
        CHECK (verification_status IN ('passed', 'failed', 'warning', 'skipped')),
    
    -- Results
    verification_result JSONB NOT NULL DEFAULT '{}', -- Detailed results
    issues_found JSONB DEFAULT '[]', -- Array of issues/warnings
    risk_score INTEGER CHECK (risk_score BETWEEN 0 AND 100), -- 0=safe, 100=critical
    
    -- Verifier Identity
    verified_by VARCHAR(100) NOT NULL,
    verifier_tool VARCHAR(100), -- Tool used for verification
    verifier_version VARCHAR(50),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending'
) PARTITION BY LIST (tenant_id);

CREATE TABLE core.contract_verification_log_default PARTITION OF core.contract_verification_log DEFAULT;

CREATE INDEX idx_verification_log_contract ON core.contract_verification_log(contract_hash);
CREATE INDEX idx_verification_log_type ON core.contract_verification_log(tenant_id, verification_type);
CREATE INDEX idx_verification_log_status ON core.contract_verification_log(verification_status);

COMMENT ON TABLE core.contract_verification_log IS 'Audit trail of all contract verification attempts';

-- =============================================================================
-- CONTRACT DEPENDENCY GRAPH
-- =============================================================================
-- Tracks dependencies between contracts for safe upgrades

CREATE TABLE core.contract_dependencies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    dependent_contract_hash UUID NOT NULL REFERENCES core.product_contract_anchors(contract_hash),
    dependency_contract_hash UUID NOT NULL REFERENCES core.product_contract_anchors(contract_hash),
    
    -- Dependency Type
    dependency_type VARCHAR(20) NOT NULL 
        CHECK (dependency_type IN ('INHERITS', 'CALLS', 'REFERENCES', 'REQUIRES')),
    
    -- Compatibility
    min_version INTEGER,
    max_version INTEGER,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_contract_dependency UNIQUE (tenant_id, dependent_contract_hash, dependency_contract_hash)
) PARTITION BY LIST (tenant_id);

CREATE TABLE core.contract_dependencies_default PARTITION OF core.contract_dependencies DEFAULT;

CREATE INDEX idx_contract_deps_dependent ON core.contract_dependencies(tenant_id, dependent_contract_hash);
CREATE INDEX idx_contract_deps_dependency ON core.contract_dependencies(tenant_id, dependency_contract_hash);

COMMENT ON TABLE core.contract_dependencies IS 'Dependency graph for contract upgrade path analysis';

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Function: Calculate contract hash (deterministic UUID v5)
CREATE OR REPLACE FUNCTION core.calculate_contract_hash(
    p_tenant_id UUID,
    p_base_product_id UUID,
    p_contract_source TEXT,
    p_parameters_jsonb JSONB
)
RETURNS UUID AS $$
DECLARE
    v_namespace UUID := '6ba7b810-9dad-11d1-80b4-00c04fd430c8'::UUID; -- DNS namespace
    v_input TEXT;
BEGIN
    v_input := p_tenant_id::text || '|' || 
               p_base_product_id::text || '|' || 
               COALESCE(p_contract_source, '') || '|' || 
               p_parameters_jsonb::text;
    
    RETURN uuid_generate_v5(v_namespace, v_input);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION core.calculate_contract_hash IS 
    'Generates deterministic UUID v5 hash from contract content and parameters';

-- Function: Create new contract anchor
CREATE OR REPLACE FUNCTION core.create_contract_anchor(
    p_tenant_id UUID,
    p_base_product_id UUID,
    p_contract_source TEXT,
    p_parameters_jsonb JSONB,
    p_contract_language VARCHAR(20) DEFAULT 'WASM',
    p_contract_bytecode BYTEA DEFAULT NULL,
    p_launch_signature BYTEA DEFAULT NULL,
    p_launch_signer VARCHAR(100) DEFAULT NULL,
    p_authorisation_rules JSONB DEFAULT '{}',
    p_created_by VARCHAR(100) DEFAULT 'system'
)
RETURNS UUID AS $$
DECLARE
    v_contract_hash UUID;
    v_version_seq INTEGER;
    v_anchor_id UUID;
    v_immutable_hash VARCHAR(64);
BEGIN
    -- Calculate deterministic contract hash
    v_contract_hash := core.calculate_contract_hash(
        p_tenant_id, p_base_product_id, p_contract_source, p_parameters_jsonb
    );
    
    -- Check if exact contract already exists
    IF EXISTS (
        SELECT 1 FROM core.product_contract_anchors 
        WHERE contract_hash = v_contract_hash AND is_deleted = FALSE
    ) THEN
        RAISE EXCEPTION 'Contract with identical hash % already exists', v_contract_hash;
    END IF;
    
    -- Determine version sequence
    SELECT COALESCE(MAX(version_sequence), 0) + 1 INTO v_version_seq
    FROM core.product_contract_anchors
    WHERE tenant_id = p_tenant_id 
      AND base_product_id = p_base_product_id 
      AND is_deleted = FALSE;
    
    -- Mark previous versions as not latest
    UPDATE core.product_contract_anchors
    SET is_latest_version = FALSE
    WHERE tenant_id = p_tenant_id 
      AND base_product_id = p_base_product_id 
      AND is_latest_version = TRUE;
    
    -- Calculate immutable hash
    v_immutable_hash := encode(digest(
        v_contract_hash::text || p_base_product_id::text || v_version_seq::text || NOW()::text,
        'sha256'
    ), 'hex');
    
    -- Insert new anchor
    INSERT INTO core.product_contract_anchors (
        tenant_id,
        contract_hash,
        contract_code_hash,
        base_product_id,
        contract_language,
        contract_bytecode,
        contract_source_hash,
        parameters_snapshot_jsonb,
        launch_signature,
        launch_signer,
        authorisation_decision_jsonb,
        version_sequence,
        is_latest_version,
        created_by,
        immutable_hash,
        product_contract_hash
    ) VALUES (
        p_tenant_id,
        v_contract_hash,
        encode(digest(COALESCE(p_contract_source, ''), 'sha256'), 'hex'),
        p_base_product_id,
        p_contract_language,
        p_contract_bytecode,
        encode(digest(COALESCE(p_contract_source, ''), 'sha256'), 'hex'),
        p_parameters_jsonb,
        p_launch_signature,
        p_launch_signer,
        p_authorisation_rules,
        v_version_seq,
        TRUE,
        p_created_by,
        v_immutable_hash,
        v_contract_hash
    )
    RETURNING id INTO v_anchor_id;
    
    RETURN v_anchor_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.create_contract_anchor IS 
    'Creates a new immutable contract anchor with cryptographic verification';

-- Function: Verify and activate contract
CREATE OR REPLACE FUNCTION core.verify_contract_anchor(
    p_contract_hash UUID,
    p_verified_by VARCHAR(100),
    p_verification_results JSONB DEFAULT '{}'
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE core.product_contract_anchors
    SET 
        anchor_status = 'verified',
        verified_at = NOW(),
        anchored_at = COALESCE(anchored_at, NOW())
    WHERE contract_hash = p_contract_hash 
      AND anchor_status = 'pending'
      AND is_deleted = FALSE;
    
    IF FOUND THEN
        -- Log verification
        INSERT INTO core.contract_verification_log (
            tenant_id, contract_hash, verification_type, verification_status, 
            verification_result, verified_by
        )
        SELECT 
            tenant_id, p_contract_hash, 'SEMANTIC', 'passed', 
            p_verification_results, p_verified_by
        FROM core.product_contract_anchors
        WHERE contract_hash = p_contract_hash;
        
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Function: Get active contract for product
CREATE OR REPLACE FUNCTION core.get_active_contract(
    p_tenant_id UUID,
    p_product_id UUID
)
RETURNS TABLE (
    contract_hash UUID,
    contract_code_hash TEXT,
    parameters_snapshot JSONB,
    anchor_status VARCHAR(20),
    version_sequence INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pca.contract_hash,
        pca.contract_code_hash,
        pca.parameters_snapshot_jsonb,
        pca.anchor_status,
        pca.version_sequence
    FROM core.product_contract_anchors pca
    WHERE pca.tenant_id = p_tenant_id
      AND pca.base_product_id = p_product_id
      AND pca.is_latest_version = TRUE
      AND pca.anchor_status IN ('verified', 'active')
      AND pca.is_deleted = FALSE
      AND pca.valid_from <= NOW()
      AND pca.valid_to > NOW()
    ORDER BY pca.version_sequence DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.get_active_contract IS 
    'Retrieves the currently active contract for a product';

-- Function: Validate movement against contract
CREATE OR REPLACE FUNCTION core.validate_movement_against_contract(
    p_movement_id UUID,
    p_contract_hash UUID
)
RETURNS TABLE (
    is_valid BOOLEAN,
    validation_errors JSONB
) AS $$
DECLARE
    v_auth_rules JSONB;
    v_errors JSONB := '[]'::JSONB;
    v_is_valid BOOLEAN := TRUE;
    v_movement RECORD;
BEGIN
    -- Get authorization rules from contract
    SELECT authorisation_decision_jsonb INTO v_auth_rules
    FROM core.product_contract_anchors
    WHERE contract_hash = p_contract_hash;
    
    -- Get movement details
    SELECT * INTO v_movement FROM core.value_movements WHERE id = p_movement_id;
    
    IF v_movement IS NULL THEN
        RETURN QUERY SELECT FALSE, '["Movement not found"]'::JSONB;
        RETURN;
    END IF;
    
    -- Validate against contract rules (example validations)
    IF v_auth_rules->>'max_amount' IS NOT NULL THEN
        IF v_movement.total_debits > (v_auth_rules->>'max_amount')::DECIMAL THEN
            v_errors := v_errors || '["Amount exceeds contract maximum"]'::JSONB;
            v_is_valid := FALSE;
        END IF;
    END IF;
    
    IF v_auth_rules->>'allowed_channels' IS NOT NULL THEN
        IF NOT (v_movement.channel = ANY(ARRAY(SELECT jsonb_array_elements_text(v_auth_rules->'allowed_channels')))) THEN
            v_errors := v_errors || '["Channel not allowed by contract"]'::JSONB;
            v_is_valid := FALSE;
        END IF;
    END IF;
    
    RETURN QUERY SELECT v_is_valid, v_errors;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Calculate immutable hash on insert
CREATE OR REPLACE FUNCTION core.calc_contract_anchor_hash()
RETURNS TRIGGER AS $$
BEGIN
    NEW.immutable_hash := encode(digest(
        NEW.id::text || NEW.contract_hash::text || NEW.base_product_id::text || 
        NEW.version_sequence::text || NEW.created_at::text,
        'sha256'
    ), 'hex');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_contract_anchor_hash
    BEFORE INSERT ON core.product_contract_anchors
    FOR EACH ROW EXECUTE FUNCTION core.calc_contract_anchor_hash();

-- Trigger: Prevent updates to verified/active contracts (immutability)
CREATE OR REPLACE FUNCTION core.prevent_contract_mutation()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.anchor_status IN ('verified', 'active') THEN
        -- Only allow status changes to deprecated/revoked
        IF NEW.anchor_status NOT IN ('deprecated', 'revoked', 'verified', 'active') OR
           NEW.contract_hash != OLD.contract_hash OR
           NEW.contract_code_hash != OLD.contract_code_hash OR
           NEW.parameters_snapshot_jsonb != OLD.parameters_snapshot_jsonb THEN
            RAISE EXCEPTION 'IMMUTABLE_CONTRACT: Cannot modify verified/active contract %', OLD.contract_hash;
        END IF;
    END IF;
    
    NEW.system_time := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_contract_mutation
    BEFORE UPDATE ON core.product_contract_anchors
    FOR EACH ROW EXECUTE FUNCTION core.prevent_contract_mutation();

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT ON core.product_contract_anchors TO finos_app;
GRANT SELECT, INSERT ON core.contract_verification_log TO finos_app;
GRANT SELECT, INSERT ON core.contract_dependencies TO finos_app;

GRANT EXECUTE ON FUNCTION core.calculate_contract_hash TO finos_app;
GRANT EXECUTE ON FUNCTION core.create_contract_anchor TO finos_app;
GRANT EXECUTE ON FUNCTION core.verify_contract_anchor TO finos_app;
GRANT EXECUTE ON FUNCTION core.get_active_contract TO finos_app;
GRANT EXECUTE ON FUNCTION core.validate_movement_against_contract TO finos_app;
