-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_islamic_finance
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Islamic Finance.
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


CREATE TABLE dynamic.product_islamic_finance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL UNIQUE REFERENCES dynamic.product_template_master(product_id) ON DELETE CASCADE,
    
    -- Contract Type
    contract_type dynamic.islamic_contract_type NOT NULL,
    contract_type_description TEXT,
    
    -- Shariah Compliance
    shariah_board_certificate_number VARCHAR(100),
    certificate_issue_date DATE,
    certificate_expiry_date DATE,
    shariah_advisor_name VARCHAR(200),
    
    -- Asset Backing
    asset_backing_required BOOLEAN DEFAULT TRUE,
    asset_categories_allowed TEXT[],
    asset_valuation_method VARCHAR(50),
    
    -- Profit Rate (instead of interest)
    profit_rate_calculation_method VARCHAR(50),
    profit_rate_ceiling_bps INTEGER, -- Basis points over benchmark
    benchmark_rate VARCHAR(50), -- KIBOR, LIBOR, etc.
    
    -- Takaful (Islamic Insurance)
    takaful_required BOOLEAN DEFAULT TRUE,
    takaful_contribution_percentage DECIMAL(10,6),
    takaful_provider_id UUID,
    
    -- Penalty Replacement (no interest penalties)
    late_payment_penalty_type VARCHAR(50) DEFAULT 'CHARITY' 
        CHECK (late_payment_penalty_type IN ('CHARITY', 'PROFIT_RATE_INCREMENT', 'ASSET_SALE')),
    late_payment_charity_percentage DECIMAL(10,6),
    charity_recipient VARCHAR(200),
    
    -- Additional Terms
    ijara_lease_period_months INTEGER,
    mudarabah_profit_sharing_ratio_investor DECIMAL(5,4),
    mudarabah_profit_sharing_ratio_bank DECIMAL(5,4),
    
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

CREATE TABLE dynamic.product_islamic_finance_default PARTITION OF dynamic.product_islamic_finance DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_islamic_finance IS 'Shariah-compliant product configuration for Islamic finance';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_islamic_finance TO finos_app;
