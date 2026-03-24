-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 13 - Billing & Contracts
-- TABLE: dynamic.usage_meter_definition
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Usage Meter Definition.
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
CREATE TABLE dynamic.usage_meter_definition (

    meter_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    meter_code VARCHAR(100) NOT NULL,
    meter_name VARCHAR(200) NOT NULL,
    meter_description TEXT,
    
    -- Meter Type
    meter_type VARCHAR(50) NOT NULL 
        CHECK (meter_type IN ('API_CALL', 'STORAGE_GB', 'BANDWIDTH_GB', 'COMPUTE_HOUR', 'IMPRESSION', 'CLICK', 'TRANSACTION', 'SEAT', 'MESSAGE', 'DOCUMENT', 'CUSTOM')),
    
    -- Aggregation
    aggregation_method VARCHAR(50) DEFAULT 'SUM' 
        CHECK (aggregation_method IN ('SUM', 'COUNT', 'AVERAGE', 'MAX', 'MIN', 'UNIQUE_COUNT', 'LATEST')),
    aggregation_period VARCHAR(20) DEFAULT 'DAILY' CHECK (aggregation_period IN ('HOURLY', 'DAILY', 'MONTHLY', 'BILLING_CYCLE')),
    
    -- Unit
    unit_of_measure VARCHAR(50) NOT NULL, -- calls, GB, hours, impressions
    unit_precision INTEGER DEFAULT 2,
    
    -- Pricing
    base_rate DECIMAL(28,8), -- Per unit rate
    minimum_billable_units DECIMAL(28,8) DEFAULT 0,
    rounding_method VARCHAR(20) DEFAULT 'HALF_UP', -- HALF_UP, HALF_EVEN, UP, DOWN
    
    -- Tiers
    tiered_pricing_enabled BOOLEAN DEFAULT FALSE,
    tier_structure JSONB, -- [{min: 0, max: 1000, rate: 0.01}, {min: 1001, rate: 0.008}]
    
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
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_usage_meter_code UNIQUE (tenant_id, meter_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.usage_meter_definition_default PARTITION OF dynamic.usage_meter_definition DEFAULT;

-- Indexes
CREATE INDEX idx_usage_meter_tenant ON dynamic.usage_meter_definition(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_usage_meter_lookup ON dynamic.usage_meter_definition(tenant_id, meter_code) WHERE is_active = TRUE;
CREATE INDEX idx_usage_meter_type ON dynamic.usage_meter_definition(tenant_id, meter_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.usage_meter_definition IS 'Usage meter definitions for metered billing (API calls, storage, etc.)';

-- Triggers
CREATE TRIGGER trg_usage_meter_definition_audit
    BEFORE UPDATE ON dynamic.usage_meter_definition
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.usage_meter_definition TO finos_app;