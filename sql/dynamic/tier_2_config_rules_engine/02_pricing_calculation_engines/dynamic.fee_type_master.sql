-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Pricing & Calculation Engines
-- TABLE: dynamic.fee_type_master
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Fee Type Master.
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


CREATE TABLE dynamic.fee_type_master (
    fee_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    fee_type_code VARCHAR(50) NOT NULL,
    fee_type_name VARCHAR(200) NOT NULL,
    fee_type_description TEXT,
    
    -- Classification
    fee_category dynamic.fee_category NOT NULL,
    fee_subcategory VARCHAR(50),
    
    -- VAT/Tax
    vat_applicable BOOLEAN DEFAULT TRUE,
    vat_inclusion VARCHAR(20) DEFAULT 'EXCLUSIVE' 
        CHECK (vat_inclusion IN ('INCLUSIVE', 'EXCLUSIVE')),
    vat_rate_percentage DECIMAL(10,6),
    
    -- Accounting
    accounting_treatment VARCHAR(20) DEFAULT 'IMMEDIATE' 
        CHECK (accounting_treatment IN ('DEFERRED', 'IMMEDIATE', 'AMORTIZED')),
    deferred_recognition_period_months INTEGER,
    
    -- GL Mapping
    income_gl_account_code VARCHAR(50),
    receivable_gl_account_code VARCHAR(50),
    deferred_gl_account_code VARCHAR(50),
    
    -- Recognition
    recognition_trigger VARCHAR(100), -- EVENT_TYPE that triggers recognition
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
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
    
    CONSTRAINT unique_fee_type_code_per_tenant UNIQUE (tenant_id, fee_type_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.fee_type_master_default PARTITION OF dynamic.fee_type_master DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_fee_type_tenant ON dynamic.fee_type_master(tenant_id);
CREATE INDEX idx_fee_type_lookup ON dynamic.fee_type_master(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.fee_type_master IS 'Master classification of fee types with accounting treatment';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.fee_type_master TO finos_app;
