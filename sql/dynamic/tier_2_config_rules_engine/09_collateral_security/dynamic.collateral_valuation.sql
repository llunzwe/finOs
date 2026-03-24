-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 09 - Collateral Security
-- TABLE: dynamic.collateral_valuation
-- COMPLIANCE: Basel III
--   - UNCITRAL
--   - LMA
--   - CMA
-- ============================================================================


CREATE TABLE dynamic.collateral_valuation (

    valuation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    collateral_id UUID NOT NULL REFERENCES dynamic.collateral_master(collateral_id),
    
    -- Valuer
    valuer_id UUID,
    valuer_name VARCHAR(200),
    valuer_license_number VARCHAR(100),
    valuation_method VARCHAR(50) NOT NULL 
        CHECK (valuation_method IN ('MARKET_COMPARISON', 'INCOME', 'COST', 'DCF', 'FORCED_SALE', 'DESKTOP')),
    
    -- Dates
    valuation_date DATE NOT NULL,
    valuation_valid_until DATE NOT NULL,
    
    -- Values
    market_value DECIMAL(28,8) NOT NULL,
    forced_sale_value DECIMAL(28,8),
    liquidation_value DECIMAL(28,8),
    insurance_value DECIMAL(28,8),
    
    -- Currency
    valuation_currency CHAR(3) NOT NULL,
    
    -- Details
    valuation_report_url VARCHAR(500),
    valuation_notes TEXT,
    assumptions_limitations TEXT,
    
    -- Indexation
    indexation_applied BOOLEAN DEFAULT FALSE,
    indexation_basis VARCHAR(100),
    indexation_date DATE,
    
    -- Status
    is_current BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    CONSTRAINT unique_current_valuation UNIQUE (tenant_id, collateral_id, is_current) WHERE is_current = TRUE

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.collateral_valuation_default PARTITION OF dynamic.collateral_valuation DEFAULT;

-- Indexes
CREATE INDEX idx_valuation_collateral ON dynamic.collateral_valuation(tenant_id, collateral_id);
CREATE INDEX idx_valuation_date ON dynamic.collateral_valuation(valuation_date DESC);

-- Comments
COMMENT ON TABLE dynamic.collateral_valuation IS 'Collateral appraisals with revaluation tracking';

GRANT SELECT, INSERT, UPDATE ON dynamic.collateral_valuation TO finos_app;