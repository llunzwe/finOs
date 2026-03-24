-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
--
-- COMPONENT: 26 - Enterprise Extensions
-- TABLE: dynamic.portfolio_snapshots
--
-- DESCRIPTION:
--   Enterprise-grade historical portfolio snapshots for trend analysis.
--   Point-in-time portfolio values, risk metrics, and performance.
--
-- ============================================================================


CREATE TABLE dynamic.portfolio_snapshots (
    snapshot_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- References
    portfolio_id UUID NOT NULL REFERENCES dynamic.customer_portfolio(portfolio_id),
    customer_id UUID NOT NULL REFERENCES core.customers(id),
    
    -- Snapshot Date
    snapshot_date DATE NOT NULL,
    snapshot_type VARCHAR(20) DEFAULT 'DAILY' 
        CHECK (snapshot_type IN ('DAILY', 'MONTHLY', 'QUARTERLY', 'YEARLY')),
    
    -- Financial Snapshot
    total_assets DECIMAL(28,8),
    total_liabilities DECIMAL(28,8),
    net_worth DECIMAL(28,8),
    
    -- Product Breakdown
    deposits_balance DECIMAL(28,8),
    loans_outstanding DECIMAL(28,8),
    credit_cards_outstanding DECIMAL(28,8),
    investments_value DECIMAL(28,8),
    
    -- Performance
    month_to_date_return DECIMAL(10,6),
    year_to_date_return DECIMAL(10,6),
    
    -- Risk Metrics
    credit_exposure DECIMAL(28,8),
    credit_utilization DECIMAL(5,4),
    
    -- Metadata
    attributes JSONB DEFAULT '{}',
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_portfolio_snapshot UNIQUE (tenant_id, portfolio_id, snapshot_date, snapshot_type)
) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.portfolio_snapshots_default PARTITION OF dynamic.portfolio_snapshots DEFAULT;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_portfolio_snapshots_tenant ON dynamic.portfolio_snapshots(tenant_id);
CREATE INDEX idx_portfolio_snapshots_portfolio ON dynamic.portfolio_snapshots(tenant_id, portfolio_id);
CREATE INDEX idx_portfolio_snapshots_date ON dynamic.portfolio_snapshots(tenant_id, snapshot_date);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE dynamic.portfolio_snapshots IS 'Historical portfolio snapshots for trend analysis and performance tracking. Tier 2 - Enterprise Extensions.';

-- ============================================================================
-- SECURITY - GRANTS
-- ============================================================================
GRANT SELECT, INSERT, UPDATE ON dynamic.portfolio_snapshots TO finos_app;
