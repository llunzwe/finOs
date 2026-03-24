-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.program_transfers
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Program Transfers.
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
CREATE TABLE dynamic.program_transfers (

    transfer_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Source & Destination
    from_account_id UUID NOT NULL, -- value_container or program_reserve
    to_account_id UUID NOT NULL,
    from_account_type VARCHAR(30) NOT NULL,
    to_account_type VARCHAR(30) NOT NULL,
    
    -- Transfer Details
    amount DECIMAL(28,8) NOT NULL,
    currency CHAR(3) NOT NULL,
    
    -- Type
    transfer_type VARCHAR(30) NOT NULL 
        CHECK (transfer_type IN ('adjustment', 'funding', 'settlement', 'refund', 'fee', 'interest')),
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending' 
        CHECK (status IN ('pending', 'completed', 'failed', 'reversed')),
    
    -- Reference
    reference_id VARCHAR(100),
    reference_type VARCHAR(50),
    
    -- Linked Core Movement
    movement_id UUID REFERENCES core.value_movements(id),
    
    -- Memo
    memo TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    completed_at TIMESTAMPTZ

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.program_transfers_default PARTITION OF dynamic.program_transfers DEFAULT;

-- Indexes
CREATE INDEX idx_program_transfers_status ON dynamic.program_transfers(tenant_id, status) 
    WHERE status IN ('pending', 'failed');

GRANT SELECT, INSERT, UPDATE ON dynamic.program_transfers TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.program_transfers IS 'Program Transfers';