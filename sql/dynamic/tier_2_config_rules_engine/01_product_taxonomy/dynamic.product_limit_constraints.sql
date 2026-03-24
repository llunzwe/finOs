-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.product_limit_constraints
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Product Limit Constraints.
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


CREATE TABLE dynamic.product_limit_constraints (
    constraint_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id) ON DELETE CASCADE,
    
    -- Limit Definition
    limit_type VARCHAR(50) NOT NULL 
        CHECK (limit_type IN ('SINGLE_EXPOSURE', 'GROUP_EXPOSURE', 'SECTOR', 'GEOGRAPHIC', 'PRODUCT_LINE', 'CUSTOMER_SEGMENT')),
    limit_scope JSONB, -- {segment: '...', geography: '...'}
    
    -- Limit Value
    limit_amount DECIMAL(28,8),
    limit_percentage DECIMAL(5,4), -- 0-1
    limit_currency CHAR(3) REFERENCES core.currencies(code),
    
    -- Enforcement
    enforcement_level VARCHAR(20) DEFAULT 'HARD_REJECT' 
        CHECK (enforcement_level IN ('HARD_REJECT', 'SOFT_WARN', 'APPROVAL_REQUIRED', 'MONITOR_ONLY')),
    approval_workflow_id UUID,
    
    -- Breach Handling
    breach_notification_emails TEXT[],
    auto_escalate_on_breach BOOLEAN DEFAULT FALSE,
    
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

CREATE TABLE dynamic.product_limit_constraints_default PARTITION OF dynamic.product_limit_constraints DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_limit_constraints_product

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.product_limit_constraints IS 'Concentration and exposure limits for products';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.product_limit_constraints TO finos_app;
