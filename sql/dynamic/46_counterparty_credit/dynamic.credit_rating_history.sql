-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 46: Counterparty & Credit Management
-- Table: credit_rating_history
-- Description: Historical credit ratings from S&P, Moody's, Fitch with effective
--              dates and watch/outlook status for credit migration tracking
-- Compliance: Basel III (Standardized Approach), Credit Risk Management
-- ================================================================================

CREATE TABLE dynamic.credit_rating_history (
    -- Primary Identity
    rating_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Counterparty Reference
    counterparty_id UUID NOT NULL REFERENCES dynamic.counterparty_master(counterparty_id),
    
    -- Rating Agency
    rating_agency VARCHAR(50) NOT NULL CHECK (rating_agency IN ('S_P', 'MOODYS', 'FITCH', 'DBRS', 'EJR', 'INTERNAL')),
    
    -- Credit Rating
    credit_rating VARCHAR(20) NOT NULL,
    -- S&P: AAA, AA+, AA, AA-, A+, A, A-, BBB+, BBB, BBB-, BB+, etc.
    -- Moody's: Aaa, Aa1, Aa2, Aa3, A1, A2, A3, Baa1, etc.
    
    -- Rating Category (Standardized for Basel)
    rating_category VARCHAR(50) CHECK (rating_category IN (
        'AAA', 'AA', 'A', 'BBB', 'BB', 'B', 'CCC', 'CC', 'C', 'D', 'NR', 'UNRATED'
    )),
    
    -- Outlook/Watch
    rating_outlook VARCHAR(20) CHECK (rating_outlook IN ('STABLE', 'POSITIVE', 'NEGATIVE', 'DEVELOPING')),
    rating_watch VARCHAR(50) CHECK (rating_watch IN ('UPGRADE', 'DOWNGRADE', 'EVOLVING', 'NONE')),
    
    -- Rating Type
    rating_type VARCHAR(50) DEFAULT 'LONG_TERM_ISSUER' CHECK (rating_type IN (
        'LONG_TERM_ISSUER', 'SHORT_TERM_ISSUER', 'LONG_TERM_ISSUE', 'SHORT_TERM_ISSUE',
        'SENIOR_DEBT', 'SUBORDINATED_DEBT', 'LOCAL_CURRENCY', 'FOREIGN_CURRENCY'
    )),
    
    -- Effective Period
    effective_date DATE NOT NULL,
    expiry_date DATE DEFAULT '9999-12-31',
    is_current_rating BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Rating Details
    rating_action VARCHAR(50) CHECK (rating_action IN ('INITIAL', 'UPGRADE', 'DOWNGRADE', 'AFFIRMED', 'WITHDRAWN')),
    previous_rating VARCHAR(20),
    notches_changed INTEGER, -- Positive for upgrade, negative for downgrade
    
    -- Issuer/Issue Reference
    rated_entity_name VARCHAR(500),
    isin VARCHAR(12), -- If issue-specific rating
    
    -- Source
    rating_report_reference VARCHAR(255),
    rating_report_date DATE,
    rating_analyst VARCHAR(200),
    
    -- Internal Mapping
    internal_rating_grade VARCHAR(20), -- Internal rating system mapping
    pd_implied DECIMAL(8,6), -- Implied probability of default
    lgd_implied DECIMAL(5,4), -- Implied loss given default
    
    -- Partitioning
    partition_key DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT valid_rating_dates CHECK (effective_date <= expiry_date)
) PARTITION BY RANGE (partition_key);

-- Default partition
CREATE TABLE dynamic.credit_rating_history_default PARTITION OF dynamic.credit_rating_history
    DEFAULT;

-- Monthly partitions
CREATE TABLE dynamic.credit_rating_history_2025_01 PARTITION OF dynamic.credit_rating_history
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE dynamic.credit_rating_history_2025_02 PARTITION OF dynamic.credit_rating_history
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Indexes
CREATE INDEX idx_credit_rating_counterparty ON dynamic.credit_rating_history (tenant_id, counterparty_id);
CREATE INDEX idx_credit_rating_agency ON dynamic.credit_rating_history (tenant_id, rating_agency, effective_date DESC);
CREATE INDEX idx_credit_rating_current ON dynamic.credit_rating_history (tenant_id, counterparty_id, rating_agency, rating_type) 
    WHERE is_current_rating = TRUE;
CREATE INDEX idx_credit_rating_category ON dynamic.credit_rating_history (tenant_id, rating_category);
CREATE INDEX idx_credit_rating_action ON dynamic.credit_rating_history (tenant_id, rating_action);

-- Comments
COMMENT ON TABLE dynamic.credit_rating_history IS 'Historical credit ratings from major agencies with migration tracking';
COMMENT ON COLUMN dynamic.credit_rating_history.rating_category IS 'Standardized rating category for Basel capital calculations';
COMMENT ON COLUMN dynamic.credit_rating_history.pd_implied IS 'Probability of default implied by the rating';

-- RLS
ALTER TABLE dynamic.credit_rating_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY credit_rating_history_tenant_isolation ON dynamic.credit_rating_history
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.credit_rating_history TO finos_app_user;
GRANT SELECT ON dynamic.credit_rating_history TO finos_readonly_user;
