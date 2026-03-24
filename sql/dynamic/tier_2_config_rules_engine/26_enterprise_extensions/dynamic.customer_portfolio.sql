-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Enterprise Extensions
-- TABLE: dynamic.customer_portfolio
--
-- DESCRIPTION:
--   Enterprise-grade customer portfolio aggregation and 360° view.
--   Aggregates all products, relationships, and exposure per customer.
--   Supports relationship pricing and consolidated reporting.
--
-- ============================================================================


CREATE TABLE dynamic.customer_portfolio (
    portfolio_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Customer Reference
    customer_id UUID NOT NULL REFERENCES core.customers(id),
    
    -- Portfolio Aggregation
    total_products INTEGER DEFAULT 0,
    active_products INTEGER DEFAULT 0,
    dormant_products INTEGER DEFAULT 0,
    
    -- Financial Summary
    total_assets DECIMAL(28,8) DEFAULT 0, -- Deposits + Investments
    total_liabilities DECIMAL(28,8) DEFAULT 0, -- Loans + Credit
    net_worth DECIMAL(28,8) DEFAULT 0,
    
    -- Exposure by Product Type
    deposit_balance DECIMAL(28,8) DEFAULT 0,
    loan_outstanding DECIMAL(28,8) DEFAULT 0,
    credit_card_outstanding DECIMAL(28,8) DEFAULT 0,
    investment_value DECIMAL(28,8) DEFAULT 0,
    insurance_premium_ytd DECIMAL(28,8) DEFAULT 0,
    
    -- Risk Metrics
    total_credit_exposure DECIMAL(28,8) DEFAULT 0,
    credit_utilization_percentage DECIMAL(5,4) DEFAULT 0,
    risk_grade VARCHAR(10),
    
    -- Revenue
    revenue_ytd DECIMAL(28,8) DEFAULT 0,
    revenue_last_12m DECIMAL(28,8) DEFAULT 0,
    
    -- Relationship
    relationship_manager_id UUID,
    customer_segment VARCHAR(50),
    relationship_tier VARCHAR(20), -- 'BRONZE', 'SILVER', 'GOLD', 'PLATINUM'
    
    -- Engagement
    last_transaction_date DATE,
    last_login_date DATE,
    engagement_score INTEGER, -- 0-100
    
    -- Metadata
    attributes JSONB DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_customer_portfolio UNIQUE (tenant_id, customer_id)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.customer_portfolio_default PARTITION OF dynamic.customer_portfolio DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_customer_portfolio_tenant ON dynamic.customer_portfolio(tenant_id);
CREATE INDEX idx_customer_portfolio_customer ON dynamic.customer_portfolio(tenant_id, customer_id);
CREATE INDEX idx_customer_portfolio_segment ON dynamic.customer_portfolio(tenant_id, customer_segment);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.customer_portfolio IS 'Customer portfolio aggregation - 360° view of all products and exposure. Tier 2 - Enterprise Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.customer_portfolio TO finos_app;
