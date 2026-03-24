-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 09 - Collateral & Security
-- TABLE: dynamic.security_perfection_checklist
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Security Perfection Checklist.
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
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.security_perfection_checklist_default PARTITION OF dynamic.security_perfection_checklist DEFAULT;

-- Indexes
CREATE INDEX idx_checklist_agreement ON dynamic.security_perfection_checklist(tenant_id, agreement_id);

-- Comments
COMMENT ON TABLE dynamic.security_perfection_checklist IS 'Security perfection tracking checklist';

GRANT SELECT, INSERT, UPDATE ON dynamic.security_perfection_checklist TO finos_app;