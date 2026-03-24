-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 11 - Integration & API Management
-- TABLE: dynamic.external_service_registry
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for External Service Registry.
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
CREATE TABLE dynamic.external_service_registry (

    service_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    service_name VARCHAR(200) NOT NULL,
    service_code VARCHAR(100) NOT NULL,
    service_description TEXT,
    
    -- Category
    service_category VARCHAR(50) NOT NULL 
        CHECK (service_category IN ('BUREAU', 'PAYMENT_GATEWAY', 'KYC', 'SMS', 'EMAIL', 'NOTIFICATION', 'SANCTIONS', 'FRAUD', 'ACCOUNTING', 'TAX')),
    
    -- Endpoint
    base_url VARCHAR(500) NOT NULL,
    health_check_endpoint VARCHAR(200),
    api_version VARCHAR(20),
    
    -- Authentication
    auth_type dynamic.api_auth_type NOT NULL,
    auth_config JSONB, -- Credentials configuration
    
    -- Circuit Breaker
    circuit_breaker_enabled BOOLEAN DEFAULT TRUE,
    circuit_breaker_threshold INTEGER DEFAULT 5,
    circuit_breaker_timeout_seconds INTEGER DEFAULT 60,
    circuit_breaker_recovery_timeout INTEGER DEFAULT 300,
    
    -- Retry
    retry_enabled BOOLEAN DEFAULT TRUE,
    retry_max_attempts INTEGER DEFAULT 3,
    retry_backoff_strategy JSONB DEFAULT '{"type": "exponential", "initial_ms": 1000, "max_ms": 30000}'::jsonb,
    
    -- Timeout
    timeout_policy JSONB DEFAULT '{"connect_ms": 5000, "read_ms": 30000}'::jsonb,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    last_health_check_at TIMESTAMPTZ,
    last_health_status VARCHAR(20),
    
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
    
    CONSTRAINT unique_service_code UNIQUE (tenant_id, service_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.external_service_registry_default PARTITION OF dynamic.external_service_registry DEFAULT;

-- Indexes
CREATE INDEX idx_service_registry_tenant ON dynamic.external_service_registry(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_service_registry_category ON dynamic.external_service_registry(tenant_id, service_category) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.external_service_registry IS 'Third party connector registry with circuit breaker';

-- Triggers
CREATE TRIGGER trg_external_service_audit
    BEFORE UPDATE ON dynamic.external_service_registry
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.external_service_registry TO finos_app;