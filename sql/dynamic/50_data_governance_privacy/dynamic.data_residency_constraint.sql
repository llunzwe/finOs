-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 50: Data Governance & Privacy (GDPR Article 30)
-- Table: data_residency_constraint
-- Description: Data residency requirements and cross-border transfer controls
--              per GDPR Article 30 and global privacy regulations
-- Compliance: GDPR Article 30, CCPA, LGPD, POPIA, Data Sovereignty Laws
-- ================================================================================

CREATE TABLE dynamic.data_residency_constraint (
    -- Primary Identity
    constraint_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Constraint Definition
    constraint_code VARCHAR(100) NOT NULL,
    constraint_name VARCHAR(200) NOT NULL,
    constraint_description TEXT,
    
    -- Applicability
    data_subject_type VARCHAR(100) NOT NULL CHECK (data_subject_type IN (
        'EU_RESIDENT', 'UK_RESIDENT', 'US_CITIZEN', 'US_RESIDENT', 'BRAZIL_RESIDENT',
        'SOUTH_AFRICA_RESIDENT', 'CHINA_CITIZEN', 'RUSSIA_CITIZEN', 'GENERAL'
    )),
    data_category VARCHAR(100) NOT NULL CHECK (data_category IN (
        'PERSONAL_DATA', 'FINANCIAL_DATA', 'TRANSACTION_DATA', 'BIOMETRIC_DATA',
        'HEALTH_DATA', 'CHILDREN_DATA', 'SENSITIVE_DATA', 'CRIMINAL_DATA', 'ALL_DATA'
    )),
    
    -- Geographic Constraints
    required_residency_country CHAR(2) NOT NULL, -- ISO country code where data must be stored
    required_residency_region VARCHAR(100), -- e.g., "EU", "EEA", "US", "APAC"
    
    -- Cross-Border Transfer Rules
    cross_border_transfer_allowed BOOLEAN DEFAULT FALSE,
    transfer_mechanism VARCHAR(100) CHECK (transfer_mechanism IN (
        'ADEQUACY_DECISION', 'SCC', 'BCR', 'CERTIFICATION', 'CFR', 'DEROGATION', 'NOT_ALLOWED'
    )),
    -- SCC: Standard Contractual Clauses
    -- BCR: Binding Corporate Rules
    -- CFR: Code of Conduct/ Certification
    
    -- Transfer Conditions
    transfer_conditions JSONB, -- Additional conditions for transfer
    -- Example: {"encryption_required": true, "pseudonymization": true, "dpia_required": true}
    
    -- Prohibited Destinations
    prohibited_countries JSONB, -- ["CN", "RU"] - Countries where transfer is prohibited
    prohibited_recipients JSONB, -- ["CLOUD_PROVIDER_X", "THIRD_PARTY_Y"]
    
    -- Data Processing Constraints
    processing_location_restriction VARCHAR(50) CHECK (processing_location_restriction IN (
        'STORAGE_ONLY', 'PROCESSING_ALLOWED', 'SPECIFIC_REGIONS_ONLY'
    )),
    allowed_processing_regions JSONB, -- ["EU", "UK", "US-EAST"]
    
    -- Retention Constraints
    max_retention_days INTEGER,
    retention_country_specific BOOLEAN DEFAULT FALSE,
    
    -- Audit Requirements
    audit_log_required BOOLEAN DEFAULT TRUE,
    audit_retention_years INTEGER DEFAULT 7,
    
    -- Enforcement
    enforcement_level VARCHAR(50) DEFAULT 'HARD' CHECK (enforcement_level IN ('HARD', 'SOFT', 'WARNING')),
    -- HARD: Block transfer; SOFT: Log warning; WARNING: Alert only
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE NOT NULL DEFAULT '9999-12-31',
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_constraint_code_per_tenant UNIQUE (tenant_id, constraint_code),
    CONSTRAINT valid_residency_dates CHECK (effective_from < effective_to)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE dynamic.data_residency_constraint_default PARTITION OF dynamic.data_residency_constraint
    DEFAULT;

-- Indexes
CREATE UNIQUE INDEX idx_data_residency_active ON dynamic.data_residency_constraint (tenant_id, constraint_code)
    WHERE is_active = TRUE AND effective_to = '9999-12-31';
CREATE INDEX idx_data_residency_subject ON dynamic.data_residency_constraint (tenant_id, data_subject_type);
CREATE INDEX idx_data_residency_country ON dynamic.data_residency_constraint (tenant_id, required_residency_country);
CREATE INDEX idx_data_residency_transfer ON dynamic.data_residency_constraint (tenant_id, cross_border_transfer_allowed);

-- Comments
COMMENT ON TABLE dynamic.data_residency_constraint IS 'Data residency requirements per GDPR Article 30 and global privacy regulations';
COMMENT ON COLUMN dynamic.data_residency_constraint.transfer_mechanism IS 'SCC=Standard Contractual Clauses, BCR=Binding Corporate Rules';
COMMENT ON COLUMN dynamic.data_residency_constraint.enforcement_level IS 'HARD=block transfer, SOFT=log warning, WARNING=alert only';

-- RLS
ALTER TABLE dynamic.data_residency_constraint ENABLE ROW LEVEL SECURITY;
CREATE POLICY data_residency_constraint_tenant_isolation ON dynamic.data_residency_constraint
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.data_residency_constraint TO finos_app_user;
GRANT SELECT ON dynamic.data_residency_constraint TO finos_readonly_user;
