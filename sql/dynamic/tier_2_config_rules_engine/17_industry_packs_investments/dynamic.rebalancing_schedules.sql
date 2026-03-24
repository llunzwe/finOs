-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 17 - Industry Packs Investments
-- TABLE: dynamic.rebalancing_schedules
-- COMPLIANCE: MiFID II
--   - UCITS
--   - ESG
--   - CISCA
-- ============================================================================


CREATE TABLE dynamic.rebalancing_schedules (

    schedule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    schedule_code VARCHAR(100) NOT NULL,
    schedule_name VARCHAR(200) NOT NULL,
    schedule_description TEXT,
    
    -- Portfolio/Model Link
    model_id UUID REFERENCES dynamic.portfolio_models(model_id),
    applies_to_all_models BOOLEAN DEFAULT FALSE,
    
    -- Schedule Type
    schedule_type VARCHAR(50) NOT NULL 
        CHECK (schedule_type IN ('CALENDAR', 'THRESHOLD', 'CASH_FLOW', 'TACTICAL')),
    
    -- Calendar Schedule
    rebalancing_frequency VARCHAR(20), -- MONTHLY, QUARTERLY, ANNUAL
    rebalancing_day INTEGER, -- Day of month or quarter
    
    -- Threshold Schedule
    drift_threshold_percentage DECIMAL(10,6), -- Rebalance when allocation deviates by X%
    
    -- Cash Flow Schedule
    cash_flow_trigger BOOLEAN DEFAULT FALSE,
    min_cash_flow_amount DECIMAL(28,8),
    
    -- Execution
    execution_strategy VARCHAR(50) DEFAULT 'PROPORTIONAL', -- PROPORTIONAL, TAX_EFFICIENT, RISK_MINIMIZING
    transaction_cost_optimization BOOLEAN DEFAULT TRUE,
    
    -- Constraints
    constraints JSONB, -- {min_trade_size: 1000, max_turnover: 0.20, ...}
    tax_awareness BOOLEAN DEFAULT FALSE,
    
    -- Notification
    notification_recipients TEXT[],
    pre_rebalance_notification_days INTEGER DEFAULT 1,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    next_rebalance_date DATE,
    last_rebalance_date DATE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_rebalancing_schedule_code UNIQUE (tenant_id, schedule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.rebalancing_schedules_default PARTITION OF dynamic.rebalancing_schedules DEFAULT;

-- Indexes
CREATE INDEX idx_rebalancing_schedules_tenant ON dynamic.rebalancing_schedules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_rebalancing_schedules_model ON dynamic.rebalancing_schedules(tenant_id, model_id) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.rebalancing_schedules IS 'Portfolio rebalancing schedules and thresholds';

-- Triggers
CREATE TRIGGER trg_rebalancing_schedules_audit
    BEFORE UPDATE ON dynamic.rebalancing_schedules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.rebalancing_schedules TO finos_app;