-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 20 - Blockchain Configuration
-- TABLE: dynamic.zk_proof_policies
--
-- DESCRIPTION:
--   Zero-knowledge proof configuration for privacy-preserving verification.
--   Configures ZK proof types, verification parameters, and circuit definitions.
--   Maps to core_crypto.immutable_events.zk_proof_type.
--
-- CORE DEPENDENCY: 006_immutable_event_store.sql
--
-- COMPLIANCE:
--   - Privacy-preserving verification
--   - GDPR data minimization
--
-- ============================================================================

CREATE TABLE dynamic.zk_proof_policies (
    policy_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Policy Identification
    policy_code VARCHAR(100) NOT NULL,
    policy_name VARCHAR(200) NOT NULL,
    policy_description TEXT,
    
    -- ZK Proof Configuration
    proof_type dynamic.zk_proof_type NOT NULL,
    circuit_id VARCHAR(200), -- Reference to compiled circuit
    proving_system VARCHAR(50) DEFAULT 'SNARK', -- SNARK, STARK, BULLETPROOFS, etc.
    
    -- Verification Parameters
    verification_key_hash VARCHAR(64), -- SHA-256 of verification key
    verification_key_storage VARCHAR(500), -- Path or URL to verification key
    public_input_schema JSONB, -- Schema for public inputs
    private_input_schema JSONB, -- Schema for private inputs (for documentation only)
    
    -- Application Context
    applicable_event_categories VARCHAR(50)[], -- Events this ZK policy applies to
    applicable_container_types VARCHAR(50)[], -- Container types for range proofs
    
    -- Proof Generation
    auto_generate BOOLEAN DEFAULT FALSE, -- Auto-generate proofs on event creation
    proof_generation_service VARCHAR(200), -- Service endpoint for proof generation
    generation_timeout_seconds INTEGER DEFAULT 60,
    
    -- Verification
    require_verification BOOLEAN DEFAULT TRUE,
    verification_service VARCHAR(200), -- Service endpoint for verification
    on_verification_failure VARCHAR(50) DEFAULT 'REJECT', -- REJECT, ALERT, LOG
    
    -- Privacy Settings
    reveal_commitment_only BOOLEAN DEFAULT TRUE, -- Only store commitment, not full proof
    data_retention_days INTEGER DEFAULT 2555, -- ~7 years default
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_zk_policy_code UNIQUE (tenant_id, policy_code),
    CONSTRAINT chk_zk_valid_dates CHECK (valid_from < valid_to)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.zk_proof_policies_default PARTITION OF dynamic.zk_proof_policies DEFAULT;

-- Indexes
CREATE INDEX idx_zk_policy_type ON dynamic.zk_proof_policies(tenant_id, proof_type) WHERE is_active = TRUE AND is_current = TRUE;

-- Comments
COMMENT ON TABLE dynamic.zk_proof_policies IS 'Zero-knowledge proof policies for privacy-preserving verification. Tier 2 Low-Code';
COMMENT ON COLUMN dynamic.zk_proof_policies.proof_type IS 'Type of ZK proof (range_proof, membership_proof, etc.)';
COMMENT ON COLUMN dynamic.zk_proof_policies.circuit_id IS 'Reference to compiled ZK circuit for proof generation';
COMMENT ON COLUMN dynamic.zk_proof_policies.verification_key_hash IS 'SHA-256 hash of verification key for integrity';

-- Trigger
CREATE TRIGGER trg_zk_proof_policies_audit
    BEFORE UPDATE ON dynamic.zk_proof_policies
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.zk_proof_policies TO finos_app;
