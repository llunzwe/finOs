-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 02 - Value Containers
-- TABLE: dynamic.measurement_unit_configs
--
-- DESCRIPTION:
--   Measurement unit configuration for value containers.
--   Configures units, precision, and conversion rules.
--
-- CORE DEPENDENCY: 002_value_container.sql
--
-- ============================================================================

CREATE TABLE dynamic.measurement_unit_configs (
    unit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Unit Identification
    unit_code VARCHAR(50) NOT NULL, -- 'USD', 'EUR', 'SHARES', 'OUNCES', 'BTC'
    unit_name VARCHAR(200) NOT NULL,
    unit_symbol VARCHAR(20),
    unit_description TEXT,
    
    -- Unit Classification
    unit_type VARCHAR(50) NOT NULL, -- 'CURRENCY', 'SHARES', 'WEIGHT', 'VOLUME', 'CRYPTO', 'TOKEN'
    is_fiat_currency BOOLEAN DEFAULT FALSE,
    is_cryptocurrency BOOLEAN DEFAULT FALSE,
    is_fungible BOOLEAN DEFAULT TRUE,
    
    -- Precision & Display
    decimal_places INTEGER DEFAULT 2,
    display_format VARCHAR(50), -- '#,##0.00', '0.00000000'
    rounding_method VARCHAR(20) DEFAULT 'HALF_UP', -- HALF_UP, HALF_DOWN, UP, DOWN
    
    -- Conversion
    base_unit_code VARCHAR(50), -- For subunits (e.g., 'USD' is base for 'CENTS')
    conversion_factor_to_base DECIMAL(28,18) DEFAULT 1, -- 1 USD = 100 CENTS
    
    -- Valuation
    valuation_source VARCHAR(100), -- Market data provider for non-currency units
    valuation_frequency VARCHAR(20) DEFAULT 'REALTIME', -- REALTIME, DAILY, MANUAL
    
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
    
    CONSTRAINT unique_unit_code UNIQUE (tenant_id, unit_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.measurement_unit_configs_default PARTITION OF dynamic.measurement_unit_configs DEFAULT;

CREATE INDEX idx_measurement_unit_type ON dynamic.measurement_unit_configs(tenant_id, unit_type) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.measurement_unit_configs IS 'Measurement unit configuration for value containers and currencies. Tier 2 Low-Code';

CREATE TRIGGER trg_measurement_unit_configs_audit
    BEFORE UPDATE ON dynamic.measurement_unit_configs
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.measurement_unit_configs TO finos_app;
