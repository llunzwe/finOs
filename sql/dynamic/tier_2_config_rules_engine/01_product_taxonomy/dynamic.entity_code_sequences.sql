-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 01 - Product & Taxonomy Configuration
-- TABLE: dynamic.entity_code_sequences
-- COMPLIANCE: ISO 17442, ISO 4217, IFRS 9, BCBS 239
-- DESCRIPTION: Sequence generator for human-readable entity codes
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
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_dynamic_sequence UNIQUE (tenant_id, entity_type, prefix, year_month)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.entity_code_sequences_default PARTITION OF dynamic.entity_code_sequences DEFAULT;

CREATE INDEX idx_dynamic_sequences_lookup ON dynamic.entity_code_sequences(tenant_id, entity_type, prefix, year_month);

COMMENT ON TABLE dynamic.entity_code_sequences IS 'Sequence generator for dynamic layer entity codes';

GRANT SELECT, INSERT, UPDATE ON dynamic.entity_code_sequences TO finos_app;
GRANT USAGE, SELECT ON SEQUENCE dynamic.entity_code_sequences_sequence_id_seq TO finos_app;
