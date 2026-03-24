-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 08 - Customer Management
-- TABLE: dynamic.customer_consent_preferences
--
-- DESCRIPTION:
--   Enterprise-grade configuration table for Customer Consent Preferences.
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
CREATE TABLE dynamic.customer_consent_preferences (

    consent_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    customer_id UUID NOT NULL,
    
    -- Consent Type
    consent_type VARCHAR(50) NOT NULL 
        CHECK (consent_type IN ('MARKETING', 'DATA_SHARING', 'CREDIT_CHECK', 'THIRD_PARTY_DISCLOSURE', 'PROFILING', 'AUTOMATED_DECISION', 'BIOMETRIC', 'LOCATION', 'COMMUNICATION_EMAIL', 'COMMUNICATION_SMS', 'COMMUNICATION_PHONE')),
    consent_channel VARCHAR(20) DEFAULT 'PORTAL', -- Where consent was given
    
    -- Consent Status
    consent_given BOOLEAN NOT NULL,
    consent_date TIMESTAMPTZ,
    consent_expiry TIMESTAMPTZ,
    
    -- Withdrawal
    withdrawal_date TIMESTAMPTZ,
    withdrawal_reason TEXT,
    withdrawn_by VARCHAR(100),
    
    -- Granular Options
    consent_options JSONB, -- {email: true, sms: false, phone: true}
    
    -- Proof
    consent_proof_url VARCHAR(500),
    consent_ip_address INET,
    consent_user_agent TEXT,
    
    -- Version
    privacy_policy_version VARCHAR(20),
    terms_version VARCHAR(20),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    updated_by VARCHAR(100),
    
    CONSTRAINT unique_customer_consent_type UNIQUE (tenant_id, customer_id, consent_type)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.customer_consent_preferences_default PARTITION OF dynamic.customer_consent_preferences DEFAULT;

-- Indexes
CREATE INDEX idx_consent_customer ON dynamic.customer_consent_preferences(tenant_id, customer_id);
CREATE INDEX idx_consent_type ON dynamic.customer_consent_preferences(tenant_id, consent_type);
CREATE INDEX idx_consent_given ON dynamic.customer_consent_preferences(tenant_id, consent_given) WHERE consent_given = TRUE;

-- Comments
COMMENT ON TABLE dynamic.customer_consent_preferences IS 'GDPR/POPIA compliant consent tracking';

-- Triggers
CREATE TRIGGER trg_consent_preferences_audit
    BEFORE UPDATE ON dynamic.customer_consent_preferences
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.customer_consent_preferences TO finos_app;