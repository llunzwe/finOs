-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 09 - Collateral Security
-- TABLE: dynamic.security_perfection_checklist
-- COMPLIANCE: Basel III
--   - UNCITRAL
--   - LMA
--   - CMA
-- ============================================================================


CREATE TABLE dynamic.security_perfection_checklist (

    checklist_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    agreement_id UUID NOT NULL REFERENCES dynamic.security_agreement(agreement_id),
    
    -- Checklist Items
    checklist_item VARCHAR(200) NOT NULL,
    item_category VARCHAR(50), -- DOCUMENTATION, REGISTRATION, INSURANCE, etc.
    
    -- Status
    is_required BOOLEAN DEFAULT TRUE,
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    completed_by VARCHAR(100),
    
    -- Document
    document_reference VARCHAR(200),
    document_url VARCHAR(500),
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.security_perfection_checklist_default PARTITION OF dynamic.security_perfection_checklist DEFAULT;

-- Indexes
CREATE INDEX idx_checklist_agreement ON dynamic.security_perfection_checklist(tenant_id, agreement_id);

-- Comments
COMMENT ON TABLE dynamic.security_perfection_checklist IS 'Security perfection tracking checklist';

GRANT SELECT, INSERT, UPDATE ON dynamic.security_perfection_checklist TO finos_app;