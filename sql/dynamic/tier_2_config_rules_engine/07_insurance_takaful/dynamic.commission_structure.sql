-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 07 - Insurance Takaful
-- TABLE: dynamic.commission_structure
-- COMPLIANCE: IFRS 17
--   - Solvency II
--   - AAOIFI
--   - IAIS
-- ============================================================================


CREATE TABLE dynamic.commission_structure (

    structure_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Scope
    product_id UUID NOT NULL REFERENCES dynamic.product_template_master(product_id),
    agent_tier VARCHAR(50) NOT NULL, -- AGENT, BROKER, SENIOR, etc.
    
    -- Commission Type
    commission_type VARCHAR(20) NOT NULL 
        CHECK (commission_type IN ('INITIAL', 'RENEWAL', 'OVERRIDING', 'BONUS')),
    
    -- Commission Rate
    commission_percentage DECIMAL(10,6) NOT NULL,
    commission_fixed_amount DECIMAL(28,8),
    
    -- Tiered Structure
    tiered_structure JSONB, -- [{min_premium: 0, max_premium: 10000, rate: 0.10}, ...]
    
    -- Clawback
    clawback_enabled BOOLEAN DEFAULT FALSE,
    clawback_period_months INTEGER,
    clawback_percentage DECIMAL(5,4),
    clawback_trigger VARCHAR(50), -- LAPSE, CANCELLATION, etc.
    
    -- Effective Period
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.commission_structure_default PARTITION OF dynamic.commission_structure DEFAULT;

-- Indexes
CREATE INDEX idx_commission_product ON dynamic.commission_structure(tenant_id, product_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.commission_structure IS 'Agent/broker commission rates by product and tier';

-- Triggers
CREATE TRIGGER trg_commission_structure_audit
    BEFORE UPDATE ON dynamic.commission_structure
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.commission_structure TO finos_app;