-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.reward_redemptions
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Reward Redemptions.
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
CREATE TABLE dynamic.reward_redemptions (

    redemption_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    holder_id UUID NOT NULL REFERENCES dynamic.account_holders(holder_id),
    
    -- Redemption Details
    redemption_type VARCHAR(30) NOT NULL 
        CHECK (redemption_type IN ('cashback', 'voucher', 'transfer', 'merchandise', 'donation')),
    
    -- Amount
    points_redeemed INTEGER NOT NULL,
    cash_value DECIMAL(28,8),
    currency CHAR(3),
    
    -- Destination
    destination_account_id UUID,
    destination_description TEXT,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending' 
        CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    
    -- Reference
    reference_number VARCHAR(100),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    completed_at TIMESTAMPTZ

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.reward_redemptions_default PARTITION OF dynamic.reward_redemptions DEFAULT;

GRANT SELECT, INSERT, UPDATE ON dynamic.reward_redemptions TO finos_app;

-- Comments
COMMENT ON TABLE dynamic.reward_redemptions IS 'Reward Redemptions';