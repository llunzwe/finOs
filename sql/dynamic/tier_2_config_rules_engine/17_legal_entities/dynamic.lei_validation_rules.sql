-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 17 - Legal Entities
-- TABLE: dynamic.lei_validation_rules
--
-- DESCRIPTION:
--   LEI (Legal Entity Identifier) validation rules.
--   Configures LEI validation, registration authority mappings.
--
-- CORE DEPENDENCY: 017_legal_entity_hierarchy_and_group_consolidation.sql
--
-- COMPLIANCE:
--   - ISO 17442 (LEI standard)
--   - GLEIF (Global LEI Foundation)
--
-- ============================================================================

CREATE TABLE dynamic.lei_validation_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- LEI Validation
    validate_checksum BOOLEAN DEFAULT TRUE,
    validate_against_gleif BOOLEAN DEFAULT TRUE,
    gleif_api_endpoint VARCHAR(500) DEFAULT 'https://api.gleif.org/api/v1/lei-records',
    
    -- Registration Authorities
    local_registration_authorities VARCHAR(100)[], -- e.g., 'CIPC', 'SEC', 'CompaniesHouse'
    ra_to_lei_mapping_enabled BOOLEAN DEFAULT TRUE,
    
    -- Entity Status Rules
    require_active_lei BOOLEAN DEFAULT TRUE,
    allowed_entity_statuses VARCHAR(50)[] DEFAULT ARRAY['ACTIVE'], -- ACTIVE, MERGED, LIQUIDATED
    
    -- Renewal Rules
    validate_renewal_status BOOLEAN DEFAULT TRUE,
    warning_before_expiry_days INTEGER DEFAULT 30,
    block_if_expired BOOLEAN DEFAULT FALSE,
    
    -- Data Quality
    require_legal_name_match BOOLEAN DEFAULT TRUE,
    require_address_match BOOLEAN DEFAULT FALSE,
    fuzzy_match_threshold DECIMAL(3,2) DEFAULT 0.90,
    
    -- Auto-Registration
    auto_register_if_missing BOOLEAN DEFAULT FALSE,
    auto_registration_provider VARCHAR(100),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    
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
    
    CONSTRAINT unique_lei_validation_rule UNIQUE (tenant_id, rule_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.lei_validation_rules_default PARTITION OF dynamic.lei_validation_rules DEFAULT;

CREATE INDEX idx_lei_validation_active ON dynamic.lei_validation_rules(tenant_id) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.lei_validation_rules IS 'LEI validation rules per ISO 17442 and GLEIF standards. Tier 2 Low-Code';

CREATE TRIGGER trg_lei_validation_rules_audit
    BEFORE UPDATE ON dynamic.lei_validation_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.lei_validation_rules TO finos_app;
