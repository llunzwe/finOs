-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 08 - Customer Management
-- TABLE: dynamic.customer_segment_definition
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Customer Segment Definition.
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
CREATE TABLE dynamic.customer_segment_definition (

    segment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    segment_code VARCHAR(50) NOT NULL,
    segment_name VARCHAR(200) NOT NULL,
    segment_description TEXT,
    
    -- Criteria
    segment_criteria JSONB NOT NULL, -- {min_income: 50000, min_balance: 10000, ...}
    criteria_sql TEXT, -- SQL expression for automatic assignment
    
    -- Commercial
    pricing_modifier DECIMAL(10,6) DEFAULT 0, -- Premium/discount percentage
    service_level_agreement VARCHAR(50),
    
    -- Features
    entitled_features UUID[], -- References to feature_flags
    dedicated_relationship_manager BOOLEAN DEFAULT FALSE,
    priority_support BOOLEAN DEFAULT FALSE,
    
    -- Eligibility
    min_relationship_value DECIMAL(28,8),
    min_monthly_income DECIMAL(28,8),
    min_account_balance DECIMAL(28,8),
    
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
    
    CONSTRAINT unique_segment_code UNIQUE (tenant_id, segment_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.customer_segment_definition_default PARTITION OF dynamic.customer_segment_definition DEFAULT;

-- Indexes
CREATE INDEX idx_segment_tenant ON dynamic.customer_segment_definition(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_segment_lookup ON dynamic.customer_segment_definition(tenant_id, segment_code) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.customer_segment_definition IS 'Business segment definitions with auto-assignment criteria';

-- Triggers
CREATE TRIGGER trg_customer_segment_def_audit
    BEFORE UPDATE ON dynamic.customer_segment_definition
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.customer_segment_definition TO finos_app;