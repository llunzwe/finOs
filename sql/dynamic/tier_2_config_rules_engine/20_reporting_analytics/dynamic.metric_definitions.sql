-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 20 - Reporting Analytics
-- TABLE: dynamic.metric_definitions
-- COMPLIANCE: BCBS 239
--   - IFRS
--   - XBRL
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.metric_definitions (

    metric_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    metric_code VARCHAR(100) NOT NULL,
    metric_name VARCHAR(200) NOT NULL,
    metric_description TEXT,
    
    -- Categorization
    metric_category VARCHAR(50) NOT NULL 
        CHECK (metric_category IN ('FINANCIAL', 'RISK', 'OPERATIONAL', 'CUSTOMER', 'REGULATORY', 'STRATEGIC')),
    metric_subcategory VARCHAR(100), -- e.g., 'CREDIT_RISK', 'LIQUIDITY', 'PROFITABILITY'
    
    -- Calculation
    calculation_formula TEXT NOT NULL, -- SQL expression or formula
    calculation_method VARCHAR(50) DEFAULT 'SQL_QUERY' 
        CHECK (calculation_method IN ('SQL_QUERY', 'FORMULA', 'AGGREGATION', 'MACHINE_LEARNING')),
    
    -- Data Sources
    data_sources VARCHAR(100)[], -- Table/view names
    dimensions JSONB, -- [{name: 'product_line', type: 'string'}, ...]
    
    -- Format
    unit_of_measure VARCHAR(50), -- CURRENCY, PERCENTAGE, COUNT, RATIO, DAYS
    decimal_places INTEGER DEFAULT 2,
    display_format VARCHAR(50), -- NUMBER, CURRENCY, PERCENTAGE
    
    -- Thresholds
    target_value DECIMAL(28,8),
    warning_threshold_min DECIMAL(28,8),
    warning_threshold_max DECIMAL(28,8),
    critical_threshold_min DECIMAL(28,8),
    critical_threshold_max DECIMAL(28,8),
    
    -- Aggregation
    default_aggregation VARCHAR(20) DEFAULT 'SUM' 
        CHECK (default_aggregation IN ('SUM', 'AVERAGE', 'COUNT', 'MIN', 'MAX', 'MEDIAN')),
    supports_time_series BOOLEAN DEFAULT TRUE,
    
    -- Regulatory
    regulatory_reporting_field VARCHAR(100), -- Maps to regulatory report field
    basel_indicator BOOLEAN DEFAULT FALSE,
    
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
    
    CONSTRAINT unique_metric_code UNIQUE (tenant_id, metric_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.metric_definitions_default PARTITION OF dynamic.metric_definitions DEFAULT;

-- Indexes
CREATE INDEX idx_metric_definitions_tenant ON dynamic.metric_definitions(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_metric_definitions_category ON dynamic.metric_definitions(tenant_id, metric_category) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.metric_definitions IS 'KPI and metric definitions (LCR, loss ratio, churn, etc.)';

-- Triggers
CREATE TRIGGER trg_metric_definitions_audit
    BEFORE UPDATE ON dynamic.metric_definitions
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.metric_definitions TO finos_app;