-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 34 - Customer Onboarding
-- TABLE: dynamic.digital_onboarding_sessions
--
-- DESCRIPTION:
--   Enterprise-grade digital onboarding session management.
--   Tracks e-KYC, biometric verification, video KYC journeys.
--   Supports multi-channel onboarding (mobile, web, branch-assisted).
--
-- COMPLIANCE: GDPR, POPIA, KYC/AML, FICA, FATF
-- ============================================================================


CREATE TABLE dynamic.digital_onboarding_sessions (
    session_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Session Tracking
    session_reference VARCHAR(100) NOT NULL, -- e.g., "ONB-2024-000001"
    onboarding_channel VARCHAR(50) NOT NULL 
        CHECK (onboarding_channel IN ('MOBILE_APP', 'WEB', 'BRANCH_ASSISTED', 'AGENT', 'USSD', 'WHATSAPP')),
    onboarding_type VARCHAR(50) NOT NULL 
        CHECK (onboarding_type IN ('INDIVIDUAL', 'BUSINESS', 'MINOR', 'FOREIGN_NATIONAL')),
    
    -- Customer Information (at time of onboarding)
    customer_id UUID REFERENCES core.customers(id), -- Set after completion
    prospect_id UUID, -- Pre-customer reference
    
    -- Personal Details
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    mobile_number VARCHAR(50),
    id_number VARCHAR(100),
    id_type VARCHAR(50), -- 'NATIONAL_ID', 'PASSPORT', 'DRIVERS_LICENSE'
    date_of_birth DATE,
    nationality CHAR(2),
    
    -- Business Details (if applicable)
    business_name VARCHAR(255),
    registration_number VARCHAR(100),
    business_type VARCHAR(50),
    
    -- Session Progress
    current_stage VARCHAR(50) DEFAULT 'INITIATED' 
        CHECK (current_stage IN ('INITIATED', 'IDENTITY_VERIFICATION', 'BIOMETRIC_CAPTURE', 'VIDEO_KYC', 'ADDRESS_VERIFICATION', 'PEP_SANCTIONS_CHECK', 'RISK_ASSESSMENT', 'PRODUCT_SELECTION', 'DOCUMENT_SIGNING', 'COMPLETED', 'ABANDONED', 'REJECTED')),
    stage_progress INTEGER DEFAULT 0, -- Percentage 0-100
    
    -- Verification Methods Used
    e_kyc_used BOOLEAN DEFAULT FALSE,
    biometric_capture_used BOOLEAN DEFAULT FALSE,
    video_kyc_used BOOLEAN DEFAULT FALSE,
    document_upload_used BOOLEAN DEFAULT FALSE,
    liveness_check_used BOOLEAN DEFAULT FALSE,
    
    -- Biometric Data References (actual data stored securely)
    face_biometric_reference VARCHAR(100),
    fingerprint_biometric_references VARCHAR(100)[],
    voice_biometric_reference VARCHAR(100),
    
    -- Video KYC Details
    video_kyc_session_id VARCHAR(100),
    video_kyc_agent_id UUID,
    video_kyc_start_time TIMESTAMPTZ,
    video_kyc_end_time TIMESTAMPTZ,
    video_kyc_recording_url TEXT,
    video_kyc_status VARCHAR(20),
    
    -- Verification Results
    identity_verification_status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (identity_verification_status IN ('PENDING', 'VERIFIED', 'FAILED', 'MANUAL_REVIEW')),
    identity_verification_score DECIMAL(5,4),
    identity_verification_provider VARCHAR(100),
    biometric_match_score DECIMAL(5,4),
    liveness_check_score DECIMAL(5,4),
    
    -- Risk Flags
    pep_status VARCHAR(20) DEFAULT 'NOT_CHECKED' 
        CHECK (pep_status IN ('NOT_CHECKED', 'CLEAR', 'MATCH', 'FALSE_POSITIVE')),
    sanctions_status VARCHAR(20) DEFAULT 'NOT_CHECKED',
    adverse_media_status VARCHAR(20) DEFAULT 'NOT_CHECKED',
    fraud_risk_score INTEGER, -- 0-100
    vulnerability_flagged BOOLEAN DEFAULT FALSE,
    vulnerability_reason TEXT,
    
    -- Session Timestamps
    session_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    session_completed_at TIMESTAMPTZ,
    session_expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
    last_activity_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Device & Location
    device_fingerprint VARCHAR(255),
    device_type VARCHAR(50),
    ip_address INET,
    geolocation_country CHAR(2),
    geolocation_city VARCHAR(100),
    
    -- Abandonment Tracking
    abandonment_stage VARCHAR(50),
    abandonment_reason TEXT,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_session_reference UNIQUE (tenant_id, session_reference)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.digital_onboarding_sessions_default PARTITION OF dynamic.digital_onboarding_sessions DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_onboarding_tenant ON dynamic.digital_onboarding_sessions(tenant_id);
CREATE INDEX idx_onboarding_customer ON dynamic.digital_onboarding_sessions(tenant_id, customer_id);
CREATE INDEX idx_onboarding_stage ON dynamic.digital_onboarding_sessions(tenant_id, current_stage);
CREATE INDEX idx_onboarding_status ON dynamic.digital_onboarding_sessions(tenant_id, identity_verification_status);
CREATE INDEX idx_onboarding_session_ref ON dynamic.digital_onboarding_sessions(tenant_id, session_reference);
CREATE INDEX idx_onboarding_started ON dynamic.digital_onboarding_sessions(tenant_id, session_started_at);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.digital_onboarding_sessions IS 'Digital onboarding sessions - e-KYC, biometric, video KYC tracking. Tier 2 - Customer Onboarding.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.digital_onboarding_sessions TO finos_app;
