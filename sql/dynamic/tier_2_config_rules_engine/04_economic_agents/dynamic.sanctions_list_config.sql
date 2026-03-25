-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 04 - Economic Agents
-- TABLE: dynamic.sanctions_list_config
--
-- DESCRIPTION:
--   Sanctions list configuration for screening economic agents.
--   Configures OFAC, UN, EU sanctions list sources and screening rules.
--
-- CORE DEPENDENCY: 004_economic_agent_and_relationships.sql
--
-- COMPLIANCE:
--   - OFAC (Office of Foreign Assets Control)
--   - UN Sanctions
--   - EU Consolidated List
--   - FATF Recommendations
--
-- ============================================================================

CREATE TABLE dynamic.sanctions_list_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- List Identification
    list_code VARCHAR(100) NOT NULL,
    list_name VARCHAR(200) NOT NULL,
    list_description TEXT,
    
    -- Source Information
    list_source VARCHAR(100) NOT NULL, -- 'OFAC_SDN', 'OFAC_CONSOLIDATED', 'UN', 'EU', 'HMT', 'DFAT'
    list_provider VARCHAR(200), -- Vendor providing the list
    source_url VARCHAR(500),
    
    -- Update Configuration
    update_frequency VARCHAR(20) DEFAULT 'DAILY', -- REALTIME, HOURLY, DAILY, WEEKLY
    last_update_timestamp TIMESTAMPTZ,
    next_scheduled_update TIMESTAMPTZ,
    
    -- Screening Rules
    screening_scope VARCHAR(50) DEFAULT 'ALL', -- ALL, INDIVIDUALS, ENTITIES, VESSELS
    fuzzy_matching_enabled BOOLEAN DEFAULT TRUE,
    fuzzy_match_threshold DECIMAL(3,2) DEFAULT 0.85, -- 0.0 to 1.0
    name_variations_to_check INTEGER DEFAULT 5, -- Check top N name variations
    
    -- Field Mapping
    field_mappings JSONB, -- Maps list fields to core.economic_agents fields
    
    -- Alert Configuration
    alert_on_match BOOLEAN DEFAULT TRUE,
    auto_freeze_on_exact_match BOOLEAN DEFAULT FALSE,
    alert_severity VARCHAR(20) DEFAULT 'HIGH', -- LOW, MEDIUM, HIGH, CRITICAL
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_mandatory BOOLEAN DEFAULT TRUE,
    
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
    
    CONSTRAINT unique_sanctions_list_code UNIQUE (tenant_id, list_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.sanctions_list_config_default PARTITION OF dynamic.sanctions_list_config DEFAULT;

CREATE INDEX idx_sanctions_list_source ON dynamic.sanctions_list_config(tenant_id, list_source) WHERE is_active = TRUE AND is_current = TRUE;

COMMENT ON TABLE dynamic.sanctions_list_config IS 'Sanctions list configuration for OFAC, UN, EU screening. Tier 2 Low-Code';

CREATE TRIGGER trg_sanctions_list_config_audit
    BEFORE UPDATE ON dynamic.sanctions_list_config
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.sanctions_list_config TO finos_app;
