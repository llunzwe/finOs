-- ================================================================================
-- FinOS Dynamic Layer - Tier 2: Config & Rules Engine
-- Component 44: Position & Portfolio Management
-- Table: position_reconciliation_config
-- Description: Position reconciliation rules - internal vs external (custodian, broker)
--              matching configuration and break management
-- Compliance: CSDR, Asset Servicing, Custody Reconciliation
-- ================================================================================

CREATE TABLE dynamic.position_reconciliation_config (
    -- Primary Identity
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Reconciliation Definition
    config_code VARCHAR(100) NOT NULL,
    config_name VARCHAR(200) NOT NULL,
    config_description TEXT,
    
    -- Reconciliation Type
    reconciliation_type VARCHAR(100) NOT NULL CHECK (reconciliation_type IN (
        'INTERNAL_EXTERNAL', 'CUSTODIAN', 'BROKER', 'SUB_CUSTODIAN',
        'TRADE_VERSUS_SETTLED', 'FRONT_BACK_OFFICE', 'SYSTEM_A_SYSTEM_B'
    )),
    
    -- Data Sources
    internal_source_system VARCHAR(100) NOT NULL,
    external_source_system VARCHAR(100) NOT NULL,
    external_source_type VARCHAR(50) CHECK (external_source_type IN ('CUSTODIAN', 'BROKER', 'CLEARING_HOUSE', 'VENDOR')),
    
    -- Matching Criteria
    match_criteria JSONB NOT NULL,
    -- Example:
    -- {
    --   "account_matching": "EXACT",
    --   "instrument_matching": "ISIN",
    --   "quantity_tolerance": 0,
    --   "date_matching": "SETTLEMENT_DATE"
    -- }
    
    -- Tolerance Settings
    quantity_tolerance_absolute DECIMAL(28,8) DEFAULT 0,
    quantity_tolerance_pct DECIMAL(5,4) DEFAULT 0,
    value_tolerance_absolute DECIMAL(28,8) DEFAULT 0,
    value_tolerance_pct DECIMAL(5,4) DEFAULT 0.0001, -- 1 basis point
    price_tolerance_pct DECIMAL(5,4) DEFAULT 0.001, -- 10 basis points
    
    -- Reconciliation Schedule
    frequency VARCHAR(50) DEFAULT 'DAILY' CHECK (frequency IN ('REAL_TIME', 'INTRADAY', 'DAILY', 'WEEKLY', 'MONTHLY')),
    scheduled_time TIME DEFAULT '06:00:00',
    timezone VARCHAR(50) DEFAULT 'UTC',
    business_day_only BOOLEAN DEFAULT TRUE,
    
    -- Scope
    account_filter JSONB, -- Array of account IDs or filter criteria
    instrument_filter JSONB, -- Instrument types, markets, etc.
    date_range_days INTEGER DEFAULT 1, -- How many days back to reconcile
    
    -- Break Management
    auto_match_minor_breaks BOOLEAN DEFAULT FALSE,
    minor_break_threshold DECIMAL(28,8),
    escalation_after_hours INTEGER DEFAULT 24,
    
    -- Notification
    notification_recipients JSONB, -- Array of email/alert recipients
    alert_on_break_percentage DECIMAL(5,2) DEFAULT 1.00, -- Alert if > 1% breaks
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    last_run_at TIMESTAMPTZ,
    last_run_status VARCHAR(50),
    last_run_break_count INTEGER,
    
    -- Audit Columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100) NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT unique_config_code_per_tenant UNIQUE (tenant_id, config_code)
) PARTITION BY LIST (tenant_id);

-- Default partition
CREATE TABLE dynamic.position_reconciliation_config_default PARTITION OF dynamic.position_reconciliation_config
    DEFAULT;

-- Indexes
CREATE INDEX idx_position_reconciliation_config_type ON dynamic.position_reconciliation_config (tenant_id, reconciliation_type);
CREATE INDEX idx_position_reconciliation_config_systems ON dynamic.position_reconciliation_config (tenant_id, internal_source_system, external_source_system);
CREATE INDEX idx_position_reconciliation_config_active ON dynamic.position_reconciliation_config (tenant_id)
    WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.position_reconciliation_config IS 'Position reconciliation configuration for internal vs external matching';
COMMENT ON COLUMN dynamic.position_reconciliation_config.match_criteria IS 'JSON configuration of fields to match and tolerances';

-- RLS
ALTER TABLE dynamic.position_reconciliation_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY position_reconciliation_config_tenant_isolation ON dynamic.position_reconciliation_config
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

-- Grants
GRANT SELECT, INSERT, UPDATE ON dynamic.position_reconciliation_config TO finos_app_user;
GRANT SELECT ON dynamic.position_reconciliation_config TO finos_readonly_user;
