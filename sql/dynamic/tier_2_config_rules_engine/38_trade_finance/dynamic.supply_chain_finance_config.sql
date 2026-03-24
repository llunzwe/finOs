-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 38 - Trade Finance
-- TABLE: dynamic.supply_chain_finance_config
--
-- DESCRIPTION:
--   Enterprise-grade supply chain finance configuration.
--   Reverse factoring, dynamic discounting, receivables financing.
--
-- COMPLIANCE: IFRS, Basel III/IV, Trade Finance Regulations
-- ============================================================================


CREATE TABLE dynamic.supply_chain_finance_config (
    config_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Configuration
    program_name VARCHAR(200) NOT NULL,
    scf_type VARCHAR(50) NOT NULL 
        CHECK (scf_type IN ('REVERSE_FACToring', 'DYNAMIC_DISCOUNTING', 'RECEIVABLES_FINANCE', 'PAYABLES_FINANCE', 'INVENTORY_FINANCE')),
    
    -- Anchor Buyer (Large corporate initiating program)
    anchor_buyer_id UUID REFERENCES core.customers(id),
    anchor_buyer_credit_limit DECIMAL(28,8),
    
    -- Supplier Scope
    supplier_eligibility_criteria TEXT[], -- ['MIN_REVENUE', 'MIN_TENURE']
    minimum_supplier_revenue DECIMAL(28,8),
    minimum_supplier_tenure_months INTEGER,
    
    -- Financing Terms
    financing_percentage DECIMAL(5,4) DEFAULT 0.95, -- 95% of invoice
    discount_rate_type VARCHAR(20) DEFAULT 'DYNAMIC' 
        CHECK (discount_rate_type IN ('FIXED', 'DYNAMIC', 'BUYER_FUNDED')),
    base_discount_rate DECIMAL(10,6),
    
    -- Dynamic Discounting (if applicable)
    early_payment_discount_schedule JSONB DEFAULT '{}', -- {"10_days": 0.02, "30_days": 0.01}
    
    -- Tenor
    maximum_financing_tenor_days INTEGER DEFAULT 120,
    
    -- Limits
    program_limit DECIMAL(28,8),
    per_supplier_limit DECIMAL(28,8),
    per_invoice_limit DECIMAL(28,8),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.supply_chain_finance_config_default PARTITION OF dynamic.supply_chain_finance_config DEFAULT;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.supply_chain_finance_config IS 'Supply chain finance configuration - reverse factoring, dynamic discounting. Tier 2 - Trade Finance.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.supply_chain_finance_config TO finos_app;
