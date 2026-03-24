-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 28 - Treasury & Liquidity Management
-- TABLE: dynamic.fx_trading_rules
--
-- DESCRIPTION:
--   Enterprise-grade FX trading and hedging rule configuration.
--   Spot, forward, swap, and option trading parameters.
--   Supports IFRS 9 hedge accounting, bitemporal tracking.
--
-- COMPLIANCE: IFRS 9, Basel III/IV, FX Regulations, Market Risk
-- ============================================================================


CREATE TABLE dynamic.fx_trading_rules (
    rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Rule Identification
    rule_code VARCHAR(100) NOT NULL,
    rule_name VARCHAR(200) NOT NULL,
    
    -- Trading Parameters
    instrument_type VARCHAR(50) NOT NULL 
        CHECK (instrument_type IN ('SPOT', 'FORWARD', 'SWAP', 'OPTION', 'FUTURE')),
    base_currency CHAR(3) NOT NULL,
    quote_currency CHAR(3) NOT NULL,
    currency_pair VARCHAR(7) GENERATED ALWAYS AS (base_currency || '/' || quote_currency) STORED,
    
    -- Pricing
    pricing_source VARCHAR(100), -- 'REUTERS', 'BLOOMBERG', 'INTERNAL'
    spread_basis_points INTEGER DEFAULT 50, -- 0.5%
    minimum_amount DECIMAL(28,8),
    maximum_amount DECIMAL(28,8),
    
    -- Tenor Configuration
    standard_tenors VARCHAR(20)[] DEFAULT ARRAY['ON', '1W', '1M', '3M', '6M', '1Y'],
    custom_tenor_allowed BOOLEAN DEFAULT FALSE,
    maximum_tenor_days INTEGER DEFAULT 365,
    
    -- Hedge Accounting (IFRS 9)
    hedge_accounting_enabled BOOLEAN DEFAULT FALSE,
    hedge_effectiveness_test VARCHAR(50), -- 'DOLLAR_OFFSET', 'REGRESSION', 'CRITICAL_TERMS'
    hedged_risk_type VARCHAR(50), -- 'FX_RISK', 'CASH_FLOW', 'FAIR_VALUE'
    
    -- Risk Limits
    position_limit_base DECIMAL(28,8),
    position_limit_quote DECIMAL(28,8),
    daily_var_limit DECIMAL(28,8),
    
    -- Cut-off Times
    spot_cutoff_time TIME DEFAULT '16:00:00',
    forward_cutoff_time TIME DEFAULT '15:00:00',
    
    -- Status
    rule_status VARCHAR(20) DEFAULT 'ACTIVE',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_rule_code_per_tenant UNIQUE (tenant_id, rule_code)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.fx_trading_rules_default PARTITION OF dynamic.fx_trading_rules DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.fx_trading_rules IS 'FX trading and hedging rules - spot, forward, swap, options. Tier 2 - Treasury & Liquidity Management.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.fx_trading_rules TO finos_app;
