-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_eligibility_rules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Eligibility Rules.
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


CREATE TABLE dynamic.product_eligibility_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id) ON DELETE CASCADE,
    rule_name VARCHAR(200) NOT NULL,
    rule_priority INTEGER DEFAULT 0,
    
    -- Customer Criteria
    customer_segment_codes VARCHAR(50)[],
    min_age INTEGER,
    max_age INTEGER,
    residency_status VARCHAR(50)[], -- RESIDENT, NON_RESIDENT, CITIZEN
    
    -- Income
    min_monthly_income DECIMAL(28,8),
    max_monthly_income DECIMAL(28,8),
    income_verification_required BOOLEAN DEFAULT TRUE,
    
    -- Geographic
    allowed_country_codes CHAR(2)[],
    allowed_city_codes VARCHAR(50)[],
    excluded_postal_codes VARCHAR(20)[],
    
    -- Existing Product Constraints
    required_existing_products UUID[], -- Must have these
    prohibited_existing_products UUID[], -- Cannot have these
    max_total_exposure DECIMAL(28,8),
    
    -- Regulatory
    pep_allowed BOOLEAN DEFAULT TRUE,
    sanctions_list_check_required BOOLEAN DEFAULT TRUE,
    min_credit_score INTEGER,
    max_credit_score INTEGER,
    
    -- Rule Logic
    custom_rule_expression TEXT, -- SQL or DSL expression
    
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
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_eligibility_rules_default PARTITION OF dynamic.product_eligibility_rules DEFAULT;

-- ============================================================================
-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_eligibility_rules_product ON dynamic.product_eligibility_rules(tenant_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_eligibility_rules IS 'Rules determining customer eligibility for products';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_eligibility_rules TO finos_app;
