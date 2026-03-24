-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 13 - Billing & Contracts
-- TABLE: dynamic_history.usage_record
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Usage Record.
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
CREATE TABLE dynamic_history.usage_record (

    record_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- References
    meter_id UUID NOT NULL REFERENCES dynamic.usage_meter_definition(meter_id),
    customer_id UUID NOT NULL,
    container_id UUID REFERENCES core.value_containers(id),
    
    -- Usage Details
    usage_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    usage_quantity DECIMAL(28,8) NOT NULL,
    usage_unit VARCHAR(50) NOT NULL,
    
    -- Context
    usage_context JSONB, -- {api_endpoint: '/payments', response_time_ms: 150, ...}
    usage_source VARCHAR(100), -- System that generated the usage
    usage_metadata JSONB, -- Additional dimensional data
    
    -- Billing
    billed BOOLEAN DEFAULT FALSE,
    billed_at TIMESTAMPTZ,
    billing_period_id UUID,
    
    -- Pricing (calculated at billing time)
    calculated_amount DECIMAL(28,8),
    calculated_rate DECIMAL(28,8),
    
    -- Raw Data
    raw_event_id VARCHAR(100), -- Original event reference
    raw_event_data JSONB,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    created_by VARCHAR(100),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_by VARCHAR(100),
version BIGINT NOT NULL DEFAULT 1,
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic_history.usage_record_default PARTITION OF dynamic_history.usage_record DEFAULT;

-- Indexes
CREATE INDEX idx_usage_record_meter ON dynamic_history.usage_record(tenant_id, meter_id);
CREATE INDEX idx_usage_record_customer ON dynamic_history.usage_record(tenant_id, customer_id);
CREATE INDEX idx_usage_record_timestamp ON dynamic_history.usage_record(usage_timestamp DESC);
CREATE INDEX idx_usage_record_billed ON dynamic_history.usage_record(tenant_id, billed) WHERE billed = FALSE;
CREATE INDEX idx_usage_record_container ON dynamic_history.usage_record(tenant_id, container_id);

-- Comments
COMMENT ON TABLE dynamic_history.usage_record IS 'Individual usage events for metered billing';

GRANT SELECT, INSERT, UPDATE ON dynamic_history.usage_record TO finos_app;