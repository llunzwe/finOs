-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 20 - Blockchain Configuration
-- TABLE: dynamic.merkle_batch_policies
--
-- DESCRIPTION:
--   Merkle tree batch configuration for blockchain anchoring.
--   Configures batch sizes, anchoring frequency, and Merkle tree parameters.
--   Maps to core_crypto.immutable_events.merkle_batch_id.
--
-- CORE DEPENDENCY: 006_immutable_event_store.sql, 020_blockchain_anchoring.sql
--
-- COMPLIANCE:
--   - Immutable audit trails
--   - Government trust layer verification
--
-- ============================================================================

CREATE TABLE dynamic.merkle_batch_policies (
    policy_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Policy Identification
    policy_code VARCHAR(100) NOT NULL,
    policy_name VARCHAR(200) NOT NULL,
    policy_description TEXT,
    
    -- Batch Configuration
    batch_size INTEGER NOT NULL DEFAULT 1000, -- Number of events per batch
    max_batch_age_seconds INTEGER DEFAULT 3600, -- Force close batch after this time
    min_batch_size INTEGER DEFAULT 10, -- Minimum events before anchoring
    
    -- Merkle Tree Configuration
    tree_hash_algorithm VARCHAR(20) DEFAULT 'SHA-256',
    tree_encoding VARCHAR(20) DEFAULT 'hex', -- hex, base64
    include_event_hashes BOOLEAN DEFAULT TRUE,
    include_metadata_hash BOOLEAN DEFAULT TRUE,
    
    -- Event Filtering
    applicable_event_categories VARCHAR(50)[], -- 'movement', 'container', 'agent', 'system'
    applicable_event_types VARCHAR(100)[], -- Specific event type filters
    exclude_event_types VARCHAR(100)[], -- Event types to exclude
    
    -- Anchoring Configuration
    auto_anchor BOOLEAN DEFAULT TRUE,
    anchor_chain dynamic.anchor_chain NOT NULL,
    anchor_frequency_batches INTEGER DEFAULT 1, -- Anchor every N batches
    anchor_frequency_seconds INTEGER DEFAULT 86400, -- Or every N seconds
    
    -- Multi-Chain Anchoring
    mirror_to_chains dynamic.anchor_chain[], -- Additional chains for redundancy
    require_all_confirmations BOOLEAN DEFAULT FALSE, -- All chains must confirm
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    
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
    CONSTRAINT unique_merkle_policy_code UNIQUE (tenant_id, policy_code),
    CONSTRAINT chk_merkle_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_batch_size CHECK (batch_size > 0 AND min_batch_size <= batch_size)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.merkle_batch_policies_default PARTITION OF dynamic.merkle_batch_policies DEFAULT;

-- Indexes
CREATE INDEX idx_merkle_policy_chain ON dynamic.merkle_batch_policies(tenant_id, anchor_chain) WHERE is_active = TRUE AND is_current = TRUE;
CREATE INDEX idx_merkle_policy_default ON dynamic.merkle_batch_policies(tenant_id) WHERE is_default = TRUE;

-- Comments
COMMENT ON TABLE dynamic.merkle_batch_policies IS 'Merkle tree batch policies for blockchain anchoring - configures batch sizes and anchoring frequency. Tier 2 Low-Code';
COMMENT ON COLUMN dynamic.merkle_batch_policies.batch_size IS 'Maximum number of events per Merkle batch before anchoring';
COMMENT ON COLUMN dynamic.merkle_batch_policies.anchor_chain IS 'Primary blockchain for Merkle root anchoring';

-- Trigger
CREATE TRIGGER trg_merkle_batch_policies_audit
    BEFORE UPDATE ON dynamic.merkle_batch_policies
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.merkle_batch_policies TO finos_app;
