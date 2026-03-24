-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Enterprise Extensions
-- TABLE: dynamic.limit_hierarchy
--
-- DESCRIPTION:
--   Enterprise-grade multi-level limit management hierarchy.
--   Product → Customer → Group limits with inheritance and aggregation.
--
-- ============================================================================


CREATE TABLE dynamic.limit_hierarchy (
    limit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Limit Identification
    limit_code VARCHAR(100) NOT NULL,
    limit_name VARCHAR(200) NOT NULL,
    limit_description TEXT,
    
    -- Hierarchy Level
    limit_level VARCHAR(50) NOT NULL 
        CHECK (limit_level IN ('PRODUCT', 'CUSTOMER', 'GROUP', 'RELATIONSHIP', 'GLOBAL')),
    parent_limit_id UUID REFERENCES dynamic.limit_hierarchy(limit_id),
    
    -- Scope References
    product_type VARCHAR(50), -- If product-level
    product_instance_id UUID REFERENCES dynamic.product_instances(instance_id),
    customer_id UUID REFERENCES core.customers(id),
    group_id UUID, -- Customer group
    
    -- Limit Type
    limit_type VARCHAR(50) NOT NULL 
        CHECK (limit_type IN ('CREDIT', 'DEBIT', 'TRANSACTION', 'DAILY', 'MONTHLY', 'EXPOSURE')),
    
    -- Limit Values
    limit_amount DECIMAL(28,8) NOT NULL,
    limit_currency CHAR(3) REFERENCES core.currencies(code),
    warning_threshold_percentage DECIMAL(5,4) DEFAULT 0.80, -- 80%
    
    -- Usage Tracking
    current_utilization DECIMAL(28,8) DEFAULT 0,
    utilization_percentage DECIMAL(5,4) DEFAULT 0,
    available_amount DECIMAL(28,8) GENERATED ALWAYS AS (limit_amount - current_utilization) STORED,
    
    -- Time Controls
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    reset_frequency VARCHAR(20), -- 'DAILY', 'MONTHLY'
    
    -- Enforcement
    enforcement_action VARCHAR(50) DEFAULT 'BLOCK' 
        CHECK (enforcement_action IN ('BLOCK', 'WARN', 'ESCALATE', 'NOTIFY')),
    override_approval_required BOOLEAN DEFAULT TRUE,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_limit_code UNIQUE (tenant_id, limit_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.limit_hierarchy_default PARTITION OF dynamic.limit_hierarchy DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_limit_hierarchy_tenant ON dynamic.limit_hierarchy(tenant_id);
CREATE INDEX idx_limit_hierarchy_level ON dynamic.limit_hierarchy(tenant_id, limit_level);
CREATE INDEX idx_limit_hierarchy_customer ON dynamic.limit_hierarchy(tenant_id, customer_id);
CREATE INDEX idx_limit_hierarchy_product ON dynamic.limit_hierarchy(tenant_id, product_instance_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.limit_hierarchy IS 'Multi-level limit hierarchy - product, customer, group limits with inheritance. Tier 2 - Enterprise Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.limit_hierarchy TO finos_app;
