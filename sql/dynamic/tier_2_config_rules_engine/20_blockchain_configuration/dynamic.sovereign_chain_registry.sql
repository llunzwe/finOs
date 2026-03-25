-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 20 - Blockchain Configuration
-- TABLE: dynamic.sovereign_chain_registry
--
-- DESCRIPTION:
--   Registry of sovereign blockchain endpoints for government trust anchoring.
--   Configures SARB, RBZ, CBUAE, BRICS chain connections.
--   Maps to core_crypto.immutable_events.anchor_chain.
--
-- CORE DEPENDENCY: 020_blockchain_anchoring.sql
--
-- COMPLIANCE:
--   - Sovereign blockchain integration
--   - Cross-border regulatory coordination
--
-- ============================================================================

CREATE TABLE dynamic.sovereign_chain_registry (
    chain_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Chain Identification
    chain_code VARCHAR(100) NOT NULL,
    chain_name VARCHAR(200) NOT NULL,
    chain_type dynamic.anchor_chain NOT NULL,
    chain_description TEXT,
    
    -- Sovereign Authority
    sovereign_authority VARCHAR(200) NOT NULL, -- 'South African Reserve Bank', 'Reserve Bank of Zimbabwe', etc.
    jurisdiction_code VARCHAR(10) REFERENCES core.jurisdictions(iso_code),
    regulatory_framework VARCHAR(200),
    
    -- Connection Endpoints
    rpc_endpoint_primary VARCHAR(500) NOT NULL,
    rpc_endpoint_failover VARCHAR(500),
    websocket_endpoint VARCHAR(500),
    explorer_url VARCHAR(500),
    
    -- Authentication
    auth_type VARCHAR(50) DEFAULT 'API_KEY', -- API_KEY, CERTIFICATE, OAUTH2
    auth_config JSONB, -- Encrypted credentials, certificates, etc.
    
    -- Chain Parameters
    chain_id_network INTEGER, -- Network/Chain ID for EVM chains
    native_currency_symbol VARCHAR(10),
    block_time_seconds INTEGER DEFAULT 10,
    confirmation_blocks INTEGER DEFAULT 6,
    gas_price_strategy VARCHAR(50) DEFAULT 'auto', -- auto, fixed, oracle
    
    -- Anchoring Costs
    cost_per_anchor_native DECIMAL(28,18),
    cost_per_anchor_usd DECIMAL(28,8),
    budget_limit_monthly_usd DECIMAL(28,8),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_production BOOLEAN DEFAULT FALSE,
    health_status VARCHAR(20) DEFAULT 'UNKNOWN', -- HEALTHY, DEGRADED, UNAVAILABLE, UNKNOWN
    last_health_check TIMESTAMPTZ,
    
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
    CONSTRAINT unique_chain_code UNIQUE (tenant_id, chain_code),
    CONSTRAINT unique_chain_type_per_tenant UNIQUE (tenant_id, chain_type),
    CONSTRAINT chk_sovereign_valid_dates CHECK (valid_from < valid_to)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.sovereign_chain_registry_default PARTITION OF dynamic.sovereign_chain_registry DEFAULT;

-- Indexes
CREATE INDEX idx_sovereign_chain_type ON dynamic.sovereign_chain_registry(tenant_id, chain_type) WHERE is_active = TRUE AND is_current = TRUE;
CREATE INDEX idx_sovereign_chain_jurisdiction ON dynamic.sovereign_chain_registry(tenant_id, jurisdiction_code) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.sovereign_chain_registry IS 'Sovereign blockchain registry for government trust anchoring (SARB, RBZ, BRICS). Tier 2 Low-Code';
COMMENT ON COLUMN dynamic.sovereign_chain_registry.sovereign_authority IS 'Government authority operating the blockchain';
COMMENT ON COLUMN dynamic.sovereign_chain_registry.auth_config IS 'Encrypted authentication credentials (API keys, certificates)';

-- Trigger
CREATE TRIGGER trg_sovereign_chain_registry_audit
    BEFORE UPDATE ON dynamic.sovereign_chain_registry
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.sovereign_chain_registry TO finos_app;
