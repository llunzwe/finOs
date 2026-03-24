-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 29 - AI & Embedded Finance
-- TABLE: dynamic.esg_carbon_tracking_config
--
-- DESCRIPTION:
--   Enterprise-grade ESG reporting and carbon tracking configuration.
--   Sustainability metrics, carbon footprint per transaction.
--
-- COMPLIANCE: TCFD, EU Taxonomy, SFDR, ISSB Standards
-- ============================================================================


CREATE TABLE dynamic.esg_carbon_tracking_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Configuration
    tracking_scope VARCHAR(50) NOT NULL 
        CHECK (tracking_scope IN ('SCOPE_1', 'SCOPE_2', 'SCOPE_3', 'PORTFOLIO', 'TRANSACTION')),
    
    -- Carbon Calculation
    calculation_method VARCHAR(50) DEFAULT 'SPEND_BASED' 
        CHECK (calculation_method IN ('SPEND_BASED', 'ACTIVITY_BASED', 'SUPPLIER_SPECIFIC')),
    emission_factors_source VARCHAR(100), -- 'GHG Protocol', 'Defra', 'EPA'
    
    -- Transaction Categories
    merchant_category_mapping JSONB DEFAULT '{}', -- MCC to carbon factor
    industry_sector_factors JSONB DEFAULT '{}',
    
    -- ESG Metrics
    track_carbon_emissions BOOLEAN DEFAULT TRUE,
    track_water_usage BOOLEAN DEFAULT FALSE,
    track_energy_consumption BOOLEAN DEFAULT FALSE,
    track_waste_generation BOOLEAN DEFAULT FALSE,
    
    -- Customer Engagement
    show_carbon_footprint_to_customers BOOLEAN DEFAULT FALSE,
    carbon_offsetting_enabled BOOLEAN DEFAULT FALSE,
    offsetting_providers VARCHAR(100)[],
    
    -- Reporting
    reporting_standard VARCHAR(50) DEFAULT 'GHG_PROTOCOL' 
        CHECK (reporting_standard IN ('GHG_PROTOCOL', 'TCFD', 'EU_TAXONOMY', 'SASB')),
    reporting_frequency VARCHAR(20) DEFAULT 'QUARTERLY',
    
    -- Goals
    carbon_reduction_target_percentage DECIMAL(5,4),
    target_year INTEGER,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.esg_carbon_tracking_config_default PARTITION OF dynamic.esg_carbon_tracking_config DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.esg_carbon_tracking_config IS 'ESG and carbon tracking configuration - sustainability metrics, transaction carbon footprint. Tier 2 - AI & Embedded Finance.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.esg_carbon_tracking_config TO finos_app;
