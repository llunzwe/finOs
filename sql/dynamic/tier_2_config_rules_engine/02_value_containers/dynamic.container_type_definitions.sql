-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Value Containers
-- TABLE: dynamic.container_type_definitions
--
-- DESCRIPTION:
--   Value container type definitions for financial accounts and holdings.
--   Configures container behaviors, restrictions, and operational rules.
--
-- CORE DEPENDENCY: 002_value_container.sql
--
-- ============================================================================

CREATE TABLE dynamic.container_type_definitions (
    type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Type Identification
    type_code VARCHAR(100) NOT NULL,
    type_name VARCHAR(200) NOT NULL,
    type_description TEXT,
    
    -- Container Category
    category VARCHAR(50) NOT NULL, -- 'DEPOSIT', 'LOAN', 'INVESTMENT', 'CUSTODY', 'ESCROW'
    subcategory VARCHAR(100),
    
    -- Accounting Behavior
    normal_balance VARCHAR(10) NOT NULL CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    is_asset_account BOOLEAN DEFAULT TRUE,
    
    -- Operational Restrictions
    allows_debits BOOLEAN DEFAULT TRUE,
    allows_credits BOOLEAN DEFAULT TRUE,
    allows_negative_balance BOOLEAN DEFAULT FALSE,
    minimum_balance_required BOOLEAN DEFAULT FALSE,
    minimum_balance_amount DECIMAL(28,8),
    
    -- Interest/Returns
    bears_interest BOOLEAN DEFAULT FALSE,
    interest_calculation_method VARCHAR(50), -- 'SIMPLE', 'COMPOUND', 'TIERED'
    default_interest_rate DECIMAL(10,6),
    
    -- Currency
    single_currency_only BOOLEAN DEFAULT TRUE,
    allowed_currencies CHAR(3)[],
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_system_defined BOOLEAN DEFAULT FALSE,
    
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
    
    CONSTRAINT unique_container_type_code UNIQUE (tenant_id, type_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.container_type_definitions_default PARTITION OF dynamic.container_type_definitions DEFAULT;

CREATE INDEX idx_container_type_category ON dynamic.container_type_definitions(tenant_id, category) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.container_type_definitions IS 'Value container type definitions for account classification and behavior. Tier 2 Low-Code';

CREATE TRIGGER trg_container_type_definitions_audit
    BEFORE UPDATE ON dynamic.container_type_definitions
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.container_type_definitions TO finos_app;
