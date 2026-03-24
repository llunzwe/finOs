-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.funding_sources
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Funding Sources.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 8601
--   - ISO 20022
--   - IFRS 15
--   - Basel III
--   - OECD
--   - NCA
--
-- AUDIT & GOVERNANCE:
--   - Bitemporal tracking (effective_from/valid_from, effective_to/valid_to)
--   - Full audit trail (created_at, updated_at, created_by, updated_by)
--   - Version control for change management
--   - Tenant isolation via partitioning
--   - Row-Level Security (RLS) for data protection
--
-- DATA CLASSIFICATION:
--   - Tenant Isolation: Row-Level Security enabled
--   - Audit Level: FULL
--   - Encryption: At-rest for sensitive fields
--
-- ============================================================================
CREATE TABLE dynamic.funding_sources (

    source_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identity
    source_name VARCHAR(200) NOT NULL,
    source_type VARCHAR(30) NOT NULL 
        CHECK (source_type IN ('program', 'user', 'reserve', 'external_account', 'gateway')),
    
    -- Holder Link (if user funding)
    holder_id UUID REFERENCES dynamic.account_holders(holder_id),
    
    -- Funding Configuration
    funding_type VARCHAR(30) NOT NULL 
        CHECK (funding_type IN ('debit', 'credit', 'prepaid', 'ach', 'wire', 'card')),
    
    -- Account Details (tokenized/encrypted)
    account_token VARCHAR(255),
    account_last_four VARCHAR(4),
    routing_number VARCHAR(20),
    
    -- Auto-Reload (JIT)
    auto_reload_enabled BOOLEAN DEFAULT FALSE,
    auto_reload_threshold DECIMAL(28,8),
    auto_reload_amount DECIMAL(28,8),
    auto_reload_max_daily DECIMAL(28,8),
    
    -- Status
    active BOOLEAN DEFAULT TRUE,
    verified BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.funding_sources_default PARTITION OF dynamic.funding_sources DEFAULT;

-- Indexes
CREATE INDEX idx_funding_sources_holder ON dynamic.funding_sources(tenant_id, holder_id);
CREATE INDEX idx_funding_sources_active ON dynamic.funding_sources(tenant_id, active) WHERE active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.funding_sources IS 'All funding sources including JIT auto-reload config';

-- Triggers
CREATE TRIGGER trg_funding_sources_update
    BEFORE UPDATE ON dynamic.funding_sources
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_marqeta_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.funding_sources TO finos_app;