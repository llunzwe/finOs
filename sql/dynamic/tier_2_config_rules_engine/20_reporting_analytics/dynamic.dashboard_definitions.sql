-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 20 - Reporting Analytics
-- TABLE: dynamic.dashboard_definitions
-- COMPLIANCE: BCBS 239
--   - IFRS
--   - XBRL
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.dashboard_definitions (

    dashboard_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    dashboard_code VARCHAR(100) NOT NULL,
    dashboard_name VARCHAR(200) NOT NULL,
    dashboard_description TEXT,
    
    -- Layout
    layout_config JSONB NOT NULL, -- {columns: 12, widgets: [{widget_id: '...', x: 0, y: 0, w: 6, h: 4}, ...]}
    
    -- Filters
    global_filters JSONB, -- [{name: 'date_range', type: 'daterange', default: '...'}, ...]
    
    -- Access Control
    is_public BOOLEAN DEFAULT FALSE,
    allowed_roles VARCHAR(100)[],
    allowed_users UUID[],
    
    -- Category
    dashboard_category VARCHAR(50), -- EXECUTIVE, OPERATIONAL, RISK, SALES, etc.
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_dashboard_code UNIQUE (tenant_id, dashboard_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.dashboard_definitions_default PARTITION OF dynamic.dashboard_definitions DEFAULT;

-- Indexes
CREATE INDEX idx_dashboards_tenant ON dynamic.dashboard_definitions(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_dashboards_category ON dynamic.dashboard_definitions(tenant_id, dashboard_category) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.dashboard_definitions IS 'Dashboard configurations with widget layouts';

-- Triggers
CREATE TRIGGER trg_dashboard_definitions_audit
    BEFORE UPDATE ON dynamic.dashboard_definitions
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.dashboard_definitions TO finos_app;