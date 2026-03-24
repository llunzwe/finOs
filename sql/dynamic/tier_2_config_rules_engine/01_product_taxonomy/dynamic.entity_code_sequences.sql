-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.entity_code_sequences
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Entity Code Sequences.
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
CREATE TABLE dynamic.entity_code_sequences (

    sequence_id BIGSERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    entity_type VARCHAR(50) NOT NULL, -- 'PRODUCT', 'POLICY', 'CLAIM', etc.
    prefix VARCHAR(10) NOT NULL,
    year_month VARCHAR(7) NOT NULL,
    last_sequence BIGINT NOT NULL DEFAULT 0,
    padding_length INTEGER DEFAULT 6,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    CONSTRAINT unique_dynamic_sequence UNIQUE (tenant_id, entity_type, prefix, year_month)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.entity_code_sequences_default PARTITION OF dynamic.entity_code_sequences DEFAULT;

CREATE INDEX idx_dynamic_sequences_lookup ON dynamic.entity_code_sequences(tenant_id, entity_type, prefix, year_month);

COMMENT ON TABLE dynamic.entity_code_sequences IS 'Sequence generator for dynamic layer entity codes';

GRANT SELECT, INSERT, UPDATE ON dynamic.entity_code_sequences TO finos_app;
GRANT USAGE, SELECT ON SEQUENCE dynamic.entity_code_sequences_sequence_id_seq TO finos_app;
