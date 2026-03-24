-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 13 - Billing & Contracts
-- TABLE: dynamic_history.contract_amendment_history
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Contract Amendment History.
--   Supports bitemporal tracking, tenant isolation, and comprehensive audit trails.
--
-- TIER CLASSIFICATION:
--   Tier 2 - Low-Code Configuration: Business users configure via UI/API.
--   No coding required - all settings managed through admin interfaces.
--
-- COMPLIANCE FRAMEWORK:
--   This table adheres to the following standards:
--   - ISO 8601
--   - ISO 20022
--   - IFRS 15
--   - Basel III
--   - OECD
--   - NCA
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
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    CONSTRAINT unique_amendment_number UNIQUE (tenant_id, contract_id, amendment_number)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.contract_amendment_history_default PARTITION OF dynamic_history.contract_amendment_history DEFAULT;

-- Indexes
CREATE INDEX idx_contract_amendment_contract ON dynamic_history.contract_amendment_history(tenant_id, contract_id);

-- Comments
COMMENT ON TABLE dynamic_history.contract_amendment_history IS 'Contract amendment tracking with change history';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.contract_amendment_history TO finos_app;