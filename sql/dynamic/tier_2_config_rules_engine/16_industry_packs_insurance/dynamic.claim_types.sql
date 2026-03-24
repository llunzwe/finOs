-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 16 - Industry Packs Insurance
-- TABLE: dynamic.claim_types
-- COMPLIANCE: IFRS 17
--   - Solvency II
--   - IAIS
--   - POPIA
-- ============================================================================


CREATE TABLE dynamic.claim_types (

    claim_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    claim_type_code VARCHAR(100) NOT NULL,
    claim_type_name VARCHAR(200) NOT NULL,
    claim_type_description TEXT,
    
    -- Category
    claim_category VARCHAR(50) NOT NULL 
        CHECK (claim_category IN ('DEATH', 'DISABILITY', 'CRITICAL_ILLNESS', 'HOSPITALIZATION', 'ACCIDENT', 'MATURITY', 'SURRENDER', 'DAMAGE', 'THEFT', 'LOSS', 'LIABILITY')),
    
    -- Applicable Products
    applicable_product_ids UUID[],
    applicable_policy_types VARCHAR(50)[],
    
    -- Workflow
    workflow_template_id UUID REFERENCES dynamic.state_machine_definition(machine_id),
    default_workflow_code VARCHAR(100), -- Built-in workflow if no template
    
    -- Documentation Requirements
    required_documents JSONB NOT NULL, -- [{doc_type: 'DEATH_CERTIFICATE', mandatory: true, original_required: true}, ...]
    optional_documents JSONB,
    
    -- Processing
    target_processing_days INTEGER DEFAULT 30,
    fast_track_eligible BOOLEAN DEFAULT FALSE,
    fast_track_conditions JSONB,
    
    -- Investigation
    investigation_required BOOLEAN DEFAULT FALSE,
    investigation_triggers JSONB, -- [{condition: 'amount > 100000', action: 'INVESTIGATE'}]
    
    -- Settlement
    settlement_options JSONB, -- [{option: 'LUMP_SUM', default: true}, {option: 'INSTALLMENTS', conditions: '...'}]
    max_installments INTEGER,
    
    -- Exclusions
    claim_exclusions JSONB, -- [{exclusion_code: '...', description: '...'}]
    
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
    
    CONSTRAINT unique_claim_type_code UNIQUE (tenant_id, claim_type_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.claim_types_default PARTITION OF dynamic.claim_types DEFAULT;

-- Indexes
CREATE INDEX idx_claim_types_tenant ON dynamic.claim_types(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_claim_types_category ON dynamic.claim_types(tenant_id, claim_category) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.claim_types IS 'Insurance claim type definitions with document requirements';

-- Triggers
CREATE TRIGGER trg_claim_types_audit
    BEFORE UPDATE ON dynamic.claim_types
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.claim_types TO finos_app;