-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 13: ENTITLEMENTS & AUTHORIZATION
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: RBAC, 4-Eyes, Digital Signatures, MFA, SCA (PSD2)
-- Standards: ISO 27001, SOC 2, PSD2, GDPR Article 32
-- =============================================================================

-- =============================================================================
-- ENTITLEMENTS (Permissions)
-- =============================================================================
CREATE TABLE core.entitlements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Who
    agent_id UUID NOT NULL REFERENCES core.economic_agents(id),
    on_behalf_of_id UUID REFERENCES core.economic_agents(id), -- Agency relationship
    
    -- What
    container_id UUID REFERENCES core.value_containers(id),
    entitlement_type VARCHAR(50) NOT NULL 
        CHECK (entitlement_type IN ('debit', 'credit', 'view', 'freeze', 'close', 'modify', 'approve', 'admin')),
    
    -- Limits (Granular)
    limits JSONB DEFAULT '{}', -- {
                               --   "max_amount": 10000,
                               --   "daily_limit": 50000,
                               --   "monthly_limit": 500000,
                               --   "allowed_transaction_types": ["TRANSFER", "PAYMENT"],
                               --   "allowed_counterparties": [...],
                               --   "allowed_time_ranges": [{"start": "09:00", "end": "17:00"}]
                               -- }
    
    max_amount_per_transaction DECIMAL(28,8),
    max_amount_per_day DECIMAL(28,8),
    max_amount_per_month DECIMAL(28,8),
    max_transactions_per_day INTEGER,
    max_transactions_per_month INTEGER,
    
    -- Security Requirements
    requires_2fa BOOLEAN NOT NULL DEFAULT FALSE,
    requires_mfa BOOLEAN NOT NULL DEFAULT FALSE,
    requires_approval BOOLEAN NOT NULL DEFAULT FALSE,
    approver_ids UUID[], -- List of agents who can approve
    min_approval_level INTEGER DEFAULT 1,
    
    -- Temporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'active' 
        CHECK (status IN ('active', 'suspended', 'revoked', 'expired')),
    suspended_at TIMESTAMPTZ,
    suspended_reason VARCHAR(200),
    revoked_at TIMESTAMPTZ,
    revoked_reason VARCHAR(200),
    
    -- Audit
    granted_by UUID REFERENCES core.economic_agents(id),
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_by UUID REFERENCES core.economic_agents(id),
    
    -- Correlation
    correlation_id UUID,
    causation_id UUID,
    
    CONSTRAINT unique_entitlement UNIQUE (tenant_id, agent_id, container_id, entitlement_type, valid_from)
);

CREATE INDEX idx_entitlements_agent ON core.entitlements(agent_id, status) WHERE status = 'active';
CREATE INDEX idx_entitlements_container ON core.entitlements(container_id, entitlement_type) WHERE status = 'active';
CREATE INDEX idx_entitlements_tenant ON core.entitlements(tenant_id, status);
CREATE INDEX idx_entitlements_temporal ON core.entitlements(valid_from, valid_to) WHERE is_current = TRUE;
CREATE INDEX idx_entitlements_approval ON core.entitlements(requires_approval) WHERE requires_approval = TRUE;
CREATE INDEX idx_entitlements_correlation ON core.entitlements(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core.entitlements IS 'Granular entitlements with limits and approval chains';

-- =============================================================================
-- AUTHORIZATIONS (Proof of Consent)
-- =============================================================================
CREATE TABLE core.authorizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- What was authorized
    movement_id UUID REFERENCES core.value_movements(id),
    entitlement_id UUID REFERENCES core.entitlements(id),
    authorization_type VARCHAR(50) NOT NULL 
        CHECK (authorization_type IN ('transaction', 'batch', 'standing_order', 'limit_change', 'account_access')),
    
    -- Who authorized
    authorized_by UUID NOT NULL REFERENCES core.economic_agents(id),
    on_behalf_of UUID REFERENCES core.economic_agents(id),
    
    -- Authentication
    authentication_method VARCHAR(50) NOT NULL 
        CHECK (authentication_method IN ('password', 'biometric', 'hardware_token', 'smart_card', 'mfa', 'sso', 'api_key')),
    authentication_factors JSONB DEFAULT '[]', -- ["password", "sms_otp", "fingerprint"]
    
    -- SCA (Strong Customer Authentication) - PSD2
    sca_method VARCHAR(50) CHECK (sca_method IN ('OTP', 'BIOMETRIC', 'HARD_TOKEN', 'PUSH', 'QRCODE')),
    sca_exemption_applied BOOLEAN DEFAULT FALSE,
    sca_exemption_reason VARCHAR(50), -- 'low_value', 'subscription', 'merchant_initiated', etc.
    
    -- Digital Signature
    digital_signature BYTEA,
    signature_algorithm VARCHAR(20) DEFAULT 'ECDSA_SHA256',
    public_key_fingerprint VARCHAR(64),
    certificate_id VARCHAR(100), -- X.509 certificate reference
    certificate_chain TEXT,
    
    -- Signed Data Hash
    signed_data_hash VARCHAR(64),
    signed_data JSONB, -- What was actually signed
    
    -- Context
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ip_address INET,
    device_id VARCHAR(100),
    device_fingerprint VARCHAR(256),
    geolocation GEOGRAPHY(POINT),
    geolocation_accuracy DECIMAL(10,2), -- Meters
    
    -- 4-Eyes (Co-authorization)
    co_authorized_by UUID REFERENCES core.economic_agents(id),
    co_auth_timestamp TIMESTAMPTZ,
    co_auth_signature BYTEA,
    co_auth_certificate_id VARCHAR(100),
    
    -- Verification
    verification_status VARCHAR(20) DEFAULT 'verified' 
        CHECK (verification_status IN ('pending', 'verified', 'failed', 'revoked')),
    verified_at TIMESTAMPTZ,
    verification_failure_reason VARCHAR(200),
    
    -- Metadata
    user_agent TEXT,
    session_id UUID,
    correlation_id UUID
);

CREATE INDEX idx_authorizations_movement ON core.authorizations(movement_id);
CREATE INDEX idx_authorizations_agent ON core.authorizations(authorized_by, timestamp DESC);
CREATE INDEX idx_authorizations_timestamp ON core.authorizations(tenant_id, timestamp DESC);
CREATE INDEX idx_authorizations_verification ON core.authorizations(verification_status) WHERE verification_status != 'verified';
CREATE INDEX idx_authorizations_geo ON core.authorizations USING GIST(geolocation) WHERE geolocation IS NOT NULL;

COMMENT ON TABLE core.authorizations IS 'Cryptographic proof of authorization with digital signatures';

-- =============================================================================
-- ROLE DEFINITIONS (RBAC)
-- =============================================================================
CREATE TABLE core.roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    role_name VARCHAR(100) NOT NULL,
    role_type VARCHAR(50) NOT NULL CHECK (role_type IN ('system', 'business', 'compliance', 'admin')),
    description TEXT,
    
    -- Permissions (JSON for flexibility)
    permissions JSONB NOT NULL DEFAULT '[]', -- [
                                              --   {"resource": "container", "action": "view", "scope": "own"},
                                              --   {"resource": "movement", "action": "create", "limit": 10000}
                                              -- ]
    
    -- Constraints
    max_transaction_amount DECIMAL(28,8),
    daily_transaction_limit DECIMAL(28,8),
    requires_4_eyes BOOLEAN DEFAULT FALSE,
    
    -- Temporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    
    CONSTRAINT unique_role_name UNIQUE (tenant_id, role_name)
);

CREATE INDEX idx_roles_active ON core.roles(tenant_id, is_active) WHERE is_active = TRUE;

COMMENT ON TABLE core.roles IS 'Role-Based Access Control definitions';

-- =============================================================================
-- AGENT ROLE ASSIGNMENTS
-- =============================================================================
CREATE TABLE core.agent_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    agent_id UUID NOT NULL REFERENCES core.economic_agents(id),
    role_id UUID NOT NULL REFERENCES core.roles(id),
    
    -- Scope (can be limited)
    scope_container_id UUID,
    scope_agent_id UUID,
    scope_geography VARCHAR(50),
    
    -- Delegation
    delegated_by UUID REFERENCES core.economic_agents(id),
    delegation_reason TEXT,
    
    -- Temporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_by UUID,
    revoked_at TIMESTAMPTZ,
    revoked_by UUID,
    
    CONSTRAINT unique_agent_role UNIQUE (tenant_id, agent_id, role_id, valid_from)
);

CREATE INDEX idx_agent_roles_agent ON core.agent_roles(agent_id, is_active) WHERE is_active = TRUE;
CREATE INDEX idx_agent_roles_role ON core.agent_roles(role_id);

COMMENT ON TABLE core.agent_roles IS 'Role assignments for agents with temporal validity';

-- =============================================================================
-- ACCESS CONTROL LISTS (ACL)
-- =============================================================================
CREATE TABLE core.access_control_lists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Resource
    resource_type VARCHAR(50) NOT NULL 
        CHECK (resource_type IN ('container', 'movement', 'agent', 'report', 'setting', 'batch')),
    resource_id UUID NOT NULL,
    
    -- Principal
    principal_type VARCHAR(20) NOT NULL CHECK (principal_type IN ('agent', 'role', 'group')),
    principal_id UUID NOT NULL,
    
    -- Permissions
    permission VARCHAR(50) NOT NULL, -- 'read', 'write', 'delete', 'execute', 'admin'
    is_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Conditions (JSON)
    conditions JSONB DEFAULT '{}', -- {"time_range": "09:00-17:00", "ip_range": "10.0.0.0/8"}
    
    -- Temporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    
    CONSTRAINT unique_acl_entry UNIQUE (tenant_id, resource_type, resource_id, principal_type, principal_id, permission, valid_from)
);

CREATE INDEX idx_acl_resource ON core.access_control_lists(resource_type, resource_id);
CREATE INDEX idx_acl_principal ON core.access_control_lists(principal_type, principal_id);

COMMENT ON TABLE core.access_control_lists IS 'Fine-grained access control lists';

-- =============================================================================
-- AUTHORIZATION HISTORY
-- =============================================================================
CREATE TABLE core_history.authorization_attempts (
    time TIMESTAMPTZ NOT NULL,
    tenant_id UUID NOT NULL,
    
    attempt_id UUID NOT NULL,
    agent_id UUID NOT NULL,
    
    attempt_type VARCHAR(50) NOT NULL,
    resource_type VARCHAR(50),
    resource_id UUID,
    
    success BOOLEAN NOT NULL,
    failure_reason VARCHAR(200),
    
    authentication_method VARCHAR(50),
    ip_address INET,
    device_fingerprint VARCHAR(256),
    geolocation GEOGRAPHY(POINT),
    
    PRIMARY KEY (time, attempt_id)
);

SELECT create_hypertable('core_history.authorization_attempts', 'time', 
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists => TRUE);

CREATE INDEX idx_auth_attempts_agent ON core_history.authorization_attempts(agent_id, time DESC);
CREATE INDEX idx_auth_attempts_success ON core_history.authorization_attempts(tenant_id, success, time DESC) WHERE success = FALSE;

COMMENT ON TABLE core_history.authorization_attempts IS 'Audit log of all authorization attempts';

-- =============================================================================
-- ENTITLEMENT CHECK FUNCTION
-- =============================================================================
CREATE OR REPLACE FUNCTION core.check_entitlement(
    p_agent_id UUID,
    p_container_id UUID,
    p_entitlement_type VARCHAR,
    p_amount DECIMAL(28,8) DEFAULT NULL
) RETURNS TABLE (
    has_entitlement BOOLEAN,
    requires_approval BOOLEAN,
    approver_ids UUID[],
    requires_2fa BOOLEAN,
    limit_remaining DECIMAL(28,8),
    entitlement_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        TRUE as has_entitlement,
        e.requires_approval,
        e.approver_ids,
        e.requires_2fa,
        LEAST(
            COALESCE(e.max_amount_per_transaction, '999999999999'::DECIMAL) - COALESCE(p_amount, 0),
            COALESCE(e.max_amount_per_day, '999999999999'::DECIMAL) - COALESCE(
                (SELECT SUM(amount) FROM core.movement_legs 
                 WHERE container_id = p_container_id AND created_at > CURRENT_DATE),
                0
            )
        ) as limit_remaining,
        e.id as entitlement_id
    FROM core.entitlements e
    WHERE e.agent_id = p_agent_id
      AND (e.container_id = p_container_id OR e.container_id IS NULL)
      AND e.entitlement_type = p_entitlement_type
      AND e.status = 'active'
      AND e.valid_from <= NOW()
      AND e.valid_to > NOW()
      AND (p_amount IS NULL OR e.max_amount_per_transaction IS NULL OR e.max_amount_per_transaction >= p_amount)
    ORDER BY e.granted_at DESC
    LIMIT 1;
    
    -- If no rows returned, return FALSE
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, NULL::BOOLEAN, NULL::UUID[], NULL::BOOLEAN, NULL::DECIMAL, NULL::UUID;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION core.check_entitlement IS 'Validates if an agent has a specific entitlement for a container';

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.entitlements TO finos_app;
GRANT SELECT, INSERT ON core.authorizations TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.roles TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.agent_roles TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.access_control_lists TO finos_app;
GRANT SELECT, INSERT ON core_history.authorization_attempts TO finos_app;
GRANT EXECUTE ON FUNCTION core.check_entitlement TO finos_app;
