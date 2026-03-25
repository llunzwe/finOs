-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 50: Data Governance & Privacy (GDPR Article 30)
-- Table: pii_data_classification
-- Description: PII data element classification with sensitivity levels,
--              masking rules, and handling requirements
-- Compliance: GDPR Article 30, PCI-DSS, Data Classification Standards
-- ================================================================================

CREATE TABLE dynamic.pii_data_classification (
    -- Primary Identity
    classification_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Data Element Identification
    data_element_name VARCHAR(200) NOT NULL,
    data_element_path VARCHAR(500) NOT NULL, -- Schema.table.column or JSON path
    data_element_description TEXT,
    
    -- Classification
    sensitivity_level VARCHAR(50) NOT NULL CHECK (sensitivity_level IN (
        'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED', 'CRITICAL'
    )),
    pii_category VARCHAR(100) NOT NULL CHECK (pii_category IN (
        'DIRECT_IDENTIFIER', 'QUASI_IDENTIFIER', 'SENSITIVE_PII', 'NON_PII'
    )),
    
    -- Specific PII Types
    pii_type VARCHAR(100) CHECK (pii_type IN (
        'NAME', 'ADDRESS', 'EMAIL', 'PHONE', 'SSN', 'TAX_ID', 'NATIONAL_ID',
        'PASSPORT', 'DRIVERS_LICENSE', 'DATE_OF_BIRTH', 'ACCOUNT_NUMBER',
        'CREDIT_CARD', 'BIOMETRIC', 'RACE_ETHNICITY', 'POLITICAL_OPINION',
        'RELIGION', 'HEALTH_DATA', 'SEXUAL_ORIENTATION', 'TRADE_UNION'
    )),
    
    -- Data Subject
    data_subject_type VARCHAR(50) CHECK (data_subject_type IN ('CUSTOMER', 'EMPLOYEE', 'VENDOR', 'THIRD_PARTY')),
    
    -- System Location
    source_system VARCHAR(100) NOT NULL,
    source_database VARCHAR(100),
    source_table VARCHAR(100),
    source_column VARCHAR(100),
    
    -- Masking Rules
    masking_required BOOLEAN DEFAULT TRUE,
    masking_rule VARCHAR(100) CHECK (masking_rule IN (
        'FULL_MASK', 'PARTIAL_MASK', 'HASH', 'TOKENIZE', 'ENCRYPT', 'REDACT', 'NONE'
    )),
    masking_pattern VARCHAR(255), -- e.g., "XXX-XX-{last4}" for SSN
    unmasking_authorized_roles JSONB, -- Roles that can see unmasked data
    
    -- Encryption
    encryption_required BOOLEAN DEFAULT FALSE,
    encryption_algorithm VARCHAR(50), -- AES-256, RSA, etc.
    encryption_key_rotation_days INTEGER DEFAULT 365,
    
    -- Access Controls
    access_control_required BOOLEAN DEFAULT TRUE,
    need_to_know_basis BOOLEAN DEFAULT TRUE,
    row_level_security_required BOOLEAN DEFAULT FALSE,
    
    -- Retention
    retention_period_days INTEGER,
    retention_basis VARCHAR(100), -- Legal, Contractual, Consent, etc.
    
    -- Legal Basis
    legal_basis_for_processing VARCHAR(100) CHECK (legal_basis_for_processing IN (
        'CONSENT', 'CONTRACT', 'LEGAL_OBLIGATION', 'VITAL_INTERESTS',
        'PUBLIC_TASK', 'LEGITIMATE_INTEREST', 'NOT_APPLICABLE'
    )),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    classified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    classified_by VARCHAR(100) NOT NULL,
    last_reviewed_at TIMESTAMPTZ,
    next_review_due DATE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_element_path_per_tenant UNIQUE (tenant_id, source_system, source_table, source_column),
    CONSTRAINT valid_retention CHECK (retention_period_days > 0 OR retention_period_days IS NULL)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE dynamic.pii_data_classification_default PARTITION OF dynamic.pii_data_classification
    DEFAULT;

-- Indexes
CREATE INDEX idx_pii_classification_sensitivity ON dynamic.pii_data_classification (tenant_id, sensitivity_level);
CREATE INDEX idx_pii_classification_type ON dynamic.pii_data_classification (tenant_id, pii_type);
CREATE INDEX idx_pii_classification_system ON dynamic.pii_data_classification (tenant_id, source_system, source_table);
CREATE INDEX idx_pii_classification_active ON dynamic.pii_data_classification (tenant_id)
    WHERE is_active = TRUE;
CREATE INDEX idx_pii_classification_review ON dynamic.pii_data_classification (tenant_id, next_review_due);

-- Comments
COMMENT ON TABLE dynamic.pii_data_classification IS 'PII data element classification with sensitivity levels and handling rules';
COMMENT ON COLUMN dynamic.pii_data_classification.sensitivity_level IS 'CRITICAL=special categories, RESTRICTED=PII, CONFIDENTIAL=sensitive business';
COMMENT ON COLUMN dynamic.pii_data_classification.masking_rule IS 'Method for masking data in non-production environments';

-- RLS
ALTER TABLE dynamic.pii_data_classification ENABLE ROW LEVEL SECURITY;
CREATE POLICY pii_data_classification_tenant_isolation ON dynamic.pii_data_classification
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.pii_data_classification TO finos_app_user;
GRANT SELECT ON dynamic.pii_data_classification TO finos_readonly_user;
