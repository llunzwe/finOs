-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 45: Settlement Fails Management (CSDR)
-- Table: csd_penalty_reporting
-- Description: CSDR penalty calculation and reporting to CSDs and regulators
--              Settlement discipline reporting
-- Compliance: CSDR (EU) 909/2014, ESMA Settlement Discipline Guidelines
-- ================================================================================

CREATE TABLE dynamic.csd_penalty_reporting (
    -- Primary Identity
    penalty_report_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- References
    fail_id UUID NOT NULL REFERENCES dynamic.settlement_fails_management(fail_id),
    settlement_location VARCHAR(100) NOT NULL,
    
    -- Reporting Period
    reporting_month INTEGER NOT NULL CHECK (reporting_month >= 1 AND reporting_month <= 12),
    reporting_year INTEGER NOT NULL,
    
    -- Penalty Details
    penalty_type VARCHAR(50) NOT NULL CHECK (penalty_type IN ('CASH', 'SECURITIES', 'BUY_IN_COST')),
    penalty_category VARCHAR(50) CHECK (penalty_category IN (
        'SETTLEMENT_FAIL', 'DELIVERY_FAIL', 'RECEIPT_FAIL', 'DOCUMENTATION_FAIL'
    )),
    
    -- Calculation Basis
    reference_date DATE NOT NULL,
    calculation_basis_value DECIMAL(28,8) NOT NULL,
    calculation_basis_currency CHAR(3) NOT NULL,
    penalty_rate_bps DECIMAL(5,2) NOT NULL,
    days_overdue INTEGER NOT NULL,
    
    -- Amounts
    penalty_amount_calculated DECIMAL(28,8) NOT NULL,
    penalty_amount_settled DECIMAL(28,8),
    settlement_currency CHAR(3),
    exchange_rate_applied DECIMAL(18,8),
    
    -- Parties
    penalized_party_id UUID NOT NULL REFERENCES dynamic.counterparty_master(counterparty_id),
    penalized_party_lei VARCHAR(20),
    beneficiary_party_id UUID REFERENCES dynamic.counterparty_master(counterparty_id),
    beneficiary_party_lei VARCHAR(20),
    
    -- Reporting Status
    report_generated BOOLEAN DEFAULT FALSE,
    report_generated_at TIMESTAMPTZ,
    submitted_to_csd BOOLEAN DEFAULT FALSE,
    submitted_to_csd_at TIMESTAMPTZ,
    csd_reference VARCHAR(100),
    
    -- Settlement
    penalty_settled BOOLEAN DEFAULT FALSE,
    settled_at TIMESTAMPTZ,
    settlement_reference VARCHAR(100),
    
    -- Dispute
    disputed BOOLEAN DEFAULT FALSE,
    dispute_reason TEXT,
    dispute_submitted_at TIMESTAMPTZ,
    dispute_resolved_at TIMESTAMPTZ,
    dispute_resolution TEXT,
    
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
CREATE TABLE dynamic.csd_penalty_reporting_default PARTITION OF dynamic.csd_penalty_reporting
    DEFAULT;

-- Monthly partitions
CREATE TABLE dynamic.csd_penalty_reporting_2025_01 PARTITION OF dynamic.csd_penalty_reporting
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.csd_penalty_reporting_2025_02 PARTITION OF dynamic.csd_penalty_reporting
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Indexes
CREATE INDEX idx_csd_penalty_fail ON dynamic.csd_penalty_reporting (tenant_id, fail_id);
CREATE INDEX idx_csd_penalty_location ON dynamic.csd_penalty_reporting (tenant_id, settlement_location, reporting_year, reporting_month);
CREATE INDEX idx_csd_penalty_penalized ON dynamic.csd_penalty_reporting (tenant_id, penalized_party_id);
CREATE INDEX idx_csd_penalty_submitted ON dynamic.csd_penalty_reporting (tenant_id, submitted_to_csd) WHERE submitted_to_csd = FALSE;
CREATE INDEX idx_csd_penalty_settled ON dynamic.csd_penalty_reporting (tenant_id, penalty_settled) WHERE penalty_settled = FALSE;

-- Comments
COMMENT ON TABLE dynamic.csd_penalty_reporting IS 'CSDR penalty calculation and reporting to Central Securities Depositories';
COMMENT ON COLUMN dynamic.csd_penalty_reporting.penalty_rate_bps IS 'Penalty rate applied in basis points (varies by instrument and delay)';

-- RLS
ALTER TABLE dynamic.csd_penalty_reporting ENABLE ROW LEVEL SECURITY;
CREATE POLICY csd_penalty_reporting_tenant_isolation ON dynamic.csd_penalty_reporting
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.csd_penalty_reporting TO finos_app_user;
GRANT SELECT ON dynamic.csd_penalty_reporting TO finos_readonly_user;
