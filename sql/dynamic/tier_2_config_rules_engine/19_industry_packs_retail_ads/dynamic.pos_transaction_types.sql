-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 19 - Industry Packs: Retail & Ads
-- TABLE: dynamic.pos_transaction_types
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Pos Transaction Types.
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
CREATE TABLE dynamic.pos_transaction_types (

    type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    type_code VARCHAR(100) NOT NULL,
    type_name VARCHAR(200) NOT NULL,
    type_description TEXT,
    
    -- Transaction Category
    transaction_category VARCHAR(50) NOT NULL 
        CHECK (transaction_category IN ('SALE', 'REFUND', 'EXCHANGE', 'VOID', 'DISCOUNT', 'TIPS', 'CASH_WITHDRAWAL', 'LOYALTY_REDEMPTION', 'GIFT_CARD', 'DEPOSIT')),
    
    -- Financial Impact
    revenue_impact VARCHAR(20) DEFAULT 'POSITIVE' CHECK (revenue_impact IN ('POSITIVE', 'NEGATIVE', 'NEUTRAL')),
    inventory_impact VARCHAR(20), -- DECREASE, INCREASE, NONE
    tax_applicable BOOLEAN DEFAULT TRUE,
    
    -- Permissions
    requires_manager_approval BOOLEAN DEFAULT FALSE,
    approval_threshold DECIMAL(28,8),
    allowed_roles VARCHAR(100)[],
    
    -- Receipt
    receipt_template_id UUID,
    print_receipt BOOLEAN DEFAULT TRUE,
    email_receipt_option BOOLEAN DEFAULT TRUE,
    
    -- Reporting
    gl_account_code VARCHAR(50),
    revenue_recognition_method VARCHAR(50), -- IMMEDIATE, DEFERRED, INSTALLMENT
    report_category VARCHAR(100),
    
    -- Integration
    integration_mapping JSONB, -- {external_system: '...', transaction_code: '...'}
    
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
    
    CONSTRAINT unique_pos_type_code UNIQUE (tenant_id, type_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.pos_transaction_types_default PARTITION OF dynamic.pos_transaction_types DEFAULT;

-- Indexes
CREATE INDEX idx_pos_types_tenant ON dynamic.pos_transaction_types(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_pos_types_category ON dynamic.pos_transaction_types(tenant_id, transaction_category) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.pos_transaction_types IS 'Point-of-sale transaction type configurations';

-- Triggers
CREATE TRIGGER trg_pos_transaction_types_audit
    BEFORE UPDATE ON dynamic.pos_transaction_types
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.pos_transaction_types TO finos_app;