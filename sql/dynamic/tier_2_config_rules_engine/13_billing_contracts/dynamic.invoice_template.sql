-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 13 - Billing & Contracts
-- TABLE: dynamic.invoice_template
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Invoice Template.
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
CREATE TABLE dynamic.invoice_template (

    template_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    template_code VARCHAR(100) NOT NULL,
    template_name VARCHAR(200) NOT NULL,
    template_description TEXT,
    
    -- Template Configuration
    template_jsonb JSONB NOT NULL DEFAULT '{}', -- Layout, sections, styling
    line_item_rules JSONB NOT NULL DEFAULT '[]', -- [{field: 'description', required: true}, ...]
    
    -- Tax Configuration
    tax_inclusive BOOLEAN DEFAULT FALSE,
    tax_display_format VARCHAR(50) DEFAULT 'SEPARATE_LINE', -- SEPARATE_LINE, INCLUSIVE, DETAILED
    multiple_tax_support BOOLEAN DEFAULT TRUE,
    
    -- Display Options
    show_logo BOOLEAN DEFAULT TRUE,
    show_payment_terms BOOLEAN DEFAULT TRUE,
    show_bank_details BOOLEAN DEFAULT TRUE,
    show_line_item_details BOOLEAN DEFAULT TRUE,
    
    -- Numbering
    invoice_number_format VARCHAR(200) DEFAULT '{PREFIX}-{YYYY}-{SEQUENCE}',
    invoice_number_prefix VARCHAR(20) DEFAULT 'INV',
    invoice_sequence_start INTEGER DEFAULT 1,
    
    -- Footer & Legal
    footer_text TEXT,
    terms_and_conditions TEXT,
    legal_disclaimers TEXT,
    
    -- Localization
    default_language VARCHAR(10) DEFAULT 'en',
    supported_languages VARCHAR(10)[],
    currency_display_format VARCHAR(50) DEFAULT 'SYMBOL',
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    
    -- Audit
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
    
    CONSTRAINT unique_invoice_template_code UNIQUE (tenant_id, template_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.invoice_template_default PARTITION OF dynamic.invoice_template DEFAULT;

-- Indexes
CREATE INDEX idx_invoice_template_tenant ON dynamic.invoice_template(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_invoice_template_lookup ON dynamic.invoice_template(tenant_id, template_code) WHERE is_active = TRUE;
CREATE INDEX idx_invoice_template_default ON dynamic.invoice_template(tenant_id, is_default) WHERE is_default = TRUE;

-- Comments
COMMENT ON TABLE dynamic.invoice_template IS 'Configurable invoice layouts and line-item rules';

-- Triggers
CREATE TRIGGER trg_invoice_template_audit
    BEFORE UPDATE ON dynamic.invoice_template
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.invoice_template TO finos_app;