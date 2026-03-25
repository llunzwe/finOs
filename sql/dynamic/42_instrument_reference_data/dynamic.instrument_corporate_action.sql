-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 42: Instrument Reference Data Management
-- Table: instrument_corporate_action
-- Description: Corporate action lifecycle management - dividends, splits, mergers,
--              rights issues, spin-offs with entitlement calculation
-- Compliance: Corporate Actions Standards (ISO 15022), Tax Reporting
-- ================================================================================

CREATE TABLE dynamic.instrument_corporate_action (
    -- Primary Identity
    corporate_action_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Action Identification
    action_code VARCHAR(100) NOT NULL, -- Unique code per corporate action
    action_type VARCHAR(50) NOT NULL CHECK (action_type IN (
        'DIVIDEND_CASH', 'DIVIDEND_STOCK', 'STOCK_SPLIT', 'REVERSE_SPLIT',
        'RIGHTS_ISSUE', 'BONUS_ISSUE', 'MERGER', 'ACQUISITION', 'SPIN_OFF',
        'DELISTING', 'NAME_CHANGE', 'TICKER_CHANGE', 'LIQUIDATION',
        'REDEMPTION', 'CONVERSION', 'TENDER_OFFER', 'EXCHANGE_OFFER'
    )),
    action_sub_type VARCHAR(50),
    
    -- Instrument Reference
    instrument_id UUID NOT NULL REFERENCES dynamic.securities_master(security_id),
    
    -- Event Dates
    announcement_date DATE,
    ex_date DATE NOT NULL,
    record_date DATE NOT NULL,
    payment_date DATE,
    effective_date DATE NOT NULL,
    deadline_date DATE, -- For elections/tenders
    
    -- Action Details
    action_description TEXT NOT NULL,
    action_terms JSONB NOT NULL,
    -- Example: {"ratio": "2:1"} for splits, {"amount": 0.50, "currency": "USD"} for dividends
    
    -- Financial Impact
    gross_amount DECIMAL(28,8),
    net_amount DECIMAL(28,8),
    tax_rate DECIMAL(5,4),
    tax_amount DECIMAL(28,8),
    currency_code CHAR(3),
    
    -- Election Options (for optional actions)
    election_available BOOLEAN DEFAULT FALSE,
    election_options JSONB,
    default_election VARCHAR(50),
    
    -- Status
    action_status VARCHAR(50) DEFAULT 'ANNOUNCED' CHECK (action_status IN (
        'ANNOUNCED', 'PENDING', 'ACTIVE', 'COMPLETED', 'CANCELLED', 'LAPSED'
    )),
    
    -- Processing
    processing_status VARCHAR(50) DEFAULT 'PENDING' CHECK (processing_status IN (
        'PENDING', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'MANUAL_INTERVENTION'
    )),
    processed_at TIMESTAMPTZ,
    processed_positions_count INTEGER,
    
    -- Source
    data_source VARCHAR(100) NOT NULL,
    source_reference VARCHAR(255),
    
    -- Bitemporal
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_to TIMESTAMPTZ NOT NULL DEFAULT '9999-12-31',
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_action_code_per_tenant UNIQUE (tenant_id, action_code),
    CONSTRAINT valid_corporate_action_dates CHECK (valid_from < valid_to),
    CONSTRAINT valid_event_sequence CHECK (announcement_date <= ex_date AND ex_date <= record_date)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE dynamic.instrument_corporate_action_default PARTITION OF dynamic.instrument_corporate_action
    DEFAULT;

-- Indexes
CREATE INDEX idx_instrument_corporate_action_instrument ON dynamic.instrument_corporate_action (tenant_id, instrument_id, effective_date);
CREATE INDEX idx_instrument_corporate_action_type ON dynamic.instrument_corporate_action (tenant_id, action_type, action_status);
CREATE INDEX idx_instrument_corporate_action_dates ON dynamic.instrument_corporate_action (tenant_id, ex_date, record_date);
CREATE INDEX idx_instrument_corporate_action_status ON dynamic.instrument_corporate_action (tenant_id, processing_status);
CREATE INDEX idx_instrument_corporate_action_current ON dynamic.instrument_corporate_action (tenant_id, instrument_id) 
    WHERE is_current = TRUE;

-- Comments
COMMENT ON TABLE dynamic.instrument_corporate_action IS 'Corporate action lifecycle management - dividends, splits, mergers, rights issues';
COMMENT ON COLUMN dynamic.instrument_corporate_action.action_terms IS 'JSON structure defining action terms (ratios, amounts, etc.)';
COMMENT ON COLUMN dynamic.instrument_corporate_action.election_options IS 'Available election choices for optional corporate actions';

-- RLS
ALTER TABLE dynamic.instrument_corporate_action ENABLE ROW LEVEL SECURITY;
CREATE POLICY instrument_corporate_action_tenant_isolation ON dynamic.instrument_corporate_action
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.instrument_corporate_action TO finos_app_user;
GRANT SELECT ON dynamic.instrument_corporate_action TO finos_readonly_user;
