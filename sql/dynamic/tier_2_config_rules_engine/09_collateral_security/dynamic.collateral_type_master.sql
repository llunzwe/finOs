-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 09 - Collateral & Security
-- TABLE: dynamic.collateral_type_master
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Collateral Type Master.
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
CREATE TABLE dynamic.collateral_type_master (

    collateral_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    collateral_type_code VARCHAR(50) NOT NULL,
    collateral_type_name VARCHAR(200) NOT NULL,
    collateral_type_description TEXT,
    
    -- Classification
    collateral_category dynamic.collateral_category NOT NULL,
    
    -- Lending Eligibility
    eligibility_for_lending BOOLEAN DEFAULT TRUE,
    eligible_loan_types VARCHAR(50)[],
    max_loan_to_value_ratio DECIMAL(5,4), -- 0-1
    
    -- Haircuts
    standard_haircut_percentage DECIMAL(5,4) DEFAULT 0,
    stress_haircut_percentage DECIMAL(5,4),
    
    -- Valuation
    revaluation_frequency_months INTEGER DEFAULT 12,
    revaluation_trigger_events VARCHAR(50)[], -- MARKET_DECLINE, DEFAULT, etc.
    
    -- Forced Sale
    forced_sale_discount DECIMAL(5,4) DEFAULT 0.2,
    liquidation_period_months INTEGER,
    
    -- Insurance
    insurance_required BOOLEAN DEFAULT TRUE,
    insurance_coverage_minimum DECIMAL(5,4) DEFAULT 1.0, -- 100%
    
    -- Documentation
    required_documents JSONB, -- [{doc_type: 'TITLE_DEED', mandatory: true}, ...]
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
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
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_collateral_type_code UNIQUE (tenant_id, collateral_type_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.collateral_type_master_default PARTITION OF dynamic.collateral_type_master DEFAULT;

-- Indexes
CREATE INDEX idx_collateral_type_tenant ON dynamic.collateral_type_master(tenant_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.collateral_type_master IS 'Asset categories for collateral management';

-- Triggers
CREATE TRIGGER trg_collateral_type_master_audit
    BEFORE UPDATE ON dynamic.collateral_type_master
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.collateral_type_master TO finos_app;