-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 13 - Billing Contracts
-- TABLE: dynamic_history.contract_amendment_history
-- COMPLIANCE: IFRS 15
--   - ISO 20022
--   - UNCITRAL
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic_history.contract_amendment_history (

    amendment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    contract_id UUID NOT NULL REFERENCES dynamic.contract_instance(contract_id) ON DELETE CASCADE,
    
    -- Amendment Details
    amendment_number INTEGER NOT NULL,
    amendment_description TEXT,
    amendment_reason TEXT,
    
    -- Changes
    changes_jsonb JSONB NOT NULL, -- {field: 'end_date', old_value: '...', new_value: '...'}
    
    -- Approval
    approved_by VARCHAR(100),
    approved_at TIMESTAMPTZ,
    
    -- Effective
    effective_date DATE NOT NULL,
    
    -- Document
    amendment_document_url VARCHAR(500),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    CONSTRAINT unique_amendment_number UNIQUE (tenant_id, contract_id, amendment_number)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.contract_amendment_history_default PARTITION OF dynamic_history.contract_amendment_history DEFAULT;

-- Indexes
CREATE INDEX idx_contract_amendment_contract ON dynamic_history.contract_amendment_history(tenant_id, contract_id);

-- Comments
COMMENT ON TABLE dynamic_history.contract_amendment_history IS 'Contract amendment tracking with change history';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.contract_amendment_history TO finos_app;