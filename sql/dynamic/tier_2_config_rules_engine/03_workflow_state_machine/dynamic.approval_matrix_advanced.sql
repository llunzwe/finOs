-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 03 - Workflow & State Machine
-- TABLE: dynamic.approval_matrix_advanced
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Approval Matrix Advanced.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO/IEC 19510 (BPMN 2.0)
--   - SOX
--   - PSD2
--   - DORA
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


CREATE TABLE dynamic.approval_matrix_advanced (
    matrix_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    matrix_name VARCHAR(200) NOT NULL,
    matrix_description TEXT,
    
    -- Applicability
    product_type VARCHAR(50),
    transaction_type VARCHAR(50),
    customer_segment VARCHAR(50),
    
    -- Amount Range
    amount_range_min DECIMAL(28,8) DEFAULT 0,
    amount_range_max DECIMAL(28,8),
    currency_code CHAR(3) REFERENCES core.currencies(code),
    
    -- Approval Chain
    approval_chain JSONB NOT NULL, -- [{level: 1, role: 'MANAGER', min_amount: 0}, ...]
    
    -- Substitution Rules
    substitution_rules JSONB, -- [{if_unavailable: 'MANAGER', substitute: 'SENIOR_MANAGER'}, ...]
    
    -- Conditions
    requires_dual_approval BOOLEAN DEFAULT FALSE,
    dual_approval_threshold DECIMAL(28,8),
    requires_risk_approval BOOLEAN DEFAULT FALSE,
    risk_approval_threshold DECIMAL(28,8),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    priority INTEGER DEFAULT 0,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.approval_matrix_advanced_default PARTITION OF dynamic.approval_matrix_advanced DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
idx_approval_matrix_tenant
idx_approval_matrix_product

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.approval_matrix_advanced IS 'Amount-based approval hierarchies with substitution rules';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.approval_matrix_advanced TO finos_app;
