-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 17 - Industry Packs Investments
-- TABLE: dynamic.order_execution_rules
-- COMPLIANCE: MiFID II
--   - UCITS
--   - ESG
--   - CISCA
-- ============================================================================


CREATE TABLE dynamic.order_execution_rules (

    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    rule_description TEXT,
    
    -- Applicability
    applicable_order_types VARCHAR(50)[], -- MARKET, LIMIT, STOP, STOP_LIMIT
    applicable_security_types VARCHAR(50)[], -- EQUITY, BOND, ETF, etc.
    applicable_exchanges VARCHAR(50)[],
    
    -- Execution Logic
    execution_venue VARCHAR(50) NOT NULL 
        CHECK (execution_venue IN ('EXCHANGE', 'DARK_POOL', 'INTERNAL_CROSS', 'MARKET_MAKER', 'RFQ', 'OTC')),
    venue_selection_logic JSONB, -- {primary: 'NYSE', fallback: ['NASDAQ', 'BATS']}
    
    -- Order Routing
    smart_routing_enabled BOOLEAN DEFAULT TRUE,
    routing_algorithm VARCHAR(50) DEFAULT 'BEST_EXECUTION', -- BEST_EXECUTION, TWAP, VWAP, IMPLEMENTATION_SHORTFALL
    
    -- Timing
    time_in_force_options VARCHAR(50)[], -- DAY, GTC, IOC, FOK, GTD
    default_time_in_force VARCHAR(20) DEFAULT 'DAY',
    
    -- Limits
    max_order_value DECIMAL(28,8),
    max_order_quantity INTEGER,
    max_orders_per_minute INTEGER,
    
    -- Price Protection
    price_protection_enabled BOOLEAN DEFAULT TRUE,
    max_price_deviation_percentage DECIMAL(10,6) DEFAULT 0.05,
    
    -- Block Trading
    block_trade_threshold DECIMAL(28,8),
    block_trade_handling VARCHAR(50), -- ROUTE_TO_DESK, SPLIT_ALGORITHM
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    priority INTEGER DEFAULT 0,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_order_execution_rule_code UNIQUE (tenant_id, rule_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.order_execution_rules_default PARTITION OF dynamic.order_execution_rules DEFAULT;

-- Indexes
CREATE INDEX idx_order_exec_rules_tenant ON dynamic.order_execution_rules(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_order_exec_rules_venue ON dynamic.order_execution_rules(tenant_id, execution_venue) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.order_execution_rules IS 'Order routing and execution rules for trading';

-- Triggers
CREATE TRIGGER trg_order_execution_rules_audit
    BEFORE UPDATE ON dynamic.order_execution_rules
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.order_execution_rules TO finos_app;