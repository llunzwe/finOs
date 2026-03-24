-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 17 - Industry Packs Investments
-- TABLE: dynamic.valuation_methods
-- COMPLIANCE: MiFID II
--   - UCITS
--   - ESG
--   - CISCA
-- ============================================================================


CREATE TABLE dynamic.valuation_methods (

    method_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Identification
    method_code VARCHAR(100) NOT NULL,
    method_name VARCHAR(200) NOT NULL,
    method_description TEXT,
    
    -- Method Type
    valuation_type VARCHAR(50) NOT NULL 
        CHECK (valuation_type IN ('MARK_TO_MARKET', 'MODEL_BASED', 'AMORTIZED_COST', 'FAIR_VALUE', 'HISTORICAL_COST', 'NAV', 'DCF', 'COMPARABLE')),
    
    -- Applicability
    applicable_security_types VARCHAR(50)[],
    applicable_asset_classes VARCHAR(50)[],
    
    -- Methodology
    pricing_source_priority JSONB, -- [{source: 'BLOOMBERG', priority: 1}, {source: 'REUTERS', priority: 2}]
    valuation_model VARCHAR(100), -- If model-based
    model_parameters JSONB,
    
    -- Frequency
    valuation_frequency VARCHAR(20) DEFAULT 'DAILY', -- REALTIME, DAILY, WEEKLY, MONTHLY
    valuation_time TIME DEFAULT '16:00:00',
    
    -- Adjustments
    adjustments_allowed BOOLEAN DEFAULT TRUE,
    adjustment_types JSONB, -- [{type: 'ILLIQUIDITY', calculation: '...'}, ...]
    
    -- Validation
    validation_rules JSONB, -- [{rule: 'price_change < 20%', action: 'ALERT'}]
    stale_price_threshold_hours INTEGER DEFAULT 24,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    effective_from DATE DEFAULT CURRENT_DATE,
    effective_to DATE DEFAULT '9999-12-31',
    is_default BOOLEAN DEFAULT FALSE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_valuation_method_code UNIQUE (tenant_id, method_code)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.valuation_methods_default PARTITION OF dynamic.valuation_methods DEFAULT;

-- Indexes
CREATE INDEX idx_valuation_methods_tenant ON dynamic.valuation_methods(tenant_id) WHERE is_active = TRUE;
CREATE INDEX idx_valuation_methods_type ON dynamic.valuation_methods(tenant_id, valuation_type) WHERE is_active = TRUE;

-- Comments
COMMENT ON TABLE dynamic.valuation_methods IS 'Security and asset valuation methodologies';

-- Triggers
CREATE TRIGGER trg_valuation_methods_audit
    BEFORE UPDATE ON dynamic.valuation_methods
    FOR EACH ROW EXECUTE FUNCTION dynamic.update_audit_fields();

GRANT SELECT, INSERT, UPDATE ON dynamic.valuation_methods TO finos_app;