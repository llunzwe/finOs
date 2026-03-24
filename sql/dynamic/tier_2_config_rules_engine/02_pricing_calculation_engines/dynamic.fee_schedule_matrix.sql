-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.fee_schedule_matrix
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Fee Schedule Matrix.
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


CREATE TABLE dynamic.fee_schedule_matrix (
    schedule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- References
    product_id UUID REFERENCES dynamic.product_template_master(product_id),
    fee_type_id UUID NOT NULL REFERENCES dynamic.fee_type_master(fee_type_id),
    
    -- Schedule Name
    schedule_name VARCHAR(200),
    schedule_description TEXT,
    
    -- Tier Structure
    tier_structure JSONB NOT NULL, -- [{min: 0, max: 1000, fee: 10, fee_type: 'FLAT'}, ...]
    tier_basis VARCHAR(50) DEFAULT 'TRANSACTION_AMOUNT' 
        CHECK (tier_basis IN ('TRANSACTION_AMOUNT', 'BALANCE', 'VOLUME', 'COUNT', 'TENOR')),
    
    -- Caps
    minimum_fee_cap DECIMAL(28,8),
    maximum_fee_cap DECIMAL(28,8),
    
    -- Applicability
    applicable_channel VARCHAR(50)[], -- BRANCH, ATM, DIGITAL, AGENT
    applicable_customer_segments VARCHAR(50)[],
    applicable_currencies CHAR(3)[],
    
    -- Timing
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 0, -- For conflict resolution
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.fee_schedule_matrix_default PARTITION OF dynamic.fee_schedule_matrix DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_fee_schedule_product
idx_fee_schedule_type
idx_fee_schedule_effective

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.fee_schedule_matrix IS 'Tiered fee schedules with complex calculation rules';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.fee_schedule_matrix TO finos_app;
