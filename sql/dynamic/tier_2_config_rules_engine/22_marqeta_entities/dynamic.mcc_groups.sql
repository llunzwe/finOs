-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 22 - Marqeta Entities
-- TABLE: dynamic.mcc_groups
-- COMPLIANCE: PCI DSS
--   - EMV
--   - ISO 8583
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.mcc_groups (

    group_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    group_name VARCHAR(100) NOT NULL,
    group_description TEXT,
    
    -- MCCs in this group
    mcc_codes VARCHAR(10)[],
    
    -- Behavior
    default_action VARCHAR(20) DEFAULT 'allow' 
        CHECK (default_action IN ('allow', 'block', 'flag')),
    
    active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.mcc_groups_default PARTITION OF dynamic.mcc_groups DEFAULT;

GRANT SELECT, INSERT, UPDATE ON dynamic.mcc_groups TO finos_app;