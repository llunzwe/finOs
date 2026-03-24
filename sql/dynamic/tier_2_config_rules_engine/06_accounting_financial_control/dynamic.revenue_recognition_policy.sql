-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 06 - Accounting Financial Control
-- TABLE: dynamic.revenue_recognition_policy
-- COMPLIANCE: IFRS 9
--   - IFRS 15
--   - SOX 404
--   - FCA CASS
-- ============================================================================


CREATE TABLE dynamic.revenue_recognition_policy (

    policy_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    policy_name VARCHAR(200) NOT NULL,
    policy_description TEXT,
    
    -- Scope
    product_id UUID REFERENCES dynamic.product_template_master(product_id),
    product_category_id UUID REFERENCES dynamic.product_category(category_id),
    revenue_type VARCHAR(50) NOT NULL, -- INTEREST, FEE, COMMISSION, etc.
    
    -- Recognition Timing
    recognition_trigger VARCHAR(50) NOT NULL 
        CHECK (recognition_trigger IN ('OVER_TIME', 'POINT_IN_TIME', 'PERCENTAGE_COMPLETE', 'MILESTONE')),
    
    -- Performance Obligations
    performance_obligations JSONB, -- [{obligation: '...', standalone_price: 100}, ...]
    
    -- Allocation
    allocation_method VARCHAR(50) DEFAULT 'STANDALONE_SELLING_PRICE' 
        CHECK (allocation_method IN ('STANDALONE_SELLING_PRICE', 'RESIDUAL', 'RELATIVE_STANDALONE')),
    
    -- Amortization
    amortization_period_months INTEGER,
    amortization_method VARCHAR(50) DEFAULT 'STRAIGHT_LINE',
    
    -- Deferral
    deferral_account_code VARCHAR(50),
    recognition_account_code VARCHAR(50),
    
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

CREATE TABLE dynamic.revenue_recognition_policy_default PARTITION OF dynamic.revenue_recognition_policy DEFAULT;

-- Indexes
CREATE INDEX idx_revenue_policy_product ON dynamic.revenue_recognition_policy(tenant_id, product_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.revenue_recognition_policy IS 'IFRS 15 revenue recognition timing rules';

-- Triggers
CREATE TRIGGER trg_revenue_policy_audit
    BEFORE UPDATE ON dynamic.revenue_recognition_policy
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.revenue_recognition_policy TO finos_app;