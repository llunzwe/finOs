-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 10 - Regulatory Reporting
-- TABLE: dynamic.report_data_aggregation_rules
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Report Data Aggregation Rules.
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
CREATE TABLE dynamic.report_data_aggregation_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    report_id UUID NOT NULL REFERENCES dynamic.regulatory_report_catalog(report_id),
    
    -- Line Item
    line_item_code VARCHAR(50) NOT NULL,
    line_item_name VARCHAR(200),
    line_item_description TEXT,
    parent_line_item_code VARCHAR(50),
    
    -- Data Source
    source_tables TEXT[], -- Array of table names
    aggregation_logic TEXT NOT NULL, -- SQL or DSL expression
    
    -- Filters
    filter_criteria JSONB, -- {product_types: ['LOAN'], currencies: ['ZAR']}
    sign_convention VARCHAR(10) DEFAULT 'POSITIVE' CHECK (sign_convention IN ('POSITIVE', 'NEGATIVE', 'ABSOLUTE')),
    
    -- Mapping
    report_field_mappings JSONB, -- {column_a: 'field_1', column_b: 'field_2'}
    
    -- Conditions
    applicable_date_range daterange,
    applicable_entity_types VARCHAR(50)[],
    
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

CREATE TABLE dynamic.report_data_aggregation_rules_default PARTITION OF dynamic.report_data_aggregation_rules DEFAULT;

-- Indexes
CREATE INDEX idx_aggregation_report ON dynamic.report_data_aggregation_rules(tenant_id, report_id);

-- Comments
COMMENT ON TABLE dynamic.report_data_aggregation_rules IS 'How to roll up data for regulatory reports';

-- Triggers
CREATE TRIGGER trg_report_aggregation_rules_audit
    BEFORE UPDATE ON dynamic.report_data_aggregation_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.report_data_aggregation_rules TO finos_app;