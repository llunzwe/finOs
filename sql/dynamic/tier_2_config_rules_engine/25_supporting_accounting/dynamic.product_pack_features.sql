-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 25 - Supporting Accounting
-- TABLE: dynamic.product_pack_features
-- COMPLIANCE: IFRS
--   - SOX
--   - CASS
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.product_pack_features (

    feature_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    pack_id UUID NOT NULL REFERENCES dynamic.product_pack_enablement(pack_id),
    
    feature_name VARCHAR(100) NOT NULL,
    feature_description TEXT,
    
    -- Feature Configuration
    feature_config JSONB DEFAULT '{}',
    
    -- Status
    is_enabled BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.product_pack_features_default PARTITION OF dynamic.product_pack_features DEFAULT;

-- Triggers
CREATE TRIGGER trg_pack_features_update
    BEFORE UPDATE ON dynamic.product_pack_features
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_supporting_accounting_timestamps();

GRANT SELECT, INSERT, UPDATE ON dynamic.product_pack_features TO finos_app;