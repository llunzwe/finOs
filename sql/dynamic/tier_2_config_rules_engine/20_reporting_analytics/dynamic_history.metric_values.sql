-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 20 - Reporting Analytics
-- TABLE: dynamic_history.metric_values
-- COMPLIANCE: BCBS 239
--   - IFRS
--   - XBRL
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic_history.metric_values (

    value_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    metric_id UUID NOT NULL REFERENCES dynamic.metric_definitions(metric_id),
    
    -- Time
    metric_date DATE NOT NULL,
    metric_period VARCHAR(20) NOT NULL, -- DAILY, MONTHLY, QUARTERLY, ANNUAL
    
    -- Dimensions
    dimension_1 VARCHAR(100),
    dimension_2 VARCHAR(100),
    dimension_3 VARCHAR(100),
    
    -- Value
    metric_value DECIMAL(28,8) NOT NULL,
    metric_value_text TEXT,
    
    -- Context
    numerator DECIMAL(28,8),
    denominator DECIMAL(28,8),
    
    -- Comparison
    previous_period_value DECIMAL(28,8),
    yoy_value DECIMAL(28,8),
    variance_percentage DECIMAL(10,6),
    
    -- Status
    threshold_status VARCHAR(20) GENERATED ALWAYS AS (
        CASE 
            WHEN metric_value < 0 THEN 'INVALID'
            ELSE 'NORMAL'
        END
    ) STORED,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_metric_value UNIQUE (tenant_id, metric_id, metric_date, metric_period, dimension_1, dimension_2, dimension_3)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.metric_values_default PARTITION OF dynamic_history.metric_values DEFAULT;

-- Indexes
CREATE INDEX idx_metric_values_metric ON dynamic_history.metric_values(tenant_id, metric_id);
CREATE INDEX idx_metric_values_date ON dynamic_history.metric_values(metric_date DESC);
CREATE INDEX idx_metric_values_period ON dynamic_history.metric_values(tenant_id, metric_period, metric_date DESC);

-- Comments
COMMENT ON TABLE dynamic_history.metric_values IS 'Historical metric values with dimensional analysis';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.metric_values TO finos_app;