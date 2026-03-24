-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 07 - Insurance Takaful
-- TABLE: dynamic.reinsurance_treaty
-- COMPLIANCE: IFRS 17
--   - Solvency II
--   - AAOIFI
--   - IAIS
-- ============================================================================


CREATE TABLE dynamic.reinsurance_treaty (

    treaty_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Treaty Details
    treaty_name VARCHAR(200) NOT NULL,
    treaty_code VARCHAR(100) NOT NULL,
    treaty_description TEXT,
    
    -- Counterparty
    reinsurer_id UUID NOT NULL,
    reinsurer_name VARCHAR(200),
    reinsurer_rating VARCHAR(10),
    
    -- Treaty Type
    treaty_type dynamic.reinsurance_type NOT NULL,
    
    -- Terms
    treaty_limit DECIMAL(28,8),
    retention_limit DECIMAL(28,8),
    ceded_percentage DECIMAL(5,4), -- For quota share
    
    -- Layer (for XL)
    layer_attachment DECIMAL(28,8),
    layer_limit DECIMAL(28,8),
    
    -- Commission
    ceding_commission_percentage DECIMAL(10,6),
    profit_commission_structure JSONB,
    
    -- Period
    inception_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    
    -- Status
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'EXPIRED', 'CANCELLED')),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_treaty_code UNIQUE (tenant_id, treaty_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.reinsurance_treaty_default PARTITION OF dynamic.reinsurance_treaty DEFAULT;

-- Indexes
CREATE INDEX idx_treaty_tenant ON dynamic.reinsurance_treaty(tenant_id) WHERE status = 'ACTIVE';

-- Comments
COMMENT ON TABLE dynamic.reinsurance_treaty IS 'Reinsurance treaty agreements and terms';

-- Triggers
CREATE TRIGGER trg_reinsurance_treaty_audit
    BEFORE UPDATE ON dynamic.reinsurance_treaty
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.reinsurance_treaty TO finos_app;