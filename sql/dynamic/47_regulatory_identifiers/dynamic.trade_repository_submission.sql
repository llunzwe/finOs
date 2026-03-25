-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 47: Regulatory Identifiers
-- Table: trade_repository_submission
-- Description: Trade repository and ARM submission tracking with rejection handling
--              and resubmission workflows
-- Compliance: EMIR, MiFID II, CFTC, SFTR
-- ================================================================================

CREATE TABLE dynamic.trade_repository_submission (
    -- Primary Identity
    submission_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identifier Reference
    uti VARCHAR(100) NOT NULL,
    identifier_id UUID REFERENCES dynamic.uti_upi_registry(identifier_id),
    
    -- Submission Details
    submission_type VARCHAR(50) NOT NULL CHECK (submission_type IN (
        'REAL_TIME', 'TPLUS1', 'END_OF_DAY', 'INTRADAY', 'BACKLOADING'
    )),
    submission_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Reporting Venue
    reporting_venue VARCHAR(100) NOT NULL, -- DTCC, RegisTR, KDPW, etc.
    reporting_venue_endpoint VARCHAR(255),
    
    -- Submission Content
    message_type VARCHAR(50) NOT NULL CHECK (message_type IN (
        'TRADE_REPORT', 'POSITION_REPORT', 'VALUATION_REPORT', 'MARGIN_REPORT', 'COLLATERAL_REPORT'
    )),
    message_format VARCHAR(50) DEFAULT 'ISO20022', -- ISO20022, FIX, FpML
    message_payload JSONB NOT NULL, -- Full submission payload
    message_hash VARCHAR(64), -- SHA-256 of payload for integrity
    
    -- Processing Status
    submission_status VARCHAR(50) DEFAULT 'SUBMITTED' CHECK (submission_status IN (
        'SUBMITTED', 'ACKNOWLEDGED', 'ACCEPTED', 'REJECTED', 'PENDING_VALIDATION', 'CANCELLED'
    )),
    
    -- Response from TR
    venue_response_timestamp TIMESTAMPTZ,
    venue_reference VARCHAR(100),
    venue_status_code VARCHAR(50),
    venue_status_message TEXT,
    
    -- Rejection Handling
    rejected BOOLEAN DEFAULT FALSE,
    rejection_code VARCHAR(50),
    rejection_reason TEXT,
    rejection_category VARCHAR(50) CHECK (rejection_category IN (
        'SCHEMA_VALIDATION', 'BUSINESS_RULE', 'REFERENCE_DATA', 'DUPLICATE', 'AUTHORIZATION', 'TECHNICAL'
    )),
    
    -- Resubmission
    resubmission_count INTEGER DEFAULT 0,
    resubmission_of UUID REFERENCES dynamic.trade_repository_submission(submission_id),
    resubmission_reason TEXT,
    resubmitted_at TIMESTAMPTZ,
    
    -- Manual Intervention
    manual_intervention_required BOOLEAN DEFAULT FALSE,
    manual_intervention_notes TEXT,
    manually_processed_by VARCHAR(100),
    manually_processed_at TIMESTAMPTZ,
    
    -- Partitioning
    partition_key DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY RANGE (partition_key);

-- Default partition
CREATE TABLE dynamic.trade_repository_submission_default PARTITION OF dynamic.trade_repository_submission
    DEFAULT;

-- Monthly partitions
CREATE TABLE dynamic.trade_repository_submission_2025_01 PARTITION OF dynamic.trade_repository_submission
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.trade_repository_submission_2025_02 PARTITION OF dynamic.trade_repository_submission
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Indexes
CREATE INDEX idx_trade_repo_submission_uti ON dynamic.trade_repository_submission (tenant_id, uti);
CREATE INDEX idx_trade_repo_submission_status ON dynamic.trade_repository_submission (tenant_id, submission_status);
CREATE INDEX idx_trade_repo_submission_rejected ON dynamic.trade_repository_submission (tenant_id, rejected) WHERE rejected = TRUE;
CREATE INDEX idx_trade_repo_submission_venue ON dynamic.trade_repository_submission (tenant_id, reporting_venue);
CREATE INDEX idx_trade_repo_submission_manual ON dynamic.trade_repository_submission (tenant_id, manual_intervention_required) WHERE manual_intervention_required = TRUE;

-- Comments
COMMENT ON TABLE dynamic.trade_repository_submission IS 'Trade repository submission tracking with rejection and resubmission workflows';
COMMENT ON COLUMN dynamic.trade_repository_submission.message_hash IS 'SHA-256 hash of message payload for integrity verification';

-- RLS
ALTER TABLE dynamic.trade_repository_submission ENABLE ROW LEVEL SECURITY;
CREATE POLICY trade_repository_submission_tenant_isolation ON dynamic.trade_repository_submission
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.trade_repository_submission TO finos_app_user;
GRANT SELECT ON dynamic.trade_repository_submission TO finos_readonly_user;
