-- =============================================================================
-- FINOS CORE KERNEL - PRIMITIVE 4: ECONOMIC AGENT & RELATIONSHIPS
-- =============================================================================
-- Enterprise-Grade SQL Schema for PostgreSQL 16+
-- Features: KYC/AML, Sanctions Screening, Graph Relationships, PII Encryption
-- Standards: ISO 17442 (LEI), ISO 9362 (BIC), FATF Recommendations
-- =============================================================================

-- =============================================================================
-- ECONOMIC AGENTS (Party Master)
-- =============================================================================
CREATE TABLE core.economic_agents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Classification (6 Universal Types)
    type VARCHAR(50) NOT NULL 
        CHECK (type IN ('INDIVIDUAL', 'ORGANIZATION', 'DEVICE', 'GOVERNMENT', 'BOT', 'AGGREGATE')),
    
    -- Identity
    display_name VARCHAR(500) NOT NULL,
    legal_name VARCHAR(500),
    
    -- ISO 17442 LEI
    lei_code VARCHAR(20) CHECK (lei_code ~ '^[A-Z0-9]{18}[0-9]{2}$'),
    
    -- Identifiers (Flexible Storage)
    national_id VARCHAR(100),
    national_id_type VARCHAR(50) CHECK (national_id_type IN ('passport', 'national_id', 'drivers_license', 'residence_permit')),
    national_id_country CHAR(2) REFERENCES core.country_codes(iso_code),
    
    tax_id VARCHAR(100),
    tax_id_country CHAR(2),
    tax_id_encrypted BYTEA,
    
    -- Device/Bot Specific
    device_serial VARCHAR(100),
    api_key_fingerprint VARCHAR(64),
    device_metadata JSONB DEFAULT '{}',
    
    -- Risk & Compliance (Universal)
    risk_category VARCHAR(20) DEFAULT 'medium' 
        CHECK (risk_category IN ('low', 'medium', 'high', 'prohibited')),
    risk_score DECIMAL(5,2) CHECK (risk_score BETWEEN 0 AND 100),
    risk_assessed_at TIMESTAMPTZ,
    risk_assessed_by UUID,
    
    -- KYC Status
    kyc_status VARCHAR(20) DEFAULT 'pending' 
        CHECK (kyc_status IN ('pending', 'in_progress', 'verified', 'suspended', 'rejected', 'expired')),
    kyc_verified_at TIMESTAMPTZ,
    kyc_verified_by UUID,
    kyc_expiry_date DATE,
    kyc_level VARCHAR(20) DEFAULT 'basic' CHECK (kyc_level IN ('basic', 'standard', 'enhanced')),
    
    -- PEP (Politically Exposed Person)
    pep_status BOOLEAN DEFAULT FALSE,
    pep_details JSONB DEFAULT '{}',
    pep_screened_at TIMESTAMPTZ,
    
    -- Sanctions Screening
    sanctions_status VARCHAR(20) DEFAULT 'clear' 
        CHECK (sanctions_status IN ('clear', 'potential_match', 'confirmed_match', 'under_review')),
    sanctions_screened_at TIMESTAMPTZ,
    sanctions_match_details JSONB DEFAULT '{}',
    sanctions_lists TEXT[],
    
    -- FATF/Geographic Risk
    country_of_residence CHAR(2) REFERENCES core.country_codes(iso_code),
    country_of_citizenship CHAR(2) REFERENCES core.country_codes(iso_code),
    country_of_birth CHAR(2) REFERENCES core.country_codes(iso_code),
    jurisdiction_risk VARCHAR(20),
    
    -- Organization Specific
    incorporation_date DATE,
    incorporation_country CHAR(2) REFERENCES core.country_codes(iso_code),
    industry_code VARCHAR(10),
    industry_classification VARCHAR(20) DEFAULT 'ISIC' CHECK (industry_classification IN ('ISIC', 'NAICS', 'NACE')),
    company_size VARCHAR(20) CHECK (company_size IN ('micro', 'small', 'medium', 'large', 'enterprise')),
    annual_revenue DECIMAL(28,8),
    employee_count INTEGER,
    
    -- Temporal
    established_date DATE,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Metadata
    attributes JSONB NOT NULL DEFAULT '{}',
    tags TEXT[],
    
    -- PII/Encryption Markers
    pii_encrypted BOOLEAN DEFAULT FALSE,
    encryption_key_id VARCHAR(100),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 0,
    immutable_hash VARCHAR(64) NOT NULL DEFAULT 'pending',
    
    -- Correlation Tracking
    correlation_id UUID,
    causation_id UUID,
    
    -- Soft Delete
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    -- Constraints
    CONSTRAINT unique_agent_display_per_tenant UNIQUE (tenant_id, display_name, type),
    CONSTRAINT chk_agent_valid_dates CHECK (valid_from < valid_to),
    CONSTRAINT chk_lei_format CHECK (lei_code IS NULL OR lei_code ~ '^[A-Z0-9]{18}[0-9]{2}$')
) PARTITION BY LIST (tenant_id);

-- Create default partition
CREATE TABLE core.economic_agents_default PARTITION OF core.economic_agents DEFAULT;

-- Critical indexes (-3.2)
CREATE INDEX idx_agents_tenant_lookup ON core.economic_agents(tenant_id, display_name) WHERE is_deleted = FALSE;
CREATE INDEX idx_agents_type ON core.economic_agents(tenant_id, type) WHERE is_deleted = FALSE;
CREATE INDEX idx_agents_kyc ON core.economic_agents(kyc_status) WHERE kyc_status != 'verified' AND is_deleted = FALSE;
CREATE INDEX idx_agents_sanctions ON core.economic_agents(sanctions_status) 
    WHERE sanctions_status IN ('potential_match', 'confirmed_match') AND is_deleted = FALSE;
CREATE INDEX idx_agents_lei ON core.economic_agents(lei_code) WHERE lei_code IS NOT NULL;
CREATE INDEX idx_agents_national_id ON core.economic_agents(national_id, national_id_country) 
    WHERE national_id IS NOT NULL;
CREATE INDEX idx_agents_country ON core.economic_agents(country_of_residence);
CREATE INDEX idx_agents_temporal ON core.economic_agents(valid_from, valid_to) WHERE is_current = TRUE AND is_deleted = FALSE;
CREATE INDEX idx_agents_attributes ON core.economic_agents USING GIN(attributes);
CREATE INDEX idx_agents_correlation ON core.economic_agents(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_agents_active_composite ON core.economic_agents(tenant_id, type, valid_from, valid_to) 
    WHERE is_current = TRUE AND is_deleted = FALSE;

COMMENT ON TABLE core.economic_agents IS 'Universal economic agent registry with KYC/AML compliance';
COMMENT ON COLUMN core.economic_agents.tax_id_encrypted IS 'AES-256 encrypted tax identifier';

-- Trigger for audit updates
CREATE OR REPLACE FUNCTION core.update_agent_audit()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = OLD.version + 1;
    NEW.immutable_hash := encode(digest(
        NEW.id::text || NEW.display_name || NEW.type || NEW.kyc_status || NEW.sanctions_status || NEW.version::text,
        'sha256'
    ), 'hex');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_agents_audit
    BEFORE UPDATE ON core.economic_agents
    FOR EACH ROW EXECUTE FUNCTION core.update_agent_audit();

-- =============================================================================
-- AGENT IDENTIFIERS
-- =============================================================================
CREATE TABLE core.agent_identifiers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    agent_id UUID NOT NULL REFERENCES core.economic_agents(id) ON DELETE CASCADE,
    
    identifier_type VARCHAR(50) NOT NULL 
        CHECK (identifier_type IN ('national_id', 'passport', 'email', 'phone', 'lei', 'bic', 'tax_id', 
                                   'company_reg', 'vat_id', 'drivers_license', 'social_security')),
    identifier_value VARCHAR(255) NOT NULL,
    identifier_value_encrypted BYTEA,
    
    -- Verification
    verified BOOLEAN NOT NULL DEFAULT FALSE,
    verified_at TIMESTAMPTZ,
    verified_by UUID,
    verification_method VARCHAR(50),
    
    -- Temporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Soft Delete
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    CONSTRAINT unique_agent_identifier UNIQUE (agent_id, identifier_type, identifier_value)
);

CREATE INDEX idx_agent_ids_lookup ON core.agent_identifiers(identifier_type, identifier_value);
CREATE INDEX idx_agent_ids_agent ON core.agent_identifiers(agent_id, identifier_type);
CREATE INDEX idx_agent_ids_verified ON core.agent_identifiers(verified) WHERE verified = TRUE;
CREATE INDEX idx_agent_identifiers_correlation ON core.agent_identifiers(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core.agent_identifiers IS 'Multiple identifiers per agent with verification tracking';

-- =============================================================================
-- AGENT RELATIONSHIPS (Graph Edges)
-- =============================================================================
CREATE TABLE core.agent_relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Directed Graph
    from_agent_id UUID NOT NULL REFERENCES core.economic_agents(id),
    to_agent_id UUID NOT NULL REFERENCES core.economic_agents(id),
    
    -- 11 Universal Relationship Types
    type VARCHAR(50) NOT NULL 
        CHECK (type IN (
            'OWNERSHIP', 'CONTROL', 'EMPLOYMENT', 'REPRESENTATION', 'AGENCY',
            'GUARANTEE', 'BENEFICIARY', 'CUSTODY', 'GROUP_MEMBERSHIP', 'FAMILY', 'TRADE'
        )),
    
    -- Strength/Quantification
    ownership_percentage DECIMAL(5,2) CHECK (ownership_percentage BETWEEN 0 AND 100),
    control_percentage DECIMAL(5,2) CHECK (control_percentage BETWEEN 0 AND 100),
    voting_rights DECIMAL(5,2) CHECK (voting_rights BETWEEN 0 AND 100),
    guarantee_limit DECIMAL(28,8),
    
    -- Authority Scope (for REPRESENTATION/AGENCY)
    authority_scope JSONB DEFAULT '[]', -- ["sign_contracts", "operate_accounts"]
    authority_limit_amount DECIMAL(28,8),
    authority_limit_currency CHAR(3),
    
    -- Verification
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    verified_by UUID REFERENCES core.economic_agents(id),
    verified_at TIMESTAMPTZ,
    verification_evidence JSONB DEFAULT '{}',
    evidence_refs TEXT[],
    
    -- Temporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31 23:59:59+00'::timestamptz,
    system_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Metadata
    notes TEXT,
    attributes JSONB DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    
    -- Soft Delete
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    -- Constraints
    CONSTRAINT no_self_relationship CHECK (from_agent_id != to_agent_id),
    CONSTRAINT unique_relationship UNIQUE (from_agent_id, to_agent_id, type, valid_from)
);

-- Critical indexes for graph traversal
CREATE INDEX idx_rel_from ON core.agent_relationships(from_agent_id, type);
CREATE INDEX idx_rel_to ON core.agent_relationships(to_agent_id, type);
CREATE INDEX idx_rel_type ON core.agent_relationships(tenant_id, type) WHERE is_current = TRUE;
CREATE INDEX idx_rel_ownership ON core.agent_relationships(ownership_percentage) WHERE type = 'OWNERSHIP';
CREATE INDEX idx_rel_temporal ON core.agent_relationships(valid_from, valid_to) WHERE is_current = TRUE;
CREATE INDEX idx_rel_verified ON core.agent_relationships(is_verified) WHERE is_verified = TRUE;
CREATE INDEX idx_agent_relationships_correlation ON core.agent_relationships(correlation_id) WHERE correlation_id IS NOT NULL;

COMMENT ON TABLE core.agent_relationships IS 'Directed graph edges representing 11 universal relationship types';

-- Trigger to prevent circular ownership
CREATE OR REPLACE FUNCTION core.check_circular_ownership()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.type = 'OWNERSHIP' THEN
        IF NEW.from_agent_id = NEW.to_agent_id OR 
           EXISTS (SELECT 1 FROM core.agent_relationships 
                   WHERE from_agent_id = NEW.to_agent_id 
                   AND to_agent_id = NEW.from_agent_id 
                   AND type = 'OWNERSHIP'
                   AND is_current = TRUE) THEN
            RAISE EXCEPTION 'CIRCULAR_OWNERSHIP: Detected between agents % and %', NEW.from_agent_id, NEW.to_agent_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_circular_ownership
    BEFORE INSERT OR UPDATE ON core.agent_relationships
    FOR EACH ROW EXECUTE FUNCTION core.check_circular_ownership();

-- =============================================================================
-- AGENT RELATIONSHIP HISTORY
-- =============================================================================
CREATE TABLE core_history.agent_relationship_changes (
    time TIMESTAMPTZ NOT NULL,
    relationship_id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    
    from_agent_id UUID NOT NULL,
    to_agent_id UUID NOT NULL,
    type VARCHAR(50) NOT NULL,
    
    change_type VARCHAR(20) NOT NULL CHECK (change_type IN ('created', 'updated', 'expired', 'verified')),
    change_details JSONB,
    
    changed_by UUID,
    
    PRIMARY KEY (time, relationship_id)
);

SELECT create_hypertable('core_history.agent_relationship_changes', 'time', 
                         chunk_time_interval => INTERVAL '1 week',
                         if_not_exists => TRUE);

CREATE INDEX idx_rel_changes_agents ON core_history.agent_relationship_changes(from_agent_id, to_agent_id, time DESC);

-- =============================================================================
-- SANCTIONS SCREENING LOG
-- =============================================================================
CREATE TABLE core_audit.sanctions_screenings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    agent_id UUID NOT NULL REFERENCES core.economic_agents(id),
    
    screened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    screened_by VARCHAR(100),
    screening_service VARCHAR(50), -- 'dow_jones', 'refinitiv', 'manual'
    
    screen_type VARCHAR(20) NOT NULL CHECK (screen_type IN ('initial', 'periodic', 'triggered')),
    
    -- Results
    match_count INTEGER DEFAULT 0,
    matches JSONB DEFAULT '[]',
    overall_status VARCHAR(20) NOT NULL,
    
    -- False Positive Management
    false_positive BOOLEAN DEFAULT FALSE,
    false_positive_reason TEXT,
    reviewed_by UUID,
    reviewed_at TIMESTAMPTZ,
    
    -- Raw data hash for integrity
    raw_result_hash VARCHAR(64)
);

CREATE INDEX idx_sanctions_screening_agent ON core_audit.sanctions_screenings(agent_id, screened_at DESC);
CREATE INDEX idx_sanctions_screening_status ON core_audit.sanctions_screenings(overall_status) WHERE overall_status != 'clear';

-- =============================================================================
-- KYC VERIFICATION LOG
-- =============================================================================
CREATE TABLE core_audit.kyc_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    agent_id UUID NOT NULL REFERENCES core.economic_agents(id),
    
    verification_type VARCHAR(50) NOT NULL CHECK (verification_type IN ('identity', 'address', 'income', 'source_of_funds', 'pep')),
    verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    verified_by UUID,
    
    verification_method VARCHAR(50), -- 'document_upload', 'video_call', 'api_check', 'manual_review'
    verification_provider VARCHAR(100), -- 'jumio', 'onfido', 'trulioo'
    
    -- Documents referenced
    document_ids UUID[],
    
    -- Results
    result_status VARCHAR(20) NOT NULL,
    result_details JSONB,
    risk_factors JSONB,
    
    -- Expiry
    valid_until DATE,
    reminder_sent BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_kyc_verifications_agent ON core_audit.kyc_verifications(agent_id, verified_at DESC);
CREATE INDEX idx_kyc_verifications_expiry ON core_audit.kyc_verifications(valid_until) WHERE valid_until < CURRENT_DATE + INTERVAL '30 days';

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON core.economic_agents TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.agent_identifiers TO finos_app;
GRANT SELECT, INSERT, UPDATE ON core.agent_relationships TO finos_app;
GRANT SELECT, INSERT ON core_history.agent_relationship_changes TO finos_app;
GRANT SELECT, INSERT ON core_audit.sanctions_screenings TO finos_app;
GRANT SELECT, INSERT ON core_audit.kyc_verifications TO finos_app;
