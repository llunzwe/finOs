-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 25 - Supporting Accounting
-- TABLE: dynamic.balance_snapshots
-- COMPLIANCE: IFRS
--   - SOX
--   - CASS
--   - GDPR
-- ============================================================================


CREATE TABLE dynamic.balance_snapshots (

    snapshot_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    view_id UUID NOT NULL REFERENCES dynamic.real_time_ledger_views(view_id),
    
    -- Entity being tracked
    entity_type VARCHAR(50) NOT NULL, -- 'container', 'product', 'ring_fence', etc.
    entity_id UUID NOT NULL,
    
    -- Balance Components
    total_receipts DECIMAL(28,8) DEFAULT 0,
    total_payments DECIMAL(28,8) DEFAULT 0,
    pending_receipts DECIMAL(28,8) DEFAULT 0,
    pending_payments DECIMAL(28,8) DEFAULT 0,
    holds_amount DECIMAL(28,8) DEFAULT 0,
    
    -- Calculated Balances
    current_balance DECIMAL(28,8) DEFAULT 0,
    available_balance DECIMAL(28,8) DEFAULT 0,
    
    -- Currency
    currency CHAR(3) NOT NULL,
    
    -- As-of Time (Critical for bitemporal)
    as_of_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Calculation Metadata
    calculation_basis VARCHAR(200), -- Which movements were included
    last_movement_id UUID, -- Up to which movement
    
    -- Compliance Flags
    compliance_status VARCHAR(20) DEFAULT 'valid' 
        CHECK (compliance_status IN ('valid', 'warning', 'breach')),
    compliance_checks_passed JSONB DEFAULT '{}',
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.balance_snapshots_default PARTITION OF dynamic.balance_snapshots DEFAULT;

-- Indexes
CREATE INDEX idx_balance_snapshots_view ON dynamic.balance_snapshots(tenant_id, view_id, as_of_time DESC);
CREATE INDEX idx_balance_snapshots_entity ON dynamic.balance_snapshots(tenant_id, entity_type, entity_id, as_of_time DESC);

-- Comments
COMMENT ON TABLE dynamic.balance_snapshots IS 
    'Point-in-time balance snapshots - always derived, never authoritative source';

GRANT SELECT, INSERT, UPDATE ON dynamic.balance_snapshots TO finos_app;