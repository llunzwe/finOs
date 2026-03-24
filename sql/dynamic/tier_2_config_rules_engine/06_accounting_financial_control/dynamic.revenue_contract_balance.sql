-- ============================================================================
-- FINOS DYNAMIC LAYER - TIER 2: CONFIG & RULES ENGINE (LOW-CODE)
-- ============================================================================
-- COMPONENT: 06 - Accounting Financial Control
-- TABLE: dynamic.revenue_contract_balance
-- COMPLIANCE: IFRS 9
--   - IFRS 15
--   - SOX 404
--   - FCA CASS
-- ============================================================================


CREATE TABLE dynamic.revenue_contract_balance (

    balance_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES core.tenants(id) ON DELETE CASCADE,
    
    -- Contract Reference
    contract_id UUID NOT NULL,
    account_id UUID REFERENCES core.value_containers(id),
    
    -- Allocation
    initial_allocation DECIMAL(28,8) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    
    -- Recognition Tracking
    recognized_to_date DECIMAL(28,8) DEFAULT 0,
    remaining_obligation DECIMAL(28,8),
    
    -- Schedule
    expected_recognition_schedule JSONB, -- [{period: '2024-01', amount: 100}, ...]
    
    -- Status
    balance_type VARCHAR(20) NOT NULL CHECK (balance_type IN ('ASSET', 'LIABILITY')),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'FULLY_RECOGNIZED', 'CANCELLED')),
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version BIGINT NOT NULL DEFAULT 1,
    
    CONSTRAINT unique_contract_balance UNIQUE (tenant_id, contract_id, balance_type)

) PARTITION BY LIST (tenant_id);

CREATE TABLE dynamic.revenue_contract_balance_default PARTITION OF dynamic.revenue_contract_balance DEFAULT;

-- Comments
COMMENT ON TABLE dynamic.revenue_contract_balance IS 'Contract asset/liability balances under IFRS 15';

GRANT SELECT, INSERT, UPDATE ON dynamic.revenue_contract_balance TO finos_app;