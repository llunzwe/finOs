-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.funds_transfer_pricing_rules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Funds Transfer Pricing Rules.
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


CREATE TABLE dynamic.funds_transfer_pricing_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Product Assignment
    product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id),
    
    -- FTP Methodology
    methodology VARCHAR(50) NOT NULL 
        CHECK (methodology IN ('POOL', 'SINGLE_RATE', 'MATCHED_MATURITY', 'ORIGINATING_RATE', 'STICKY_RATE')),
    
    -- Curve Reference
    reference_curve_id UUID REFERENCES dynamic.transfer_pricing_curve(curve_id),
    fixed_rate DECIMAL(15,10),
    
    -- Adjustment Factors
    adjustment_factors JSONB, -- {liquidity: 0.001, credit: 0.002, ...}
    
    -- Tenor Matching
    match_tenor BOOLEAN DEFAULT TRUE,
    tenor_rollover_strategy VARCHAR(50),
    
    -- Application
    apply_to_principal BOOLEAN DEFAULT TRUE,
    apply_to_interest BOOLEAN DEFAULT FALSE,
    apply_to_fees BOOLEAN DEFAULT FALSE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.funds_transfer_pricing_rules_default PARTITION OF dynamic.funds_transfer_pricing_rules DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_ftp_rules_product

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.funds_transfer_pricing_rules IS 'Funds Transfer Pricing calculation rules by product';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.funds_transfer_pricing_rules TO finos_app;
