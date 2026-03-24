-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 20 - Reporting Analytics
-- TABLE: dynamic.dashboard_widget_templates
-- COMPLIANCE: BCBS 239
--   - IFRS
--   - XBRL
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.dashboard_widget_templates (

    widget_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    widget_code VARCHAR(100) NOT NULL,
    widget_name VARCHAR(200) NOT NULL,
    widget_description TEXT,
    
    -- Widget Type
    widget_type VARCHAR(50) NOT NULL 
        CHECK (widget_type IN ('CHART', 'TABLE', 'KPI', 'GAUGE', 'MAP', 'LIST', 'CUSTOM')),
    chart_type VARCHAR(50), -- LINE, BAR, PIE, AREA, SCATTER, HEATMAP (if chart)
    
    -- Data Source
    data_source_type VARCHAR(50) NOT NULL 
        CHECK (data_source_type IN ('METRIC', 'REPORT', 'QUERY', 'API', 'STATIC')),
    data_source_id UUID, -- References metric, report, etc.
    data_query TEXT, -- Custom SQL/query
    
    -- Configuration
    widget_config JSONB NOT NULL, -- {colors: [...], axes: {...}, legend: {...}}
    filter_config JSONB, -- Available filters
    drill_down_config JSONB, -- Drill-down paths
    
    -- Dimensions
    default_width INTEGER DEFAULT 6, -- Grid columns (out of 12)
    default_height INTEGER DEFAULT 4, -- Grid rows
    min_width INTEGER DEFAULT 3,
    min_height INTEGER DEFAULT 2,
    
    -- Refresh
    auto_refresh_enabled BOOLEAN DEFAULT FALSE,
    refresh_interval_seconds INTEGER DEFAULT 300,
    
    -- Interactivity
    click_actions JSONB, -- [{action: 'DRILL_DOWN', target: '...'}, ...]
    hover_config JSONB,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_widget_code UNIQUE (tenant_id, widget_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.dashboard_widget_templates_default PARTITION OF dynamic.dashboard_widget_templates DEFAULT;

-- Indexes
CREATE INDEX idx_widget_templates_tenant ON dynamic.dashboard_widget_templates(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_widget_templates_type ON dynamic.dashboard_widget_templates(tenant_id, widget_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.dashboard_widget_templates IS 'Reusable dashboard widget templates';

-- Triggers
CREATE TRIGGER trg_dashboard_widget_templates_audit
    BEFORE UPDATE ON dynamic.dashboard_widget_templates
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.dashboard_widget_templates TO finos_app;