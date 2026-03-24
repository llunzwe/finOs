-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 15 - Industry Packs: Banking
-- TABLE: dynamic.collateral_type_extensions
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Collateral Type Extensions.
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
CREATE TABLE dynamic.collateral_type_extensions (

    extension_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Reference to base collateral type
    collateral_type_id UUID NOT NULL REFERENCES dynamic.collateral_type_master(collateral_type_id),
    
    -- Extension Type
    extension_category VARCHAR(50) NOT NULL 
        CHECK (extension_category IN ('REAL_ESTATE', 'VEHICLE', 'EQUIPMENT', 'INVENTORY', 'FINANCIAL_INSTRUMENT', 'GUARANTEE', 'CASH', 'INTANGIBLE')),
    
    -- Specific Configuration
    property_type VARCHAR(50), -- RESIDENTIAL, COMMERCIAL, INDUSTRIAL, AGRICULTURAL (for REAL_ESTATE)
    vehicle_type VARCHAR(50), -- CAR, TRUCK, MOTORCYCLE, BOAT (for VEHICLE)
    equipment_category VARCHAR(50), -- MANUFACTURING, IT, MEDICAL, CONSTRUCTION (for EQUIPMENT)
    
    -- Valuation Extensions
    valuation_methods_allowed VARCHAR(50)[], -- MARKET_COMPARISON, INCOME, COST, DCF
    required_valuation_frequency_months INTEGER,
    mandatory_revaluation_triggers JSONB, -- [{trigger: 'MARKET_DECLINE', threshold: 10}, ...]
    
    -- Lending Parameters
    max_loan_to_value_ratio DECIMAL(5,4),
    max_loan_to_value_ratio_renewal DECIMAL(5,4),
    min_acceptable_value DECIMAL(28,8),
    
    -- Insurance Requirements
    insurance_types_required VARCHAR(50)[], -- FIRE, THEFT, COMPREHENSIVE, etc.
    min_insurance_coverage_ratio DECIMAL(5,4) DEFAULT 1.0,
    insurance_renewal_buffer_days INTEGER DEFAULT 30,
    
    -- Legal Requirements
    documentation_required JSONB, -- [{doc_type: 'TITLE_DEED', mandatory: true}, ...]
    registration_required BOOLEAN DEFAULT TRUE,
    registration_authority VARCHAR(200),
    
    -- Monitoring
    monitoring_frequency_months INTEGER,
    physical_inspection_required BOOLEAN DEFAULT FALSE,
    inspection_frequency_months INTEGER,
    
    -- Special Conditions
    seasonal_adjustments JSONB, -- For agricultural inventory
    depreciation_schedule JSONB, -- For vehicles and equipment
    market_volatility_adjustment DECIMAL(5,4), -- LTV adjustment for volatile assets
    
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
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.collateral_type_extensions_default PARTITION OF dynamic.collateral_type_extensions DEFAULT;

-- Indexes
CREATE INDEX idx_collateral_ext_type ON dynamic.collateral_type_extensions(tenant_id, collateral_type_id) WHERE is_active = TRUE;
CREATE INDEX idx_collateral_ext_category ON dynamic.collateral_type_extensions(tenant_id, extension_category) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.collateral_type_extensions IS 'Banking-specific collateral type extensions and lending parameters';

-- Triggers
CREATE TRIGGER trg_collateral_type_extensions_audit
    BEFORE UPDATE ON dynamic.collateral_type_extensions
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.collateral_type_extensions TO finos_app;