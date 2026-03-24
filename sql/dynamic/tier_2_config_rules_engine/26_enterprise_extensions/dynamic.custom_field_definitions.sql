-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Enterprise Extensions
-- TABLE: dynamic.custom_field_definitions
--
-- DESCRIPTION:
--   Enterprise-grade User-Defined Fields (UDF) engine configuration.
--   Tenant-specific custom fields for any entity without code changes.
--
-- ============================================================================


CREATE TABLE dynamic.custom_field_definitions (
    field_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Field Identification
    field_code VARCHAR(100) NOT NULL,
    field_name VARCHAR(200) NOT NULL,
    field_description TEXT,
    
    -- Entity Mapping
    applies_to_entity VARCHAR(50) NOT NULL 
        CHECK (applies_to_entity IN ('CUSTOMER', 'ACCOUNT', 'TRANSACTION', 'PRODUCT', 'LOAN', 'CLAIM', 'POLICY')),
    
    -- Data Type
    data_type VARCHAR(50) NOT NULL 
        CHECK (data_type IN ('STRING', 'TEXT', 'INTEGER', 'DECIMAL', 'BOOLEAN', 'DATE', 'DATETIME', 'JSON', 'REFERENCE', 'ENUM')),
    
    -- Validation Rules
    is_required BOOLEAN DEFAULT FALSE,
    is_unique BOOLEAN DEFAULT FALSE,
    min_length INTEGER,
    max_length INTEGER,
    min_value DECIMAL(28,8),
    max_value DECIMAL(28,8),
    regex_pattern VARCHAR(500),
    
    -- Enum Options (if data_type = 'ENUM')
    enum_options JSONB,
    
    -- Default Value
    default_value TEXT,
    
    -- Reference (if data_type = 'REFERENCE')
    reference_table VARCHAR(100),
    reference_column VARCHAR(100),
    
    -- UI Configuration
    display_label VARCHAR(200),
    display_order INTEGER DEFAULT 0,
    display_section VARCHAR(100),
    ui_component VARCHAR(50) DEFAULT 'TEXT' 
        CHECK (ui_component IN ('TEXT', 'TEXTAREA', 'NUMBER', 'DATE', 'SELECT', 'RADIO', 'CHECKBOX', 'JSON_EDITOR')),
    
    -- Access Control
    visible_to_roles VARCHAR(50)[],
    editable_by_roles VARCHAR(50)[],
    
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
    
    CONSTRAINT unique_field_code UNIQUE (tenant_id, field_code, applies_to_entity)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.custom_field_definitions_default PARTITION OF dynamic.custom_field_definitions DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_custom_field_tenant ON dynamic.custom_field_definitions(tenant_id);
CREATE INDEX idx_custom_field_entity ON dynamic.custom_field_definitions(tenant_id, applies_to_entity);
CREATE INDEX idx_custom_field_active ON dynamic.custom_field_definitions(tenant_id, is_active);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.custom_field_definitions IS 'Custom field definitions - UDF engine for tenant-specific extensions. Tier 2 - Enterprise Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.custom_field_definitions TO finos_app;
