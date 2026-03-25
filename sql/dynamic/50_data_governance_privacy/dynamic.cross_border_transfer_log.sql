-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 50: Data Governance & Privacy (GDPR Article 30)
-- Table: cross_border_transfer_log
-- Description: Audit log of all cross-border data transfers with legal basis,
--              safeguards, and data subject notifications
-- Compliance: GDPR Article 30 Records of Processing, Schrems II Requirements
-- ================================================================================

CREATE TABLE dynamic.cross_border_transfer_log (
    -- Primary Identity
    transfer_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Transfer Identification
    transfer_reference VARCHAR(100) NOT NULL,
    transfer_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Data Details
    data_subject_count INTEGER NOT NULL,
    data_categories JSONB NOT NULL, -- ["PERSONAL_DATA", "FINANCIAL_DATA"]
    data_volume_gb DECIMAL(10,2),
    
    -- Origin
    origin_country CHAR(2) NOT NULL,
    origin_region VARCHAR(100),
    origin_system VARCHAR(100) NOT NULL,
    
    -- Destination
    destination_country CHAR(2) NOT NULL,
    destination_region VARCHAR(100),
    destination_system VARCHAR(100) NOT NULL,
    destination_organization VARCHAR(200),
    destination_legal_entity VARCHAR(200),
    
    -- Transfer Mechanism (Schrems II compliance)
    transfer_mechanism VARCHAR(100) NOT NULL CHECK (transfer_mechanism IN (
        'ADEQUACY_DECISION', 'SCC_EU_CONTROLLER', 'SCC_EU_PROCESSOR',
        'SCC_UK_CONTROLLER', 'SCC_UK_PROCESSOR', 'BCR_GROUP', 'BCR_PROCESSOR',
        'CERTIFICATION_CODE', 'CFR', 'DEROGATION_EXPLICIT_CONSENT',
        'DEROGATION_CONTRACT', 'DEROGATION_VITAL_INTERESTS', 'DEROGATION_PUBLIC_INTEREST',
        'DEROGATION_LEGAL_CLAIM', 'DEROGATION_IMPORTANT_PUBLIC_INTEREST'
    )),
    
    -- Transfer Impact Assessment (TIA)
    transfer_impact_assessment_completed BOOLEAN DEFAULT FALSE,
    tia_completion_date DATE,
    tia_document_reference VARCHAR(255),
    supplementary_measures_required BOOLEAN DEFAULT FALSE,
    supplementary_measures JSONB, -- ["ENCRYPTION_IN_TRANSIT", "ENCRYPTION_AT_REST", "PSEUDONYMIZATION"]
    
    -- Legal Basis
    legal_basis VARCHAR(100) NOT NULL,
    consent_obtained BOOLEAN DEFAULT FALSE,
    consent_reference VARCHAR(100),
    data_processing_agreement_ref VARCHAR(100),
    
    -- Safeguards
    encryption_used BOOLEAN DEFAULT FALSE,
    encryption_method VARCHAR(100),
    pseudonymization_used BOOLEAN DEFAULT FALSE,
    additional_safeguards JSONB,
    
    -- Data Subject Rights
    data_subjects_notified BOOLEAN DEFAULT FALSE,
    notification_method VARCHAR(100),
    notification_timestamp TIMESTAMPTZ,
    
    -- Regulatory
    supervisory_authority_notified BOOLEAN DEFAULT FALSE,
    supervisory_authority_country CHAR(2),
    notification_reference VARCHAR(100),
    
    -- Status
    transfer_status VARCHAR(50) DEFAULT 'COMPLETED' CHECK (transfer_status IN (
        'PENDING', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'BLOCKED', 'CANCELLED'
    )),
    
    -- Review
    review_required BOOLEAN DEFAULT FALSE,
    review_due_date DATE,
    reviewed_at TIMESTAMPTZ,
    reviewed_by VARCHAR(100),
    review_notes TEXT,
    
    -- Partitioning
    partition_key DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_transfer_ref_per_tenant UNIQUE (tenant_id, transfer_reference)
) PARTITION BY RANGE (partition_key);

-- Default partition
CREATE TABLE dynamic.cross_border_transfer_log_default PARTITION OF dynamic.cross_border_transfer_log
    DEFAULT;

-- Monthly partitions
CREATE TABLE dynamic.cross_border_transfer_log_2025_01 PARTITION OF dynamic.cross_border_transfer_log
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.cross_border_transfer_log_2025_02 PARTITION OF dynamic.cross_border_transfer_log
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Indexes
CREATE INDEX idx_cross_border_transfer_date ON dynamic.cross_border_transfer_log (tenant_id, transfer_timestamp);
CREATE INDEX idx_cross_border_transfer_origin ON dynamic.cross_border_transfer_log (tenant_id, origin_country);
CREATE INDEX idx_cross_border_transfer_dest ON dynamic.cross_border_transfer_log (tenant_id, destination_country);
CREATE INDEX idx_cross_border_transfer_mechanism ON dynamic.cross_border_transfer_log (tenant_id, transfer_mechanism);
CREATE INDEX idx_cross_border_transfer_status ON dynamic.cross_border_transfer_log (tenant_id, transfer_status);
CREATE INDEX idx_cross_border_transfer_review ON dynamic.cross_border_transfer_log (tenant_id, review_required) WHERE review_required = TRUE;

-- Comments
COMMENT ON TABLE dynamic.cross_border_transfer_log IS 'Audit log of cross-border data transfers per GDPR Article 30';
COMMENT ON COLUMN dynamic.cross_border_transfer_log.transfer_impact_assessment_completed IS 'Transfer Impact Assessment per Schrems II requirements';
COMMENT ON COLUMN dynamic.cross_border_transfer_log.supplementary_measures_required IS 'Additional safeguards required post-Schrems II';

-- RLS
ALTER TABLE dynamic.cross_border_transfer_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY cross_border_transfer_log_tenant_isolation ON dynamic.cross_border_transfer_log
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.cross_border_transfer_log TO finos_app_user;
GRANT SELECT ON dynamic.cross_border_transfer_log TO finos_readonly_user;
