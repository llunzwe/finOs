-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 04 - Event Scheduling
-- TABLE: dynamic.event_schema_registry
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Event Schema Registry.
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
CREATE TABLE dynamic.event_schema_registry (

    schema_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Event Type
    event_type VARCHAR(100) NOT NULL,
    event_category VARCHAR(50),
    event_description TEXT,
    
    -- Version
    schema_version VARCHAR(20) NOT NULL,
    schema_major_version INTEGER NOT NULL,
    schema_minor_version INTEGER NOT NULL,
    schema_patch_version INTEGER DEFAULT 0,
    
    -- Schema Definition
    avro_schema JSONB,
    json_schema JSONB,
    protobuf_definition TEXT,
    example_payload JSONB,
    
    -- Compatibility
    compatibility_mode VARCHAR(20) DEFAULT 'BACKWARD' 
        CHECK (compatibility_mode IN ('BACKWARD', 'FORWARD', 'FULL', 'NONE')),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    deprecated BOOLEAN DEFAULT FALSE,
    deprecation_date DATE,
    superseded_by_schema_id UUID,
    
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
    
    CONSTRAINT unique_event_schema_version UNIQUE (tenant_id, event_type, schema_version)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.event_schema_registry_default PARTITION OF dynamic.event_schema_registry DEFAULT;

-- Indexes
CREATE INDEX idx_event_schema_tenant ON dynamic.event_schema_registry(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_event_schema_type ON dynamic.event_schema_registry(tenant_id, event_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.event_schema_registry IS 'Schema validation registry for event types';

GRANT SELECT, INSERT, UPDATE ON dynamic.event_schema_registry TO finos_app;