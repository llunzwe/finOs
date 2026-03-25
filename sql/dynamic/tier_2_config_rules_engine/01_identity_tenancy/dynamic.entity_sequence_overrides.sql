-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 01 - Identity & Tenancy
-- TABLE: dynamic.entity_sequence_overrides
--
-- DESCRIPTION:
--   Entity sequence override configuration for tenant-specific numbering.
--   Configures custom sequences for entity codes per tenant.
--
-- CORE DEPENDENCY: 001_identity_and_tenancy.sql
--
-- ============================================================================

CREATE TABLE dynamic.entity_sequence_overrides (
    override_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Sequence Configuration
    entity_type VARCHAR(100) NOT NULL, -- 'CUSTOMER', 'ACCOUNT', 'TRANSACTION', etc.
    sequence_prefix VARCHAR(20) NOT NULL DEFAULT 'DYN',
    
    -- Override Settings
    start_number BIGINT DEFAULT 1,
    increment_by INTEGER DEFAULT 1,
    max_number BIGINT DEFAULT 999999999999,
    padding_length INTEGER DEFAULT 12,
    
    -- Year/Month Reset
    reset_frequency VARCHAR(20) DEFAULT 'NEVER', -- NEVER, YEARLY, MONTHLY, DAILY
    include_year_in_prefix BOOLEAN DEFAULT TRUE,
    include_month_in_prefix BOOLEAN DEFAULT TRUE,
    
    -- Custom Format
    custom_format VARCHAR(200), -- e.g., 'CUST-{YYYY}-{MM}-{SEQ:10}'
    
    -- Range Management
    reserved_ranges JSONB, -- [{"from": 1, "to": 1000, "purpose": "legacy"}]
    excluded_numbers BIGINT[], -- Specific numbers to skip
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_entity_type_override UNIQUE (tenant_id, entity_type)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.entity_sequence_overrides_default PARTITION OF dynamic.entity_sequence_overrides DEFAULT;

CREATE INDEX idx_sequence_override_type ON dynamic.entity_sequence_overrides(tenant_id, entity_type) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.entity_sequence_overrides IS 'Entity sequence override configuration for custom tenant numbering schemes. Tier 2 Low-Code';

CREATE TRIGGER trg_entity_sequence_overrides_audit
    BEFORE UPDATE ON dynamic.entity_sequence_overrides
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.entity_sequence_overrides TO finos_app;
