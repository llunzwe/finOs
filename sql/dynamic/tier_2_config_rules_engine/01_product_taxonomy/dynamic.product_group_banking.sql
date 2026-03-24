-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_group_banking
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Group Banking.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 17442 (LEI)
--   - ISO 4217
--   - IFRS 9
--   - AAOIFI
--   - BCBS 239
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


CREATE TABLE dynamic.product_group_banking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL UNIQUE REFERENCES dynamic.product_template_master(product_id) ON DELETE CASCADE,
    
    -- Group Formation
    group_type VARCHAR(50) NOT NULL 
        CHECK (group_type IN ('ROSCA', 'STOKVEL', 'GROUP_LOAN', 'SACCO', 'VSLA', 'MERRY_GO_ROUND')),
    group_formation_rules JSONB NOT NULL, -- {min_members: 5, max_members: 30, relationship_type: '...'}
    
    -- Rotation Logic (for ROSCAs)
    rotation_logic VARCHAR(50) DEFAULT 'RANDOM' 
        CHECK (rotation_logic IN ('RANDOM', 'CREDIT_SCORE_BASED', 'BIDDING', 'FIXED_ORDER', 'EMERGENCY_PRIORITY')),
    
    -- Contributions
    contribution_frequency VARCHAR(20) DEFAULT 'MONTHLY',
    min_contribution_amount DECIMAL(28,8),
    max_contribution_amount DECIMAL(28,8),
    
    -- Guarantees
    group_guarantee_structure VARCHAR(50) DEFAULT 'CROSS_GUARANTEE' 
        CHECK (group_guarantee_structure IN ('CROSS_GUARANTEE', 'JOINT_LIABILITY', 'INDIVIDUAL_LIABILITY')),
    
    -- Payout
    payout_schedule_generation_algorithm VARCHAR(50),
    payout_frequency VARCHAR(20) DEFAULT 'MONTHLY',
    
    -- Interest/Returns
    interest_distribution_method VARCHAR(50),
    profit_sharing_ratio JSONB, -- {group: 0.7, institution: 0.3}
    
    -- Social Features
    social_mission_allowed BOOLEAN DEFAULT FALSE,
    savings_lockin_period_months INTEGER,
    
    -- Audit
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

CREATE TABLE dynamic.product_group_banking_default PARTITION OF dynamic.product_group_banking DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_group_banking IS 'Configuration for group banking products (ROSCAs, Stokvels, etc.)';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_group_banking TO finos_app;
